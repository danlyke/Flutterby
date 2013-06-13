#!/usr/bin/env perl

# ABSTRACT: Test that all library modules can load successfully

use Test::Most  qw/bail !blessed/;
use Scalar::Util qw/blessed/;

BEGIN
{
    my @modules =
      qw{
	  Flutterby
	  Flutterby::Tree::Find
	  Flutterby::Util
	  Flutterby::Config
	  Flutterby::Spamcatcher
	  Flutterby::DBUtil
	  Flutterby::Users

	  Flutterby::Output::Text
	  Flutterby::Output::HTMLProcessed
	  Flutterby::Output::HTML
	  Flutterby::Output::SHTMLProcessed

	  Flutterby::Parse::FullyEscapedString
	  Flutterby::Parse::DayOfWeek
	  Flutterby::Parse::Month
	  Flutterby::Parse::Int
	  Flutterby::Parse::String
	  Flutterby::Parse::HTMLUtil
	  Flutterby::Parse::Ordinal
	  Flutterby::Parse::Text
	  Flutterby::Parse::HTML
      };
    plan tests => scalar @modules;

    use_ok $_ for @modules;
}
done_testing;
