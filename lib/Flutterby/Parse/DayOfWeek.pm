#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::DayOfWeek;

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
    $a[1] = {
	  1 => 'Monday',
	  2 => 'Tuesday',
	  3 => 'Wednesday',
	  4 => 'Thursday',
	  5 => 'Friday',
	  6 => 'Saturday',
	  7 => 'Sunday',
	  0 => 'Sunday',
	 }->{int($_[0])};
    return \@a;
  }
1;
