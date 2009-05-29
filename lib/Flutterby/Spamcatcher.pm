#!/usr/bin/perl -w
use strict;
package Flutterby::Spamcatcher;

sub IsSpamReferer($)
{
    my ($url) = @_;

    return undef if !defined($url);
    return $url =~ /(hardcore|bustyqueens|lingeriecastle|porno-holic|
		     smut-4-free|nudeebonygirls|ambien|
		     dir\.home\.bir\.ru|hydrocodone|talented-doctor|
		     tramadol|puttane-grandi-tette|pills-sale|viagra|
		     fioricet|metasart|amatoriale|euro-rape|grandfuck|
		     teensgangbang|gay-mpg|glamourporngirls|
		     tina-sex-journal|-porno-|teenies-posing|
		     hardteenaction|teensgangbang|seductivepantyhose|
		     ultrafuckers|pornocontent|
		     asi[ae]nxxxcore|casino|100freegalls|
		     teenies-posing|only-hardcore-sex|fuckthispussy|
		     teenspray|hardcore|nylonhome|assfuckher|grandfuck|
		     teenshot|lesbiche|vip-pics|zone-erotic|wetteenager|
		     upskirt|xtratits|reelcrazycunts|nylonhome|
		     health-insurance|credit|mortgage|money|payday
		     |aiansoftcore|mature-porn|boobed|girls)/xi;
	
}







1;

