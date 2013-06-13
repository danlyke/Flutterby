#!/usr/bin/perl -w

use Test::Most  qw/bail !blessed/;
use Scalar::Util qw/blessed/;

use Flutterby::Parse::Text;
use Flutterby::Parse::FullyEscapedString;
use Flutterby::Parse::HTML;
use Flutterby::Output::HTMLProcessed;
use Flutterby::Output::HTML;
use CGI;
my $cgi = CGI->new();


#my $p = Flutterby::Parse::Text->new();
#my $t = $p->parse("&#148;");

my $testtext = 'Some stuff &#65; goes here';
my $parser = Flutterby::Parse::FullyEscapedString->new();
my $t = $parser->parse($testtext);
my $o = Flutterby::Output::HTML->new;
my $text = '';
$o->setOutput(\$text);
$o->output($t);
ok $text eq 'Some stuff &amp;#65; goes here', "First string test";

# $cgi->param(abc => $testtext);
# my $out = Flutterby::Output::HTMLProcessed->new(-cgi => $cgi);
# 
# my $p = Flutterby::Parse::HTML->new();
# my $html = <<EOF;
# <html><head>
# </head>
# <body>
# <form><textarea name="abc" /></form>
# </body>
# </html>
# EOF
# my $t = $p->parse($html);
# 
# $out->output($t);
# print "\n";
# print join(',', $cgi->param);
# print "\n";

done_testing;
