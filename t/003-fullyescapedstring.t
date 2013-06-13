#!/usr/bin/perl -w
use strict;
use Test::Most 'bail';
use Flutterby::Parse::FullyEscapedString;
use Data::Dumper;

my $p = Flutterby::Parse::FullyEscapedString->new();
my $t = $p->parse('Some &#147; text &#148; stuff ');
ok $t->[1] eq 'Some &amp;#147; text &amp;#148; stuff ', "First string comparison";

done_testing;
