#!/usr/bin/perl -w
use strict;
package Flutterby::Output::HTML;
use Flutterby::Util;
use HTML::Entities;

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
						 -outputfunc => 1,
						}->{$_}));
	}
    return bless($self, $class);
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
		$$r .= $t
			if (defined($t));
	} else {
		print $t;
	}
}

sub outputChildren
{
    my ($self, $childinfo) = @_;

    my ($start);
    my ($outputfunc) = $self->{-outputfunc};
    unless (ref($childinfo))
    {
		&$outputfunc($self,$childinfo);
		return;
    }

    $start = 0;
    $start++ if (ref($childinfo->[0]));

    my ($varlist);
    $varlist = $self->{-varlist};

    my ($i);
    for ($i = $start; $i <= $#$childinfo; $i += 2) {
		if ($childinfo->[$i] eq '0') {	    
			&$outputfunc($self,$childinfo->[$i + 1]);
		} elsif ($childinfo->[$i] eq '!') {
			&$outputfunc($self, '<!-- ');
			if (ref($childinfo->[$i + 1]) eq 'ARRAY') {
				$self->outputChildren($childinfo->[$i + 1]);
			} else {
				&$outputfunc($self, $childinfo->[$i + 1]);
			}
			&$outputfunc($self, ' -->');
		} else {
			$self->outputLeaf($childinfo->[$i],$childinfo->[$i + 1]);
		}
	}
}

sub outputTag
{
    my ($self, $tag, $attributes, $childinfo,$post) = @_;
    my ($varlist);
    $varlist = $self->{-varlist};
    my ($outputfunc) = $self->{-outputfunc};

    &$outputfunc($self,"<$tag");
    foreach (keys %$attributes) {
		if ($_ =~ /^\w+$/) {
			if (defined($attributes->{$_})) {
				&$outputfunc($self," $_");
				&$outputfunc($self,Flutterby::Util::subst('="'.
														  HTML::Entities::encode($attributes->{$_})
														  .'"',@$varlist));
			} else {
				&$outputfunc($self," $_=\"$_\"");
			}
		}
    }
    if ($#$childinfo > 0) {
		&$outputfunc($self,">");
		$self->outputChildren($childinfo);
		&$outputfunc($self,\&$post($self,$tag,$attributes,$childinfo))
			if (defined($post));
		&$outputfunc($self,"</$tag>");
	} else {
		&$outputfunc($self,"></$tag>");
		&$outputfunc($self,\&$post($self,$tag,$attributes,$childinfo))
			if (defined($post));
	}
}

sub outputTagNoSubst
{
    my ($self, $tag, $attributes, $childinfo,$post) = @_;
    my ($varlist);
    $varlist = $self->{-varlist};
    my ($outputfunc) = $self->{-outputfunc};

    &$outputfunc($self,"<$tag");
    foreach (keys %$attributes) {
		if (/^\w+$/) {
			if (defined($attributes->{$_})) {
				&$outputfunc($self," $_");
				&$outputfunc($self,Flutterby::Util::subst('="'.
														  HTML::Entities::encode($attributes->{$_})
														  .'"',@$varlist));
			} else {
				&$outputfunc($self," $_=\"$_\"");
			}
		}
    }
    if ($#$childinfo > 0) {
		&$outputfunc($self,">");
		$self->outputChildren($childinfo);
		&$outputfunc($self,\&$post($self,$tag,$attributes,$childinfo))
			if (defined($post));
		&$outputfunc($self,"</$tag>");
	} else {
		&$outputfunc($self,'></$tag>');
		&$outputfunc($self,\&$post($self,$tag,$attributes,$childinfo))
			if (defined($post));
	}
}


sub outputLeaf
{
    my ($self, $tag, $childinfo) = @_;

    $self->outputTag($tag,$childinfo->[0], $childinfo);
}

sub output
{
    my ($self, $childinfo) = @_;
    $self->outputChildren($childinfo,0);
	#    $self->outputLeaf($tree->[0], $tree->[1]);
}

1;
