#!/usr/bin/perl -w
use strict;
package Flutterby::Parse::Text;
use base 'Flutterby::Parse::HTML';
use HTML::Entities;
use Flutterby::Parse::HTMLUtil;
use Flutterby::Util;

sub new
{
    my ($type,%args) = @_;
    my $class = ref($type) || $type;

    my $self = {-textglossary => {}};

    $self->{-htmlparser} = new Flutterby::Parse::HTML(%args,
                                                      -allowalltags => 1);
    return bless($self, $class);
}



sub FormatString($@)
{
    my ($self) = shift;
    my ($text);
    my ($outfunc) = $self->{-outfunc};

    while ($text = shift) {
        $text =~ s/\</\&lt\;/sg;
        $text =~ s/\>/\&gt\;/sg;
        while ($text =~ s/^(.*?\&)//s) {
            $self->{-htmlparser}->parse($1);
            $self->{-htmlparser}->parse('amp;') unless ($text =~ /^(\w+|\#\d+);/);
        }
        $self->{-htmlparser}->parse($text);
    }
}

sub AddOutputLink($$$)
{
    my ($self,$text,$url) = @_;
    my ($outfunc) = $self->{-outfunc};
    my ($tagcount,$tagstack);
    $tagstack = $self->{-tagstack};
    $tagcount = $self->{-tagcount};
    if ($tagcount->{'a'}) {
        $self->{-htmlparser}->parse('<cite>');
        FormatString($self,$text);
        $self->{-htmlparser}->parse('</cite>');
    } else {
        $self->{-htmlparser}->parse("<a href=\"$url\">");
        FormatString($self,$text);
        $self->{-htmlparser}->parse('</a>');
    }
}

sub FindInGlossary($$)
{
    my ($self,$text) = @_;
    my ($outfunc) = $self->{-outfunc};
    if (defined($self->{-textglossary}->{$text})) {
        $self->{-htmlparser}->parse("<a href=\"$self->{-textglossary}->{$text}\">");
        FormatString($self,$text);
        $self->{-htmlparser}->parse("</a>");
    } else {
        $self->{-htmlparser}->parse('<cite>');
        FormatString($self,$text);
        $text =~ s/\s+/ /g;
        $text =~ s/\&/%26/g;
        $self->{-htmlparser}->parse('<a href="/wiki/'
                                    .HTML::Entities::encode($text).
                                    '"><img border="0" src="/adbanners/lookingglass.png" alt="[Wiki]" width="12" height="12"></a>');
        $self->{-htmlparser}->parse('</cite>');
    }
}
sub MatchURLsForLinks($$)
{
    my ($self,$text) = @_;
    while ($text =~ s/^(.*?|.*?[^""])((https?|ftp):[^"\)\s ]*[^",.\)\s ])//sg) {
        FormatString($self, $1);
        my ($l, $t);
        $l = $2;
        $t = $2;

        $t = substr($l,0,30).'...'.substr($l,-32)
            if (length($t) > 64);
        AddOutputLink($self,$t,$l);
    }
    FormatString($self,$text);
}

sub AddToGlossary($$$)
{
    my ($self, $ref, $url) = @_;
    $self->{-textglossary}->{$ref} = $url
        if (defined($ref) && defined($url));
}

sub FormatChunk($@)
{
    my ($self) = shift;

    my ($text);
    while ($text = shift) {
        while ($text =~ s/^(|.*?\s)_(\w|[\w\'\"][^_]*?[\w\'\"\?\!\)])_\s*
                          ((|\'s|[\(\,\.\?\:\;\!])(|[\s\(].*))$/$3/xsi) {
            MatchURLsForLinks($self,$1);
            my ($ref);
            $ref = $2;
            if ($text =~ s/^\s*\(((https?|ftp|wiki|position|address)\:(.*?))\)((|\'s|[\,\.\?\:\;\!])(\s.*|))$/$4/xsi) {
                if ($2 eq 'wiki') {
                    $self->{-htmlparser}->parse('<cite>');
                    FormatString($self,$ref);
                    $self->{-htmlparser}->parse('<a href="/wiki/'
                                                .HTML::Entities::encode($3).
                                                '"><img border="0" src="/adbanners/lookingglass.png" alt="[Wiki]" width="12" height="12"></a>');
                    $self->{-htmlparser}->parse('</cite>');

                } elsif ($2 eq 'position') {
                    FormatString($self,$ref);
                    my $addr = $ref;

                    $addr = $3 if (defined($3) && $3 ne '');

                    $self->{-htmlparser}->parse('<a href="/archives/mapit.cgi?pos='
                                                .HTML::Entities::encode($3).
                                                '"><img border="0" src="/adbanners/compass.png" alt="[Map]" width="12" height="12"></a>');
                } elsif ($2 eq 'address') {
                    FormatString($self,$ref);
                    my $addr = $ref;

                    $addr = $3 if (defined($3) && $3 ne '');

                    $self->{-htmlparser}->parse('<a href="/archives/mapit.cgi?addr='
                                                .HTML::Entities::encode($3).
                                                '"><img border="0" src="/adbanners/compass.png" alt="[Map]" width="12" height="12"></a>');
                } else {
                    #		AddToGlossary($self,$ref,$1);
                    AddOutputLink($self,$ref,$1);
                }
            } else {
                FindInGlossary($self,$ref);
            }
        }
        MatchURLsForLinks($self,$text);
    }
}


sub FormatParagraph
{
    my ($self,$text) = @_;

    my ($outfunc) = $self->{-outfunc};
    my ($tagstack, $tagcount);
    my ($userAllowedTagSubset);
    $userAllowedTagSubset = 
        Flutterby::Parse::HTMLUtil::userAllowedTagHashref();

    $tagstack = $self->{-tagstack};
    $tagcount = $self->{-tagcount};

    $text =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f]//g;
    while ($text =~ /^(.*?)([\x80-\xff])(.*)$/) {
        $text = sprintf('%s&#%d;%s', $1,ord($2),$3);
    }

    while ($text =~ s/^(.*?)\<(\/?)([a-z]\w*)(.*?)\>//si) {
        my ($pre, $close, $tag, $attrs) = ($1,$2,lc($3),$4);
        my ($tagcontents);

        # do stuff to $pre
        $self->FormatChunk($pre);
	
        $close = '' unless defined($close);
        $attrs = '' unless defined($attrs);
        if (defined($userAllowedTagSubset->{$tag})) {
            my ($outattrs);
            $outattrs = '';
            while (($attrs =~ s/^\s*([a-z]+\w*)\s*\=\s*\"([^\"]*)\"\s*//i)
                   || ($attrs =~ s/^\s*([a-z]+\w*)\s*\=\s*(\S+)\s*//i)
                   || ($attrs =~ s/^\s*([a-z]+\w*)\s*\=\s*\"([^\"]*)\"?\s*//i)) {
                $outattrs .= " $1=\"$2\"";
            }

            $tagcontents = "<$close$tag$outattrs>";
        } else {
            $tagcontents = "\&lt\;$close$tag$attrs&gt\;";
        }
        $self->{-htmlparser}->parse($tagcontents);
    }

    $self->FormatChunk($text) if ($text ne '');
}

sub HandleParagraphType($$$)
{
    my ($self, $lastinfo, $para) = @_;
    my ($outfunc) = $self->{-outfunc};

    if ($para =~ /^(([^\n\:]+\:\ *\n)?( *\w{0,3} *[\>])([^\n]*)(\n\3[^\n]*)+)\n*$/s) {
        # quoted text. Preformat.

        $self->{-htmlparser}->parse($lastinfo->{-posttags})
            if (defined($lastinfo->{-posttags}));
        delete($lastinfo->{-posttags});
        $self->{-htmlparser}->parse("<pre>\n");
        FormatParagraph($self,$para);
        $self->{-htmlparser}->parse("</pre>\n")	
    } elsif ($para =~ /^(\#|\/\*)\ /s) {
        # code. Preformat.

        $self->{-htmlparser}->parse($lastinfo->{-posttags})
            if (defined($lastinfo->{-posttags}));
        delete($lastinfo->{-posttags});
        $self->{-htmlparser}->parse("<pre>\n");
        FormatParagraph($self,$para);
        $self->{-htmlparser}->parse("</pre>\n")	
    } elsif ($para =~ /^( *)([\*])( +)([^\n]*)(\n(\1\2\3|\1 \3)[^\n]*)*\n*$/s) {
        # unnumbered list
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</ul>\n") {
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<ul>");
            }
        } else {
            $self->{-htmlparser}->parse("<ul>");
        }
        $lastinfo->{-posttags} = "</ul>\n";
        while ($para =~ s/^\n*( *)([\*])( +)([^\n]*(\n(\1 \3)[^\n]*)*)//s) {
            $self->{-htmlparser}->parse("<li>");
            FormatParagraph($self,$4);
            $self->{-htmlparser}->parse("</li>\n");
        }
    } elsif ($para =~ /^( *)(\d+)([\.\)\:\,\;]\ ).*?(\n \d+\3.*?)*$/s) {
        # numbered list
        my ($start) = $2;
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</ol>\n" 
                or (defined($lastinfo->{-listtype}) and $lastinfo->{-listtype} ne '1')) {
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<ol type=\"1\" start=\"$start\">");
                $lastinfo->{-listtype} = '1';
            }
        } else {
            $self->{-htmlparser}->parse("<ol type=\"1\" start=\"$start\">");
            $lastinfo->{-listtype} = '1';
        }
        $lastinfo->{-posttags} = "</ol>\n";
        while ($para =~ s/^\n*( *)(\d+)([\.\)\:\,\;]\ )(.*?)((\n *\d+\3.*?)*)$/$5/s) {
            my ($newstart) = $2;
            if ($newstart eq $start) {
                $self->{-htmlparser}->parse("<li>");
            } else {
                $self->{-htmlparser}->parse("<li value=\"$newstart\">");
            }

            $start = $newstart;
            $start++;
            FormatParagraph($self,$4);
            $self->{-htmlparser}->parse("</li>");
        }
    } elsif ($para =~ /^( *)([xvi]+)([\.\)\:]\ ).*?(\n [xvi]+\3.*?)*$/s) {
        # lower roman list
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</ol>\n" 
                or (defined($lastinfo->{-listtype}) and $lastinfo->{-listtype} ne 'i')) {
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<ol type=\"i\">");
                $lastinfo->{-listtype} = 'i';
            }
        } else {
            $self->{-htmlparser}->parse("<ol type=\"i\">");
            $lastinfo->{-listtype} = 'i';
        }
        $lastinfo->{-posttags} = "</ol>\n";
        while ($para =~ s/^\n*( *)([xvi]+)([\.\)\:])(.*?)((\n *[xvi]+\3.*?)*)$/$5/s) {
            $self->{-htmlparser}->parse("<li>");
            FormatParagraph($self,$4);
            $self->{-htmlparser}->parse("</li>");
        }
    } elsif ($para =~ /^( *)([XVI]+)([\.\)\:]\ ).*?(\n [XVI]+\3.*?)*$/s) {
        # upper roman list
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</ol>\n" 
                or (defined($lastinfo->{-listtype}) and $lastinfo->{-listtype} ne 'I')) {
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<ol type=\"I\">");
                $lastinfo->{-listtype} = 'I';
            }
        } else {
            $self->{-htmlparser}->parse("<ol type=\"I\">");
            $lastinfo->{-listtype} = 'I';
        }
        $lastinfo->{-posttags} = "</ol>\n";
        while ($para =~ s/^\n*( *)([XVI]+)([\.\)\:])(.*?)((\n *[XVI]+\3.*?)*)$/$5/s) {
            $self->{-htmlparser}->parse("<li>");
            FormatParagraph($self,$4);
            $self->{-htmlparser}->parse("</li>");
        }
    } elsif ($para =~ /^( *)([A-Z])([\.\)\:]\ )[^\n]*?(\n [A-Z]\3[^\n]*?)*$/s) {
        # upper alpha numbered list
        my ($start) = 1 + (ord($2) - ord('A'));
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</ol>\n" 
                or (defined($lastinfo->{-listtype}) and $lastinfo->{-listtype} ne 'A')) {
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<ol type=\"A\" start=\"$start\">");
                $lastinfo->{-listtype} = 'A';
            }
        } else {
            $self->{-htmlparser}->parse("<ol type=\"A\" start=\"$start\">");
            $lastinfo->{-listtype} = 'A';
        }
        $lastinfo->{-posttags} = "</ol>\n";
        while ($para =~ s/^\n*( *)([A-Z])([\.\)\:]\ )(.*?)((\n *[A-Z]\3.*?)*)$/$5/s) {
            my ($newstart) = 1 + (ord($2) - ord('A'));
            $self->{-htmlparser}->parse("</ol><ol type=\"A\" start=\"$newstart\">")
                if ($start ne $newstart);
            $start = $newstart;
            $start++;

            $self->{-htmlparser}->parse("<li>");
            FormatParagraph($self,$4);
            $self->{-htmlparser}->parse("</li>");
        }
    } elsif ($para =~ /^( *)([a-z])([\.\)\:]\ ).*?(\n [a-z]\3.*?)*$/s) {
        my ($start) = 1 + (ord($2) - ord('a'));
        # lower alpha numbered list
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</ol>\n" 
                or (defined($lastinfo->{-listtype}) and $lastinfo->{-listtype} ne 'a')) {
                delete($lastinfo->{-liststart});
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<ol type=\"a\" start=\"$start\">");
                $lastinfo->{-listtype} = 'a';
            }
        } else {
            $self->{-htmlparser}->parse("<ol type=\"a\" start=\"$start\">");
            $lastinfo->{-listtype} = 'a';
        }
        $lastinfo->{-posttags} = "</ol>\n";
        while ($para =~ s/^\n*( *)([a-z])([\.\)\:]\ )(.*?)((\n *[a-z]\3.*?)*)$/$5/s) {
            my ($newstart) = 1 + (ord($2) - ord('a'));
            $self->{-htmlparser}->parse("</ol><ol type=\"a\" start=\"$newstart\">")
                if ($start ne $newstart);
            $start = $newstart;
            $start++;

            $self->{-htmlparser}->parse("<li>");
            FormatParagraph($self,$4);
            $self->{-htmlparser}->parse("</li>");
        }
    } elsif ($para =~ /^( +)([^\s][^\n]*)(\n\1[^\s][^\n]*)*\n*$/s) {
        # blockquote indent
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</blockquote>\n") {
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<blockquote>");
            }
        } else {
            $self->{-htmlparser}->parse("<blockquote>");
        }
        $lastinfo->{-posttags} = "</blockquote>\n";
        $self->{-htmlparser}->parse("<p>");
        FormatParagraph($self,$para);
        $self->{-htmlparser}->parse("</p>\n\n");
    } elsif ($para =~ s/^\s*\<blockquote\s*.*?\>(.*?)\<\/blockquote\s*\>\s*$/$1/si) {
        # blockquote indent
        if (defined($lastinfo->{-posttags})) {
            if ($lastinfo->{-posttags} ne "</blockquote>\n") {
                $self->{-htmlparser}->parse($lastinfo->{-posttags});
                $self->{-htmlparser}->parse("<blockquote>");
            }
        } else {
            $self->{-htmlparser}->parse("<blockquote>");
        }
        $lastinfo->{-posttags} = "</blockquote>\n";
        $self->{-htmlparser}->parse("<p>");
        FormatParagraph($self,$para);
        $self->{-htmlparser}->parse("</p>\n\n");
    } else {
        $self->{-htmlparser}->parse($lastinfo->{-posttags}) 
            if (defined($lastinfo->{-posttags}));
        delete($lastinfo->{-posttags});
        $self->{-htmlparser}->parse("<p>");
        FormatParagraph($self,$para);
        $self->{-htmlparser}->parse("</p>\n\n");
    }
}

sub BreakIntoParagraphs($$)
{
    my ($self,$text) = @_;
    if (defined($text)) {
        if ($text =~ /\n/) {
            $text =~ s/\r\r+/\n\n/g;
            $text =~ s/\r//g;
        } else {
            $text =~ s/\r/\n/g;
        }
        my ($lastinfo) = {};
        $text =~ s/(\<blockquote\s*.*?\>)/\n\n$1/sig;
        $text =~ s/(\<\/blockquote\s*\>)/$1\n\n/sig;
        while ($text =~ s/^\n*(.*?)(\n(\ *\n)+)//s) {
            HandleParagraphType($self, $lastinfo, $1);
        }
        HandleParagraphType($self, $lastinfo, $text)
            if (defined($text) and $text ne '');
    }
}

sub parsefile
{
    my ($self) = shift @_;

    my ($parseinprogress) = $self->{-parseinprogress};

    $self->flutterby_begin_parse() unless ($parseinprogress);
    foreach (@_) {
        open(FCMSTEXT_I, $_)
            || die "Unable to open $_\n";
        $self->parse(join('',<FCMSTEXT_I>));
        close FCMSTEXT_I;
    }
    $self->flutterby_end_parse() unless ($parseinprogress);

    return $self->{-tree};
}

sub parse_file
{
    &parsefile(@_);
}

sub parse
{
    my ($self, $t) = @_;
    $t = '' unless defined($t);
    my ($parser) = $self->{-htmlparser};
    $parser->flutterby_begin_parse();
    $parser->parse('<html><body>');
    $t =~ s/\r|\<\/p\>//sig;
    $t =~ s/\<p\>/\n\n/sig;
    $self->BreakIntoParagraphs($t);
    $parser->parse('</body></html>');
    return $parser->flutterby_end_parse();
}

1;




__END__


=head1 NAME

Flutterby::Parse::Text - Text parser class

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

The C<Flutterby::Parse::Text> class was developed from some simple
scripts that created HTML from the way I wrote email and text
files. It creates an C<XML::Parser> style tree, which can then be
manipulated, and output using one of the C<Flutterby::Output>
routines.

It allows a reasonable subset of HTML to be input, ampersand escapes
all unrecognized tags, leaves entities in place when it recognizes
them from the standard set, and does a pretty good job of finding list
structure, code elements, URLs, and other text that should be
preformatted.

It also recognizes constructs of the form _underlined text_
(http://www.example.com/) and turns them into links, for text which
can both be sent to humans and automatically turned into links.

It's not infallible, and the grammar doesn't allow expression of every
possibility, C<Flutterby::Parse::HTML> or a similar parser should be
offered to users as well.
