#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::FullyEscapedString;

sub new
  {
    my ($type,%args) = @_;
    my $class = ref($type) || $type;
    my $self = {};

    my ($k, $v);
    while (($k,$v) = each %args)
    {
	$self->{$k} = $v;
    }
    return bless($self, $class);
  }

my (%sacred5) = 
    (
     '&' => 'amp',
     '<' => 'lt',
     '>' => 'gt',
     '"' => 'quot',
     );
sub parse
  {
    my ($self) = shift @_;
    my (@a,$t);

    $a[0] = '0';
    $t = join('',@_);

    $a[1] = '';
    while ($t =~ s/^(.*?)([\&\<\>\'\"\x80-\xff])//xs)
    {
	my ($escape);

	$escape = defined($sacred5{$2}) ? $sacred5{$2} : sprintf('#%d',ord($2));
	$a[1] .= "$1\&$escape;";
    }
    $a[1] .= $t;

    return \@a;
  }
1;

