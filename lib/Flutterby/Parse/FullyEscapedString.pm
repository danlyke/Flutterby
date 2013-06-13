#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::FullyEscapedString;
use utf8::all;

sub new
{
    my ($type,%args) = @_;
    my $class = ref($type) || $type;
    my $self = {};

    my ($k, $v);
    while (($k,$v) = each %args) {
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
    while ($t =~ s/^(.*?)([\&\<\>\'\"\x{80}-\x{ffff}])//xs) {
        my ($escape);
        my $pre = $1;

        $escape = defined($sacred5{$2}) ? $sacred5{$2} : sprintf('#%d',ord($2));
        if ($2 eq '&') {
            if ($t =~ s/^(\#?\w+\;)//xs) {
                $escape = "amp;$1";
            }
        }
        $a[1] .= "$pre\&$escape";
    }
    $a[1] .= $t;

    return \@a;
}
1;

