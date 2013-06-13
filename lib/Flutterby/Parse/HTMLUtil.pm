#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::HTMLUtil;


sub new()
{
    my ($type,%args) = @_;
    my $class = ref($type) || $type;
    my ($self) = {};
    foreach (keys %args) {
        $self->{$_} = $args{$_}
            if (defined({
                         -alwaysallowtags => 1,
                        }->{$_}));
    }
    return bless($self, $class);
}

my (%entitylist_head_content) =
    (
     'title' => 1,
     'isindex' => 1,
     'base' => 1
    );
my (%entitylist_head_misc) =
    (
     'script' => 1,
     'style' => 1,
     'meta' => 1,
     'link' => 1
    );
my (%entitylist_heading) =
    (
     'h1' => 1,
     'h2' => 1,
     'h3' => 1,
     'h4' => 1,
     'h5' => 1,
     'h6' => 1
    );

my (%entitylist_font) =
    (
     'tt' => 1,
     'i' => 1,
     'b' => 1,
     'u' => 1,
     'strike' => 1,
     'big' => 1,
     'small' => 1,
     'sub' => 1,
     'sup' => 1
    );
my (%entitylist_phrase) =
    (
     'em' => 1,
     'strong' => 1,
     'dfn' => 1,
     'code' => 1,
     'q' => 1,
     'samp' => 1,
     'kbd' => 1,
     'var' => 1,
     'cite' => 1,
     'abbr' => 1,
     'acronym' => 1,
    );
my (%entitylist_special) =
    (
     'a' => 1,
     'img' => 1,
     'embed' => 1,
     'applet' => 1,
     'font' => 1,
     'basefont' => 1,
     'br' => 1,
     'script' => 1,
     'map' => 1
    );
my (%entitylist_form) =
    (
     'input' => 1,
     'select' => 1,
     'textarea' => 1
    );

my (%entitylist_text) =
    (
     '#pcdata' => 1,
     %entitylist_font,
     %entitylist_phrase,
     %entitylist_special,
     %entitylist_form,
    );
my (%entitylist_list) =
    (
     'ul' => 1,
     'ol' => 1,
     'dir' => 1,
     'menu' => 1
    );
my (%entitylist_preformatted) =
    (
     'pre' => 1
    );


my (%entitylist_block) =
    (
     'div' => 1,
     'p' => 1,
     %entitylist_list,
     %entitylist_preformatted,
     'dl' => 1,
     'div' => 1,
     'center' => 1,
     'blockquote' => 1,
     'form' => 1,
     'isindex' => 1,
     'hr' => 1,
     'table' => 1
    );

my (%entitylist_body_content) =
    (
     %entitylist_heading,
     %entitylist_text,
     %entitylist_block,
     'address' => 1
    );
my (%entitylist_address_content) =
    (
     %entitylist_text,
     'p' => 1,
    );


my (%entitylist_flow) =
    (
     %entitylist_text,
     %entitylist_block,
    );


my (%entitylist_pre_exclusion) =
    (
     'img' => 1,
     'embed' => 1,
     'big' => 1,
     'small' => 1,
     'sub' => 1,
     'sup' => 1,
     'font' => 1
    );


my (%elementlist_isempty) =
    (
     'isindex' => 1,
     'base' => 1,
     'meta' => 1,
     'link' => 1,
     'hr' => 1,
     'input' => 1,
     'img' => 1,
     'embed' => 1,
     'param' => 1,
     'basefont' => 1,
     'area' => 1,
     'br' => 1,
     'col' => 1,
    );

my (%entitylist_html_content) =
    (
     'head' => 1,
     'body' => 1,
    );
my (%entitylist_list_content) =
    (
     'li' => 1,
    );
my (%entitylist_definition_list_content) =
    (
     'dt' => 1,
     'dd' => 1,
    );
my (%entitylist_table_content) =
    (
     'caption' => 1,
     'thead' => 1,
     'tfoot' => 1,
     'col' => 1,
     'colgroup' => 1,
     'tbody' => 1,
     'tr' => 1,
    );
my (%entitylist_colgroup_content) =
    (
     'col' => 1,
    );
my (%entitylist_theadfootbody_content) =
    (
     'tr' => 1,
    );
my (%entitylist_table_row_content) =
    (
     'th' => 1,
     'td' => 1,
    );
my (%entitylist_select_content) =
    (
     'option' => 1,
    );
my (%entitylist_map_content) =
    (
     'area' => 1,
    );

my (%entitylist_head_and_body_content) =
    (
     %entitylist_body_content,
     %entitylist_head_content,
    );
   

my (%entitylist_pcdata) = 
    (
     '#pcdata' => 1
    );
my (%entitylist_cdata) =
    (
     '#cdata' => 1
    );
my (%entitylist_empty) = 
    (
    );
my (%entitylist_head_all) = (%entitylist_head_content, %entitylist_head_misc);
my (%entitylist_text_plus_param) = (%entitylist_text, 'param' => 1);


my (%elementsToEntityLists) =
    (
     'head' => \%entitylist_head_all,
     'title' => \%entitylist_pcdata,
     'style' => \%entitylist_cdata,
     'script' => \%entitylist_cdata,
     'isindex' => \%entitylist_empty,
     'base' => \%entitylist_empty,
     'meta' => \%entitylist_empty,
     'link' => \%entitylist_empty,
     'body' => \%entitylist_body_content,

     'h1' => \%entitylist_text,
     'h2' => \%entitylist_text,
     'h3' => \%entitylist_text,
     'h4' => \%entitylist_text,
     'h5' => \%entitylist_text,
     'h6' => \%entitylist_text,

     'address' =>\%entitylist_address_content,
     'p' => \%entitylist_text,
     'ul' => \%entitylist_list_content,
     'li' => \%entitylist_flow,
     'ol' => \%entitylist_list_content,
     'dl' => \%entitylist_definition_list_content,
     'dt' => \%entitylist_text,
     'dd' => \%entitylist_flow,
     'dir' => \%entitylist_list_content,
     'menu' => \%entitylist_list_content,
     'pre' => \%entitylist_text,
     'div' => \%entitylist_body_content,
     'center' => \%entitylist_body_content,
     'blockquote' => \%entitylist_body_content,
     'form' => \%entitylist_body_content,
     'hr' => \%entitylist_empty,
     'table' => \%entitylist_table_content,
     'thead' => \%entitylist_theadfootbody_content,
     'tfoot' => \%entitylist_theadfootbody_content,
     'tbody' => \%entitylist_theadfootbody_content,
     'colgroup' => \%entitylist_colgroup_content,
     'tr' => \%entitylist_table_row_content,
     'th' =>\%entitylist_body_content,
     'td' =>\%entitylist_body_content,
     'caption' =>\%entitylist_text,
     'input' => \%entitylist_empty,
     'select' => \%entitylist_select_content,
     'option' => \%entitylist_pcdata,
     'textarea' => \%entitylist_pcdata,
     'a' => \%entitylist_text,
     'img' => \%entitylist_empty,
     'embed' => \%entitylist_empty,
     'applet' => \%entitylist_text_plus_param,
     'param' => \%entitylist_empty,
     'font' => \%entitylist_text,
     'basefont' => \%entitylist_empty,
     'map' => \%entitylist_map_content,
     'area' => \%entitylist_empty,

     'tt' => \%entitylist_text,
     'i' => \%entitylist_text,
     'b' => \%entitylist_text,
     'u' => \%entitylist_text,
     'strike' => \%entitylist_text,
     'big' => \%entitylist_text,
     'small' => \%entitylist_text,
     'sub' => \%entitylist_text,
     'sup' => \%entitylist_text,
     'em' => \%entitylist_text,
     'strong' => \%entitylist_text,
     'dfn' => \%entitylist_text,
     'code' => \%entitylist_text,
     'q' => \%entitylist_text,
     'samp' => \%entitylist_text,
     'kbd' => \%entitylist_text,
     'var' => \%entitylist_text,
     'cite' => \%entitylist_text,
     'abbr' => \%entitylist_text,
     'acronym' => \%entitylist_text,
 
     'br' => \%entitylist_empty,
     'hr' => \%entitylist_empty,
     'html' => \%entitylist_html_content,
    );

sub isEmpty($)
{
    my ($tag) = @_;
    my ($self);
    if (ref($tag)) {
        ($self,$tag) = @_;
    }
    return $elementlist_isempty{$tag};
}
sub isValidSubtag($$)
{
    my ($tag, $subtag) = @_;
    my ($self);
    if (ref($tag)) {
        ($self,$tag) = @_;
    }
    return 1 if (defined($self->{-alwaysallowtags})
                 and defined($self->{-alwaysallowtags}->{$tag}));

    return defined($elementsToEntityLists{$tag})
        and defined($elementsToEntityLists{$tag}->{$subtag})
    }


my (%userAllowedTagSubset) = 
    (
     # heading
     'h1' => 1,
     'h2' => 1,
     'h3' => 1,
     'h4' => 1,
     'h5' => 1,
     'h6' => 1,

     # font
     'tt' => 1,
     'i' => 1,
     'b' => 1,
     'u' => 1,
     'strike' => 1,
     'big' => 1,
     'small' => 1,
     'sub' => 1,
     'sup' => 1,

     # phrase
     'em' => 1,
     'strong' => 1,
     'dfn' => 1,
     'code' => 1,
     'q' => 1,
     'samp' => 1,
     'kbd' => 1,
     'var' => 1,
     'cite' => 1,
     'abbr' => 1,
     'acronym' => 1,

     # special
     'a' => 1,
     'img' => 1,
     'embed' => 1,
     'font' => 1,
     'br' => 1,
     'map' => 1,

     # related to map
     'area' => 1,

     # list
     'ul' => 1,
     'ol' => 1,
     'dir' => 1,
     'menu' => 1,
     'li' => 1,

     # preformatted
     'pre' => 1,

     #block
     'dl' => 1,
     'dd' => 1,
     'dt' => 1,
     'center' => 1,
     'blockquote' => 1,
     'form' => 1,
     'isindex' => 1,
     'hr' => 1,
     'table' => 1,
     'tr' => 1,
     'td' => 1,

     # content
     'address' => 1,

     # inputs
     'input' => 1,
     'select' => 1,
     'textarea' => 1,

     # select content
     'option' => 1,

     # other
     'p' => 1,
     'div' => 1,

     # damn
     'html' => 1,
     'head' => 1,
     'title' => 1,
     'body' => 1,
     'meta'=> 1,
    );

sub userAllowedTagHashref()
{
    return \%userAllowedTagSubset;
}

sub userAllowedTag($)
                   {
                       my ($tag) = @_;
                       return $userAllowedTagSubset{$tag};
                   }

                   sub whatever
                   {
                       foreach (keys %entitylist_address_content) {
                           print "$_\n";
                       }
                   }

                   1;



                   __END__


=head1 NAME

Flutterby::Parse::HTMLUtil - Simple tools to describe HTML structure

=head1 SYNOPSIS

 use Flutterby::Parse::HTMLUtil;
 $util = new Flutterby::Parse::HTMLUtil();

 print "Tag should contain no data\n" if ($util->isEmpty('<img>';

=head1 DESCRIPTION

C<Flutterby::Parse::HTMLUtil> is a simplification of whatever HTML DTD
I've decided to support at any given moment. Currently it's most of
HTML4 loose, I will be changing it to strict as I switch over to style
sheets.

