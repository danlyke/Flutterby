#!/usr/bin/env perl
# ABSTRACT: Test that all library modules can load successfully
use Test::Most 'bail';
use Flutterby::Parse::HTML;
use Flutterby::Parse::Text;
use Flutterby::Output::HTML;
use Flutterby::Output::HTMLProcessed;
use Carp;
use Data::Dumper;

my @parsers =
    (
     'Flutterby::Parse::Text',
#     'Flutterby::Parse::HTML',
    );

my @output = 
    (
     'Flutterby::Output::HTML',
#     'Flutterby::Output::HTMLProcessed',
    );


for my $parser_name (@parsers)
{
    my $parser = $parser_name->new;
    my $t = $parser->parse('a simple test of <a href="a link" onClick="invalid">a link</a> here');
    for my $output_name (@output)
    {
        my $output = $output_name->new;
        $output->output($t);
        print "\n";
    }
}
