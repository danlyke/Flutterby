#!/usr/bin/perl -w
use strict;
package FbyDB::Connection;
use Moose;
has 'dbh' => (is => 'rw');
has 'debug' => (is => 'rw');
use DBI;


use Carp;
sub CallStack
{
    local $@;
    eval { confess( '' ) };
    my @stack = split m/\n/, $@;
    shift @stack for 1..3; # Cover our tracks.
    return wantarray ? @stack : join "\n", @stack;
}



sub connect(@)
{
	my $self = shift;
	my $dbh = DBI->connect(@_)
		|| die $DBI::errstr."\n".CallStack;
	$self->dbh($dbh);
}


my %typemappings = 
(
 'Str' => 'TEXT',
 'Int' => 'INTEGER',
 'Num' => 'DOUBLE',
);


sub tablename($)
{
	my ($self,$type) = @_;
	$type = ref($type) || $type;
	$type =~ s/^.*\:\://;
	return $type;
}


sub get_attrs($)
{
	my ($self,$type) = @_;
	$type = ref($type) || $type;
	my %attrs;
	foreach my $attr ($type->meta->get_all_attributes)
	{
		if (substr($attr->name,0,1) ne '_')
		{
			if (defined($attr->{type_constraint}))
			{
				$attrs{$attr->name} = $typemappings{$attr->{type_constraint}};
			}
			else
			{
				$attrs{$attr->name} = 'TEXT';
			}
		}
	}
	return \%attrs;
}


sub create_statement($)
{
	my ($self, $type) = @_;

	my $attrs = $self->get_attrs($type);

	my $r = 'CREATE TABLE '.$self->tablename($type)
		." (\n"
		.join(",\n", map {"  $_ $attrs->{$_}" . ($_ eq 'id' ? ' PRIMARY KEY' : '')} keys %$attrs)
		."\n);\n";
	return $r;
}

sub do($@)
{
	my $self = shift;

	$self->dbh()->do(@_)
			|| die $self->dbh()->errstr."\n@_\n"."\n".CallStack;
}


sub write($$)
{
	my ($self,$obj) = @_;
	my $attrs = $self->get_attrs($obj);

	if (defined($obj->id))
	{
		my $sql = 'UPDATE '.$self->tablename($obj)
			.' SET '
			.join(', ', map { "$_=".$self->dbh()->quote($obj->$_) } keys %$attrs )
			.' WHERE id='.$self->dbh()->quote($obj->id);
		print "$sql\n"
			if ($self->debug);
		$self->do($sql);
	}
	else
	{
		my @keys = grep { defined($obj->$_) } keys %$attrs;

		my $sql = 'INSERT INTO '.$self->tablename($obj)
			.'('.join(', ', @keys).') VALUES ('
			.join(', ', map { $self->dbh()->quote($obj->$_) } @keys )
			.')';

		print "$sql\n"
			if ($self->debug);

		$self->do($sql);
		$obj->id($self->dbh()->last_insert_id(undef,undef,$self->tablename($obj),'id'));
	}
}

sub load($$@)
{
	my $self = shift;
	my $class = shift;
	my $keys = @_ ? ((ref($_[0]) eq 'HASH') ? \%{$_[0]} : {@_}) : undef;

	my $attrs = $self->get_attrs($class);
	my @attrs = keys %$attrs;

	my $sql = 'SELECT '.join(', ', @attrs).' FROM '.$self->tablename($class)
		.(defined($keys) ? ' WHERE '.join(' AND ', map { "$_=".$self->dbh()->quote($keys->{$_}) } keys %$keys) : '');
	my $sth = $self->dbh()->prepare($sql)
		|| die $self->dbh()->errstr."\n$sql\n"."\n".CallStack;

	my @objs;
	$sth->execute()
		|| die $self->dbh()->errstr."\n$sql\n"."\n".CallStack;
	while (my $row = $sth->fetchrow_hashref)
	{
		if (1)
		{
			my %args;
			while (my ($k,$v) = each %$row)
			{
				$args{$k} = $v
					if (defined($v));
			}
			push @objs, $class->new(%args);
		}
		else
		{
			push @objs, $class->new(%$row);
		}
	}
	return @objs;
}


sub delete($$@)
{
	my $self = shift;
	my $class = shift;
	my $keys = @_ ? ((ref($_[0]) eq 'HASH') ? \%{$_[0]} : {@_}) : undef;

	my $attrs = $self->get_attrs($class);
	my @attrs = keys %$attrs;

	my $sql = 'DELETE FROM '.$self->tablename($class)
		.' WHERE '.join(' AND ', map { "$_=".$self->dbh()->quote($keys->{$_}) } keys %$keys);
	$self->do($sql);
}

sub load_one($$@)
{
	my ($self, $class, @keys) = @_;
	my @ret = $self->load($class,@keys);
	die "Too many results for load of class $class ("
		.join(', ' , @keys).")\n"."\n".CallStack
		unless @ret < 2;

	return (scalar(@ret) == 1) ? $ret[0] : undef;
}


sub load_or_create($$@)
{
	my ($self, $type, %args) = @_;

	my $obj = $self->load_one($type, %args );

	unless ($obj)
	{
		$obj = $type->new(%args);
		$self->write($obj);
	}

	return $obj;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

FbyDB - Simple SQL database helper for Moose

=head1 SYNOPSIS

Create a C<Moose> object with an 'id' member:

    package Person;
    use Moose;
    has 'id' => (is => 'rw', isa => 'Int');
    has 'name' => (is => 'rw', isa => 'Str');
    no Moose;
    __PACKAGE__->meta->make_immutable;

set up a connection:

    use FbyDB;
    my $db = FbyDB::Connection->new(debug=>1);
    $db->connect("dbi:SQLite:dbname=./db.sqlite3");

You can get SQL to create tables from a Moose class by doing something like:

    $db->do($db->create_statement('Person')

Load or create objects with:

    my $person = $db->load_or_create('Person', name => 'Dan');

or, of course, just use

    Person->new(name=>'Dan')

if you know don't want an initial query. Also available is 

	my $person = $db->load_one('Person', name=>'Dan');

and

    my @people = $db->load('Person', name=>'Dan');

Write objects with

    $db->write($person);

If the 'id' member is defined, this does an UPDATE, otherwise it does
an INSERT.

=head1 DESCRIPTION

I wanted something that let me write Moose OO Perl but still let me
use an SQL database later for what it's good for. This is that
hack. KiokuDB was too complex for a simple key value database that I
couldn't query from straight SQL, nothing else seemed to be there.



