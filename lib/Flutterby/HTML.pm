#!/usr/bin/perl -w
use strict;
package Flutterby::HTML;
use Flutterby::Parse::HTML;


sub LoadHTMLFileAsTree
  {
    my ($file) = @_;
    my ($p);
    $p = new Flutterby::Parse::HTML(-alwaysallowtags => 
				    { 
				     'flutterbyquery' => 1,
 				     'flutterbyrow' => 1,
 				     'flutterbycolordep' => 1,
				    },
				    -parsecommentbody => 1,
				    -allowalltags => 1,
				   );
    my ($tree) = $p->parsefile($file);
    die "Unable to open $file\n" unless $tree;
    return $tree;
  }

1;
