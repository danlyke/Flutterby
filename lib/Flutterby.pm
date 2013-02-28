use strict;
use warnings;
package Flutterby;

# ABSTRACT: modules for managing web content



1;



__END__

=head1 NAME

Flutterby - modules for managing web content

=head1 SYNOPSIS

 use Flutterby::Parse::Text;
 $p = new Flutterby::Parse::Text();

 $tree = $p->parse(string);

 # Parse directly from file
 $tree = $p->parse_file("foo.html");
 # or
 open(F, "foo.html") || die;
 $tree = $p->parse_file(*F);

=head1 DESCRIPTION

The C<Flutterby> class hierarchy has evolved to support the web
content management system that supports Flutterby.com.
