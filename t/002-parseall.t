#!/usr/bin/env perl
# ABSTRACT: Test that all library modules can load successfully
use Test::Most 'bail';
use Flutterby::Parse::HTML;
use Flutterby::Parse::Text;
use Carp;
use Data::Dumper;

my @parsers =
    (
     Flutterby::Parse::Text->new,
     Flutterby::Parse::HTML->new,
    );

for my $parser (@parsers)
{
    my $t = $parser->parse('a simple test of <a href="a link" onClick="invalid">a link</a> here');
    print Dumper($t);
}
