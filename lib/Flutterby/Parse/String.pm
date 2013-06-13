#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::String;

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

sub parse
{
    my ($self) = shift @_;
    my (@a,$t);

    $a[0] = '0';
    $t = join('',@_);

    if (defined($self->{-longeststring})) {
        my ($len, $maxlen, @words, $word);
        $len = $self->{-longeststring};

        @words = split(/\s/s, $t);
        $t = '';
        foreach (@words) {
            my ($word);
            $word = $_;
            if (length($word) > $len) {
                $word =~ s/\// \/ /g;
            }
            $t .= " $word";
        }
    }

    $a[1] = '';
    $t =~ s/\</\&lt;/g;
    $t =~ s/\>/\&gt;/g;

    $t =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f]//g;
    while ($t =~ /^(.*?)([\x80-\xff])(.*)$/) {
        $t = sprintf('%s&#%d;%s', $1,ord($2),$3);
    }
    while ($t =~ s/^(.*?\&)//s) {
        $a[1] .= $1;
        $a[1] .= 'amp;' unless ($t =~ /^(\w+|\#\w+);/);
    }
    $a[1] .= $t;

    return \@a;
}
1;

