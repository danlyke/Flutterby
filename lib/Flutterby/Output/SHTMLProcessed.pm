#!/usr/bin/perl -w
use strict;
package Flutterby::Output::SHTMLProcessed;
use Flutterby::Output::HTMLProcessed;
use vars qw(@ISA);

sub BEGIN
  {
    @ISA = qw(Flutterby::Output::HTMLProcessed);
  }

sub new()
  {
    my ($type,%args) = @_;
    my $class = ref($type) || $type;
    
    my ($self) = new Flutterby::Output::HTMLProcessed(%args);
    $self->{-classcolortags} = {};
    $self->{-classcolortags} = $args{-classcolortags}
      if (defined($args{-classcolortags}));

    my (%overridetags) =
      (
      );

    foreach (keys %overridetags)
      {
	$self->{-overridetags}->{$_} = $overridetags{$_};
#	  unless (exists($self->{-overridetags}->{$_}));
      }
    $self->{-colorscheme} = $args{-colorscheme};
    return bless($self, $class);
  }
1;
