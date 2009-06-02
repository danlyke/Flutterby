package ImageInstance;
use Moose;
has 'id' => (is => 'rw', isa => 'Int');
has 'image_id' => (is => 'rw', isa => 'Int');
has 'filename' => (is => 'rw', isa => 'Str');
has 'width' => (is => 'rw', isa => 'Int');
has 'height' => (is => 'rw', isa => 'Int');

sub name
{
	my ($self) = @_;
	my $filename = $self->filename;
	$filename =~ s%^.*\/%%;
	$filename =~ s/\d+px\-//;
	return $filename;
}


sub dimensions()
{
	my ($self) = @_;

	unless (defined($self->width) && defined($self->height))
	{
		my $fullpath = $self->filename;
		my $mo = `jpeginfo $fullpath`;
		if ($mo =~ / (\d+) x (\d+) /)
		{
			$self->width($1);
			$self->height($2);
		}
	}
	unless (defined($self->width) && defined($self->height))
	{
		my $fullpath = $self->filename;
		my $mo = `mogrify -verbose $fullpath`;
		if ($mo =~ / (\d+)x(\d+) /)
		{
			$self->width($1);
			$self->height($2);
		}
	}
	my @ret = ($self->width, $self->height);
	return @ret	if (wantarray);
	return \@ret;
}


no Moose;
__PACKAGE__->meta->make_immutable;



package Image;
use Moose;
has 'id' => (is => 'rw', isa => 'Int');
has name => (is => 'rw', isa => 'Str');

sub instances($)
{
	my ($self, $db) = @_;
	return $db->load('ImageInstance', image_id => $self->id);
}

sub _sortinstances
{
	my ($self,$db) = @_;
	my @instsunsorted = $self->instances($db);
	my @insts = sort { $b->dimensions->[0] <=> $a->dimensions->[0] } @instsunsorted;
	return @insts;
}

sub thumb
{
	my ($self,$db) = @_;
	my @insts = $self->_sortinstances($db);
	return $insts[0];
}

sub fullsize
{
	my ($self, $db) = @_;
	my @insts = $self->_sortinstances($db);
	return $insts[$#insts];
}


no Moose;
__PACKAGE__->meta->make_immutable;


package WikiEntryReference;
use Moose;
has id => (is => 'rw', isa => 'Int');
has from_id => (is => 'rw', isa => 'Int');
has to_id => (is => 'rw', isa => 'Int');

no Moose;
__PACKAGE__->meta->make_immutable;


package WikiEntry;
use Moose;
has 'id' => (is => 'rw', isa => 'Int');
has inputname => (is => 'rw', type => 'Str');
has name => (is => 'rw', type => 'Str');
has _missingReferences => (is => 'rw', default => sub { {} });
has needsExternalRebuild => (is => 'rw', type => 'Int');
has needsContentRebuild => (is => 'rw', type => 'Int');

has _mtime => (is => 'rw', type => 'Int');
has _ctime => (is => 'rw', type => 'Int');
has _size => (is => 'rw', type => 'Int');

sub initStatStuff()
{
	my ($self) = @_;
	my ($size, $mtime, $ctime) = (stat("mvs/".$self->inputname))[7,9,10];
	die "Unable to open ".$self->inputname."\n" unless (defined($mtime));
	$self->_mtime($mtime);
	$self->_ctime($ctime);
	$self->_size($size);}

sub mtime()
{
	my ($self) = @_;
	$self->initStatStuff() unless defined($self->_mtime);
	return $self->_mtime;
}

sub ctime()
{
	my ($self) = @_;
	$self->initStatStuff() unless defined($self->_ctime);
	return $self->_ctime;
}

sub size()
{
	my ($self) = @_;
	$self->initStatStuff() unless defined($self->_size);
	return $self->_size;
}


sub referencedBy()
{
	my ($self,$db) = @_;

	my @a = $db->load('WikiEntryReference', to_id => $self->id);

	if ($self->name eq 'MFS')
	{
		print "Loaded: ", join(',', @a)," to_id is ".$self->id."\n";
	}
	my @b;
	foreach (@a)
	{
		push @b, $db->load('WikiEntry', id => $_->from_id);
	}
	return @b;
}


sub addReference
{
	my ($self, $ref) = @_;
	$self->references()->{$ref->name} = $ref;
}


sub CanonicalName($)
{
	my ($name) = @_;
	$name =~ s/\:\s+/\:/xsg;
	$name =~ s/\s+/\ /xsg;
	$name =~ s/\.wiki$//xsg;
	return $name;
}


sub name
{
	my ($self) = @_;	
	return CanonicalName($self->inputname);
}

sub outputnameRoot
{
	my ($self) = @_;
	my $name = $self->name;
	$name =~ s/ /_/g;
	return $name;
}

sub outputname
{
	my ($self) = @_;
	return $self->outputnameRoot.'.html';
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
