#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::Ordinal;

sub new
  {
    my ($type,%args) = @_;
    my $class = ref($type) || $type;
    my $self = {};
    return bless($self, $class);
  }

sub parse
  {
    my ($self) = shift @_;
    my (@a,$t);

    $a[0] = '0';
    $t = join(' ',
	      map 
	      {
		int($_).'<sup>'
		  .(($_ > 3 && $_ < 21) || ($_ % 10 > 3) 
		    ? 'th' : ['th','st','nd','rd']->[$_ % 10])
		    .'</sup>';} @_);
    $a[1] = $t;
    return \@a;
  }
1;
