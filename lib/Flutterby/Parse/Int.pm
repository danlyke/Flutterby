#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::Int;

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
    $t = join(' ',map {int($_);} @_);
    $a[1] = '';
    $t =~ s/\</\&lt;/g;
    $t =~ s/\>/\&gt;/g;
    while ($t =~ s/^(.*?\&)//s)
      {
	$a[1] .= $1;
	$a[1] .= 'amp;' unless ($t =~ /^(\w+|\#\d+);/);
      }
    $a[1] .= $t;
    return \@a;
  }
1;
