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
     'Flutterby::Parse::HTML',
    );

my @output = 
    (
     'Flutterby::Output::HTML',
     'Flutterby::Output::HTMLProcessed',
    );

my %outputchecks =
    (
     'Flutterby::Parse::Text/Flutterby::Output::HTML' => '<html><body><p>a simple test of <a href="a link" onclick="invalid">a link</a> here</p>

</body></html>',
     'Flutterby::Parse::Text/Flutterby::Output::HTMLProcessed' => '<html><body><p>a simple test of <a href="a link" onclick="invalid">a link</a> here</p>

</body></html>',
     'Flutterby::Parse::HTML/Flutterby::Output::HTML' => 'a simple test of <a href="a link" onclick="invalid">a link</a> here',
     'Flutterby::Parse::HTML/Flutterby::Output::HTMLProcessed' => 'a simple test of <a href="a link" onclick="invalid">a link</a> here'
    );

for my $parser_name (@parsers)
{
    my $parser = $parser_name->new;
    my $t = $parser->parse('a simple test of <a href="a link" onClick="invalid">a link</a> here');
    for my $output_name (@output)
    {
        my $text = '';
        my $output = $output_name->new();
        $output->setOutput(\$text);
        $output->output($t);
#        print "'$parser_name/$output_name' => '$text'\n";
        ok $text eq $outputchecks{"$parser_name/$output_name"}, "Checking $parser_name/$output_name";
    }
}

done_testing;
