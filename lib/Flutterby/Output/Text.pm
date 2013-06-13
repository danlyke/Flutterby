#!/usr/bin/perl -w
use strict;
package Flutterby::Output::Text;
use Flutterby::Util;

sub new()
{
    my ($type,%args) = @_;
    my $class = ref($type) || $type;
    my ($self) = 
    {
     -outputfunc => \&sendToOutput,
    };
    foreach (keys %args) {
        $self->{$_} = $args{$_}
            if (defined({
                         -numberlinks => 1,
                         -outputfunc => 1,
                        }->{$_}));
    }
    $self->{-linkurls} = [] if (defined($self->{-numberlinks}));

    return bless($self, $class);
}

sub resetLinkNumbers()
{
    my ($self, $number) = @_;
    $number = 1 unless defined($number);
    $self->{-numberlinks} = $number;
    $self->{-linkurls} = [];
}
sub getLinkURLs()
{
    my ($self) = @_;
    return @{$self->{-linkurls}};
}
sub setOutput()
{
    my ($self, $dest) = @_;
    $self->{-outputdest} = $dest;
}

sub sendToOutput()
{
    my ($self, $t) = @_;
    my ($r) = $self->{-outputdest};
    
    if (ref($r) eq 'GLOB') {
        print {*$r} $t;
    } elsif (ref($r) eq 'SCALAR') {
        $$r .= $t;
    } else {
        print $t;
    }
}

sub outputChildren
{
    my ($self, $childinfo, $start) = @_;

    my ($outputfunc) = $self->{-outputfunc};
    unless (ref($childinfo))
    {
        &$outputfunc($self,$childinfo);
        return;
    }
    
    $start = 0;
    $start++ if (ref($childinfo->[0]));

    my ($i);
    for ($i = $start; $i <= $#$childinfo; $i += 2) {
        if ($childinfo->[$i] eq '0') {	    
            &$outputfunc($self,$childinfo->[$i + 1]);
        } elsif ($childinfo->[$i] eq '!') {
        } else {
            $self->outputChildren($childinfo->[$i+1]);
            if ($childinfo->[$i] eq 'a' 
                && defined($childinfo->[$i+1]->[0]->{'href'})
                && defined($self->{-numberlinks})) {
                &$outputfunc($self,"\[$self->{-numberlinks}\]");
                $self->{-numberlinks}++;		
                push @{$self->{-linkurls}}, $childinfo->[$i+1]->[0]->{'href'};
            }
        }
    }
}


sub output
{
    my ($self, $childinfo) = @_;
    $self->outputChildren($childinfo);
    #    $self->outputLeaf($tree->[0], $tree->[1]);
}

1;
