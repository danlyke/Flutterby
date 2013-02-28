#!/usr/bin/perl -w
use strict;
use warnings;

package Flutterby::Parse::HTML;
# use Flutterby::Parse::TreeBuild;
use Flutterby::Parse::HTMLUtil;
use HTML::Entities;

sub MyDecodeEntities
{
    my $array;
    if (defined wantarray) {
        $array = [@_];			# copy
    } else {
        $array = \@_;			# modify in-place
    }
    my $c;
    for (@$array) {
        s/(&\#(\d+);?)/$2 < 256 ? chr($2) : $1/eg;
        s/(&\#[xX]([0-9a-fA-F]+);?)/$c = hex($2); $c < 256 ? chr($c) : $1/eg;
        s/(&(\w+);)/$HTML::Entities::entity2char{$2} || $1/eg;
    }
    wantarray ? @$array : $array->[0];
}


sub new
{
    my ($type,%args) = @_;
    my $class = ref($type) || $type;

    my ($self) = 
    {
    };
    $self->{-parsecommentbody} = $args{-parsecommentbody}
        if (defined($args{-parsecommentbody}));
    $self->{-allowedtagsubset} = 
		Flutterby::Parse::HTMLUtil::userAllowedTagHashref()
				unless defined($args{-allowalltags});
    $self->{-alwaysallowtags} = {};
    $self->{-alwaysallowtags} =
		$args{-alwaysallowtags} if (defined($self->{-alwaysallowtags}));
    $self->{-parsecommentbody} =
		$args{-parsecommentbody} if (defined($self->{-parsecommentbody}));

    $self->{-htmlutil} = new Flutterby::Parse::HTMLUtil(%args);
    return bless($self, $class);
}

sub flutterby_begin_parse
{
    my ($self) = @_;
    my (@tree);
    $self->{-tree} = \@tree;
    $self->{-tagstack} = [];
    $self->{-treepos} = [\@tree];
    $self->{-parseinprogress} = 1;
    $self->{-tagrefcount} = {};
}

sub flutterby_end_parse
{
    my ($self) = @_;
    delete ($self->{-parseinprogress});
    # now do checks to see if we've got an error condition left over
    my ($errors);
    $errors = '';
    my ($tagrefcount, $tagstack, $i, $errmsg);
    $tagstack = $self->{-tagnamestack};
    for ($i = $#$tagstack; $i >= 0; $i--) {
		$self->end($tagstack->[$i]);
    }

    $errmsg = "The following tags have non-zero ref counts:\n";
    $tagrefcount = $self->{-tagrefcount};
    for (keys %$tagrefcount) {
		$errors .= $errmsg;
		$errmsg = '';
		$errors .= "  $_ - $tagrefcount->{$_}\n";
	}
    warn $errors unless $errors eq '';
    return $self->{-tree};
}

sub parsefile
{
    my ($self) = shift @_;

    my ($parseinprogress) = $self->{-parseinprogress};

    $self->flutterby_begin_parse() unless ($parseinprogress);
    foreach (@_) {
		open(FCMSHTML_I, $_)
			|| die "Unable to open $_\n";
		$self->parse(join('',<FCMSHTML_I>));
		close FCMSHTML_I;
    }
    $self->flutterby_end_parse() unless ($parseinprogress);

    return $self->{-tree};
}

sub parse_file
{
    return &parsefile(@_);
}
sub parse
{
    my ($self) = shift @_;
    my ($parseinprogress) = $self->{-parseinprogress};
    my ($allowedtagsubset) = $self->{-allowedtagsubset};

    $allowedtagsubset = undef
		unless defined($allowedtagsubset) && ref($allowedtagsubset) eq 'HASH';

    $self->flutterby_begin_parse() unless ($parseinprogress);

    my ($charblock);
    while ($charblock = shift @_) {
		while ($charblock =~ s/^(.*?)\<(((\/?)([a-z][\w\:]*)(\s*|.*?\"\s*|[^\<]*)\/?\>)
							   |(\!)\-\-\s+(.*?)\s+-\-\>|(\!\[CDATA\[.*?\]\]\>))//xsi) {
            if (defined($9)) {
				$self->text($1) if (defined($1) && $1 ne '');
                $self->text("<$9");
            } elsif (defined($7) && $7 eq '!') {
				$self->text($1) if (defined($1) && $1 ne '');
				if (defined($self->{-parsecommentbody})) {
					$self->start('!', {});
					my ($oldparsenonhtml, $oldallowedtagsubset);
					$oldparsenonhtml = $self->{-parsenonhtml};
					$oldallowedtagsubset = $self->{-allowedtagsubset};

					$self->{-parsenonhtml} = 1;
					delete $self->{-allowedtagsubset};

					$self->parse($8);
					if (defined($oldparsenonhtml)) {
						$self->{-parsenonhtml} = $oldparsenonhtml;
					} else {
						delete($self->{-parsenonhtml});
					}
					$self->{-allowedtagsubset} = $oldallowedtagsubset
						if (defined($oldallowedtagsubset));
					$self->end('!');
				} else {
					$self->comment($8);
				}
			} else {
				my ($pre, $tagclose, $tagname, $attrs) = ($1,$4,$5,$6);

				$tagname = lc($tagname) unless $tagname =~ /\:/;
				$self->text($pre) if (defined($pre) && $pre ne '');
				if ((!defined($allowedtagsubset))
					|| $allowedtagsubset->{$tagname})
				{
					if (defined($tagclose) && $tagclose ne '')
					{
						$self->end($tagname);
					}
					else
					{
						my (%attrs);
						while (($attrs =~ s/^\s*([a-z]+[\:\w]*)\s*\=\s*\"(.*?)\"\s*//si)
							   || ($attrs =~ s/^\s*([a-z]+[\:\w]*)\s*\=\s*\'(.*?)\'\s*//si)
							   || ($attrs =~ s/^\s*([a-z]+[\:\w]*)\s*\=\s*([\S\$]+)\s*//si)
							   || ($attrs =~ s/^\s*([a-z]+[\:\w]*)\s*\=\s*\"(.*?)\"?\s*//si)
							   || ($attrs =~ s/^\s*([a-z]+[\:\w]*)//si)) {
							my ($k, $v) = ($1,$2);
							$v = '1' unless defined($v);
							$k = lc($k) unless $k =~ /\:/;
                            $attrs{$k} = MyDecodeEntities($v);
						}
						$self->start($tagname, \%attrs);
					}
				} else {
					$tagclose = '' unless defined($tagclose);
					$self->text("\&lt;$tagclose$tagname$attrs\&gt;");
				}
			}
		}
		$self->text($charblock) if (defined($charblock) && $charblock ne '');
    }
    $self->flutterby_end_parse() unless ($parseinprogress);
    return $self->{-tree};
}

sub declaration
{
    my ($self, $text) = @_;
}

sub start
{
    my ($self, $tagname, $attr) = @_;
    my ($tagnamestack) = $self->{-tagstack};
    my ($alwaysallowedtags) = $self->{-alwaysallowtags};

    $tagname = substr($tagname, 0, length($tagname) - 1) 
		if (substr($tagname,-1,1) eq '/');

    if ($self->{-htmlutil}->isEmpty($tagname)) {
		my ($tree);
		$tree = $self->{-treepos};
		$tree = $tree->[$#$tree];
		push @$tree, $tagname, [$attr];
    } else {
		if ($#$tagnamestack >= 0
			&& $tagname eq $tagnamestack->[$#$tagnamestack]
			&& !defined({'div' => 1, 'span' => 1}->{$tagname})) {
			$self->end($tagname);
		}
		if (!$self->{-parsenonhtml}
			&& !defined($alwaysallowedtags->{$tagname})
			&& $#$tagnamestack >= 0
			&& !$self->{-htmlutil}->isValidSubtag
			($tagnamestack->[$#$tagnamestack],$tagname)) {
			my ($i);
			for ($i = $#$tagnamestack - 1;
				 $i >= 0
				 && !$self->{-htmlutil}->isValidSubtag
				 ($tagnamestack->[$i],$tagname) ;
				 $i--) {
			}
			if ($i >= 0) {
				my $j;
				for ($j = $#$tagnamestack; $j >= $i; $j--) {
					$self->end(pop(@$tagnamestack));
				}
			}
		}   
		$self->{-tagrefcount}->{$tagname} = 0
			unless defined($self->{-tagrefcount}->{$tagname});
		$self->{-tagrefcount}->{$tagname}++;

		my ($tree);
		$tree = $self->{-treepos};
		$tree = $tree->[$#$tree];
		push @$tree, $tagname, [$attr];
		push @{$self->{-treepos}}, $tree->[$#$tree];
		push @{$self->{-tagstack}}, $tagname;
	}
}
sub end
{
    my ($self, $tagname) = @_;

    unless ($self->{-htmlutil}->isEmpty($tagname)) {
		return unless ($self->{-tagrefcount}->{$tagname});
	
		my ($tagnamestack) = $self->{-tagstack};
	
		if ($#$tagnamestack >= 0) {
			if ($tagnamestack->[$#$tagnamestack] ne $tagname) {
				my ($i);
				for ($i = $#$tagnamestack; 
					 ($i > 0)
					 && ($tagnamestack->[$i] ne $tagname); $i--) {
				}
				if ($tagnamestack->[$i] eq $tagname) {
					my ($j);
					for ($j = $#$tagnamestack; $j > $i; $j--) {
						$self->end($tagnamestack->[$j]);
					}
				}
			}
			if ($tagnamestack->[$#$tagnamestack] eq $tagname) {
				pop @{$self->{-treepos}};
				pop @{$self->{-tagstack}};
				delete ($self->{-tagrefcount}->{$tagname}) 
					unless (--$self->{-tagrefcount}->{$tagname});
			}
		}
    } else {
    }
}

sub comment
{
    my ($self, $text) = @_;

    my ($tree);
    $tree = $self->{-treepos};
    $tree = $tree->[$#$tree];
    push @$tree, '!', $text;
}

sub text
{
    my ($self, $text) = @_;

    my ($tree);
    $tree = $self->{-treepos};
    $tree = $tree->[$#$tree];
    if ($#$tree >= 1 && $tree->[$#$tree - 1] eq '0') {
		$tree->[$#$tree] .= $text;
    } else {
		push @$tree, '0', $text;
    }
}

1;





__END__


=head1 NAME

Flutterby::Parse::HTML - HTML parser class

=head1 SYNOPSIS

 use Flutterby::Parse::HTML;
 $p = new Flutterby::Parse::HTML();

 $tree = $p->parse(string);

 # Parse directly from file
 $tree = $p->parse_file("foo.html");
 # or
 open(F, "foo.html") || die;
 $tree = $p->parse_file(*F);

=head1 DESCRIPTION

The C<Flutterby::Parse::HTML> class was developed to provide a simple
way to clean up and restrict user input, and give the program the
results back in a C<XML::Parser> style tree, which can then be
manipulated, and output using one of the C<Flutterby::Output>
routines.

It does a reasonable job of enforcing HTML hierarchical structure as
defined in C<Flutterby::Parse::HTMLUtil>, and making sure that all the
constructs get properly closed off.

Unless instantiated with '-allowalltags => 1', will suppress any tags
related to scripting or that might lead untrusted users to gain
control of a user machine. The complete trusted tag list is in
C<Flutterby:Parse::HTMLUtil::userAllowedTagSubset>.
