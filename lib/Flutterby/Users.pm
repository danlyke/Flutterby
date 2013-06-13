#!/usr/bin/perl -w
use strict;
package Flutterby::Users;
use Flutterby::Util;
use URI::Escape;
use LWP::Simple;
use File::Temp;
use vars qw(%webloginfocache %weblogurlcache);


my $secretsalt = 'aachatahsooxeeng7lo5aifietahphuN';
# See comments below

sub GetWeblogID($$)
{
    my ($url, $dbh) = @_;
    my ($sql, $sth, $row);
	$url = $url->url if (ref($url));
    $url =~ s/^(.*?\/\/.*?\/).*$/$1/;

    unless (defined($weblogurlcache{$url})) {
        $sql = 'SELECT weblogs.id FROM weblogs,urls WHERE weblogs.url_id=urls.id'
            .' AND urls.url='.$dbh->quote($url);
        $sth = $dbh->prepare($sql)
            || die $dbh->errstr;
        $sth->execute()
            || die $sth->errstr;
        if ($row = $sth->fetchrow_arrayref()) {
            $weblogurlcache{$url} = $row->[0];
        } else {
            $weblogurlcache{$url} = 1;
        }
    }
    return $weblogurlcache{$url} if (defined($weblogurlcache{$url}));
}

sub GetWeblogInfo($$@)
{
    my ($cgi, $dbh, $weblogid) = @_;
	my $url = ref($cgi)? $cgi->url() : $cgi;

    $weblogid = GetWeblogID($url, $dbh) unless defined($weblogid);

    unless (defined($webloginfocache{$weblogid})) {
        my ($sql, $sth, $row);
        $sql = 'SELECT * FROM weblogs WHERE id='.$dbh->quote($weblogid);

        $sth = $dbh->prepare($sql)
            || die $dbh->errstr;
        $sth->execute()
            || die $sth->errstr;
        $row = $sth->fetchrow_hashref();

        my ($k, $v, %r);
        while (($k,$v) = each %$row) {
            $r{"fcmsweblog_$k"} = $v;
        }
        $webloginfocache{$weblogid} = \%r;
    }
    return $webloginfocache{$weblogid}
}

sub UpdateUser($$$$)
{
    my ($cgi, $dbh, $fields, $terms) = @_;
    
    my @data;
    
    for (@$fields) {
        if ($_ eq 'password') {
            if ($cgi->param("_$_")) {
                my $sql = "SELECT name FROM users WHERE $terms";
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                if (my $row = $sth->fetchrow_arrayref()) {
                    push @data, "$_=encode(digest("
                        .join('||',
                              map
                              {
                                  $dbh->quote($_) }
                              $row->[0],
                              $cgi->param("_$_"),
                              $secretsalt)
                            .",'sha512'::text), 'hex')";
                }
            }
        } else {
            push @data, "$_=".$dbh->quote($cgi->param("_$_"))
                if (defined($cgi->param("_$_")));
        }
    }
    my $sql = 'UPDATE USERS SET '
        .join(', ', @data)
            ." WHERE $terms";
    $dbh->do($sql);
}



sub GetSqlIfLoginInfo($$)
{
    my ($cgi, $dbh) = @_;
    my ($sql,$error);

    if (defined($cgi->param('clientid'))
        && defined($cgi->param('action'))
        && defined($cgi->param('ts'))
        && defined($cgi->param('ticket'))
        && defined($cgi->param('credtype'))
        && defined($cgi->param('credential'))
        && $cgi->param('action') eq 'sso-approved'
        && ($cgi->param('credtype') eq 'gpg --clearsign'
            || $cgi->param('credtype') eq 'gpg -clearsign')) {
        my $newKey = LWP::Simple::get($cgi->param('clientid')
                                      .'?meta=gpg%20--export%20--armor');

        if (!defined($newKey) || $newKey !~ /BEGIN PGP PUBLIC KEY BLOCK/) {
            $newKey = LWP::Simple::get($cgi->param('clientid')
                                       .'?meta=gpg%20-export%20--armor');
        }
	
        if ($newKey =~ m/BEGIN PGP PUBLIC KEY BLOCK/ ) {
            my $url = Flutterby::Util::determineUrl( $cgi );
            my $action     = $cgi->url_param( 'action' );
            my $clientid   = $cgi->url_param( 'clientid' );
            my $credential = $cgi->url_param( 'credential' );
            my $credtype   = $cgi->url_param( 'credtype' );
            my $ts         = $cgi->url_param( 'ts' );
            my $ticket     = $cgi->url_param( 'ticket' );
	    
            my ($keyFh, $keyFilename) = File::Temp::tempfile( UNLINK => 0 );
            print $keyFh $newKey;
            close $keyFh;
            my $gpg = '/usr/bin/gpg --homedir /home/flutterby/gpg ';
            my $cmd = $gpg . " --import " . $keyFilename;
            `$cmd`;
            unlink $keyFilename;

            foreach my $paramseparator ('&', ';') {
                my $sign = join($paramseparator,
                                map {"$_=".uri_escape($cgi->param($_))}
                                ('action', 'clientid', 'credtype', 'ticket', 'ts'));

                # reconstruct the signed statement
                $url =~ s/(.*?)\?(.*?)\&credential=$credential(.*)/$2/;
                $url =~ s/(.*?)\?(.*?)\;credential=$credential(.*)/$2/;
		
                my @credlines = split /\n/, $credential;
		
                my $signedText = "-----BEGIN PGP SIGNED MESSAGE-----\n";
                $signedText .= "Hash: " . $credlines[0] . "\n";
                $signedText .= "\n";
                $signedText .= $url;
                my $query = $ENV{'QUERY_STRING'};
                $query =~ s/(.*?);credential=(.*)/$1/;
                $signedText .= "?" . $query;
                $signedText .= "\n";
                $signedText .= "-----BEGIN PGP SIGNATURE-----\n";
		
                shift @credlines; # that's the hash which we have already
                foreach my $line ( @credlines ) {
                    $signedText .= $line . "\n";
                }
                $signedText .= "-----END PGP SIGNATURE-----\n";
		
                my $signedTextFh;
                my $signedTextFilename;
		
                ($signedTextFh, $signedTextFilename) = File::Temp::tempfile( UNLINK => 0 );
                print $signedTextFh $signedText;
                close $signedTextFh;
		
                my $outputFh;
                my $outputFilename;
                ($outputFh, $outputFilename) = File::Temp::tempfile( UNLINK => 0 );
                close $outputFh;
		
                my $result = system( "cat $signedTextFilename | $gpg --verify 2>$outputFilename" );
                # Note that $result == 0 means *good*, not bad
		
                open( $outputFh, "<$outputFilename" );
		
                my @output = <$outputFh>;
                my $output = join('\n',@output);
                close $outputFh;
		
                unlink $signedTextFilename;
                unlink $outputFilename;
		
                if ( $result ) {
                    $error =  "Bad electronic signature on URL, cannot log on" ;
                }
                if ( $output =~ m/"(.*)"/ && $1 eq $clientid) {
                    my ($id) = $dbh->selectrow_array('SELECT id FROM users WHERE lid_url='
                                                     .$dbh->quote($clientid));
                    if (!$id) {
                        $sql = "select nextval('users_id_seq')";
                        my ($user_id);
                        ($user_id) = $dbh->selectrow_array($sql);
                        my $username = LWP::Simple::get($cgi->param('clientid')
                                                        .'?xpath=/VCARD/FN&action=text/xml');
                        $username =~ s/\<FN\>(.*)\<\/FN\>/$1/;
                        $username = $username." [LID/$user_id]";
			
                        $sql =
                            'INSERT INTO users (id,name,lid_url,emailconfirmcode,magiccookie) VALUES ('
                                .join(',',
                                      map { $dbh->quote($_) }
                                      (
                                       $user_id,
                                       $username,
                                       $clientid,
                                       Flutterby::Util::CreateRandomString(16),
                                       Flutterby::Util::CreateRandomString(16)
                                      )
                                     )
                                    .')';
                        $dbh->do($sql)
                            || print STDERR $dbh->errstr."\n$sql\n";;
                        my ($fcmsweblog_id);
                        $fcmsweblog_id = GetWeblogID($cgi, $dbh);
			
                        $sql = "INSERT INTO capabilities(user_id, weblog_id) VALUES ($user_id, $fcmsweblog_id)";
                        $dbh->do($sql)
                            || print STDERR $dbh->errstr."\n$sql\n";
                        last;
                    }
                }
		
                $sql = 'SELECT name,value FROM sessiontickets, sessionvalues WHERE sessionvalues.ticket_id=sessiontickets.id AND sessiontickets.session='.$dbh->quote($cgi->param('ticket'));
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                my $row;
                while ($row = $sth->fetchrow_arrayref()) {
                    $cgi->param(-name => $row->[0], -value => $row->[1]);
                }
                $sql = 'SELECT * FROM users,capabilities WHERE lid_url='
                    .$dbh->quote($cgi->url_param( 'clientid' ))
                        .' AND capabilities.user_id=users.id AND capabilities.weblog_id='
                            .$dbh->quote(GetWeblogID($cgi,$dbh));
            }
        }
    } elsif (defined($cgi->param('!user'))
             && defined($cgi->param('!pass1'))
             && defined($cgi->param('!pass2'))) {
        if ($cgi->param('!user') ne ''
            && $cgi->param('!pass1') ne ''
            && $cgi->param('!pass2') eq $cgi->param('!pass1')) {
            my ($email);
            $email = '';
            $email = $cgi->param('!email')
                if (defined($cgi->param('!email')));

            $sql = "select nextval('users_id_seq')";
            my ($user_id);
            ($user_id) = $dbh->selectrow_array($sql);

            $sql =
                'INSERT INTO users (id,name,password,email,emailconfirmcode,magiccookie) VALUES ('
                    .join(',',
                          $user_id,
                          $dbh->quote($cgi->param('!user')),
                          'encode(digest('
                          .join('||', 
                                map 
                                {
                                    $dbh->quote($_) }
                                $cgi->param('!user'),
                                $cgi->param('!pass1'),
                                $secretsalt)
                          .",'sha512'::text), 'hex')",
                          $dbh->quote($email),
                          $dbh->quote(Flutterby::Util::CreateRandomString(16)),
                          $dbh->quote(Flutterby::Util::CreateRandomString(16)))
                        .')';
            unless ($dbh->do($sql))
            {
                $error = $dbh->errstr;
                $error = 'Someone with that user name already exists in the database '
                    if ($dbh->errstr =~ /Cannot insert a duplicate key into unique index/);
            }
            if (!defined($error)) {
                my ($fcmsweblog_id);
                $fcmsweblog_id = GetWeblogID($cgi, $dbh);

                $sql = "INSERT INTO capabilities(user_id, weblog_id) VALUES ($user_id, $fcmsweblog_id)";
                $dbh->do($sql)
                    || print STDERR $dbh->errstr."\n$sql\n";
            }
	    
            $sql = 'SELECT * FROM users,capabilities WHERE lower(name)='
                .$dbh->quote(lc($cgi->param('!user')))
                    .' AND password='
                        .'encode(digest('
                            .join('||', 
                                  map 
                                  {
                                      $dbh->quote($_) }
                                  $cgi->param('!user'),
                                  $cgi->param('!pass1'),
                                  $secretsalt)
                                .",'sha512'::text), 'hex')"
                                    .' AND capabilities.user_id=users.id AND capabilities.weblog_id='
                                        .$dbh->quote(GetWeblogID($cgi,$dbh));
        }
    } elsif (defined($cgi->param('!user'))
             && defined($cgi->param('!pass'))) {
        $sql = 'SELECT * FROM users,capabilities WHERE lower(name)='
            .$dbh->quote(lc($cgi->param('!user')))
                .' AND password='
                    .'encode(digest('
                        .join('||', 
                              map 
                              {
                                  $dbh->quote($_) }
                              $cgi->param('!user'),
                              $cgi->param('!pass'),
                              $secretsalt)
                            .",'sha512'::text), 'hex')"
                                .' AND capabilities.user_id=users.id AND capabilities.weblog_id='
                                    .$dbh->quote(GetWeblogID($cgi,$dbh));
    } elsif (defined($cgi->cookie('id'))) {
        my ($id, $magic) = split(/\//,$cgi->cookie('id'));
        $sql = 'SELECT * FROM users,capabilities WHERE id='
            .$dbh->quote($id).' AND magiccookie='.$dbh->quote($magic)
                .' AND capabilities.user_id=users.id AND capabilities.weblog_id='
                    .$dbh->quote(GetWeblogID($cgi,$dbh));
    }
    return ($sql, $error);
}

sub BuildCookieFromSQL($$$)
{
    my ($cgi,$dbh, $sql) = @_; 
    my ($sth, $row, $cookie);

    $sth = $dbh->prepare($sql);
    $sth->execute();
    if ($row = $sth->fetchrow_hashref()) {
        undef $row->{password};
        if (defined($cgi->param('!user'))
            || defined($cgi->param('ticket'))) {
            if (defined($cgi->param('!remember'))
                || defined($cgi->param('ticket'))) {
                $cookie = $cgi->cookie(-name=>'id',
                                       -value=>$row->{'id'}.'/'
                                       .$row->{'magiccookie'},
                                       -path=>'/',
                                       -expires=>'+10y');
                if (defined($row->{'showadminbuttons'})
                    && $row->{'showadminbuttons'} eq 'Y') {
                    $cookie = 
                        [ 
                         $cookie,
                         $cgi->cookie(-name=>'sab',
                                      -value=>'Y'
                                      -path=>'/',
                                      -expires=>'+10y'),
                        ];
                }
            } else {
                $cookie = $cgi->cookie(-name=>'id',
                                       -value=>$row->{'id'}.'/'
                                       .$row->{'magiccookie'},
                                       -path=>'/');
                if (defined($row->{'showadminbuttons'})
                    && $row->{'showadminbuttons'} eq 'Y') {
                    $cookie = 
                        [ 
                         $cookie,
                         $cgi->cookie(-name=>'sab',
                                      -value=>'Y'
                                      -path=>'/',
                                      -expires=>'+10y'),
                        ];
                }
            }
        }
    }
    return ($cookie,$row);
}

sub GetCookieAndLogin($$)
{
    my ($cgi,$dbh) = @_;
    my ($cookie,$row,$sql,$error);

    ($sql,$error) = GetSqlIfLoginInfo($cgi,$dbh);
    if (defined($sql)) {
        ($cookie,$row) = BuildCookieFromSQL($cgi,$dbh,$sql);
    } else {
        $row = {};
    }
    return ($cookie,$row,$error);
}

sub CheckLogin($$)
{
    my ($cgi,$dbh) = @_;
    my ($headerprinted,$sql);

    die "CheckLogin needs a cgi\n" unless defined($cgi);
    die "CheckLogin needs a dbh\n" unless defined($dbh);

    my ($cookie,$row,$error) = GetCookieAndLogin($cgi,$dbh);
    if (defined($cookie)) {
        print $cgi->header(-cookie=>$cookie);
        print '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">';
    } else {
        print $cgi->header;
        print '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">';
    }
    return wantarray ? ($row,$error) : $row;
}


use Flutterby::HTML;
use Flutterby::Output::HTMLProcessed;
use Flutterby::Util;

sub PrintLoginScreen
{
    my ($configuration,$cgi, $dbh, $action,$loginerror) = @_;
    my ($tree) = 
        Flutterby::HTML::LoadHTMLFileAsTree($configuration->{-htmlpath}.'userloginscreen.html');
    my ($out, $variables);
    $variables = Flutterby::Users::GetWeblogInfo($cgi, $dbh);

    if (defined($loginerror)) {
        $variables->{'failurereason'} = "error: ".$loginerror;
    }

    my $sql = "DELETE FROM sessionvalues WHERE sessionvalues.ticket_id IN (SELECT id FROM sessiontickets WHERE entered < NOW() - '1 week'::INTERVAL)";
    $dbh->do($sql)
        || warn $dbh->errstr."\n$sql\n";
    $sql = "DELETE FROM sessiontickets WHERE entered < NOW() - '1 week'::INTERVAL";
    $dbh->do($sql)
        || warn $dbh->errstr."\n$sql\n";

    my $sessionticket;
    do
    {
        $sessionticket = Flutterby::Util::CreateRandomString(16);
    } while (!$dbh->do('INSERT INTO sessiontickets(session, target) VALUES('
                       .join(',', map { $dbh->quote($_) } ($sessionticket, $action)) .')'));
    my ($sessionid) = $dbh->selectrow_array('SELECT id FROM sessiontickets WHERE session='
                                            .$dbh->quote($sessionticket));
    my $k;
    foreach $k ($cgi->param) {
        $sql = 'INSERT INTO sessionvalues(ticket_id, name, value) VALUES('
            .join(',', map {$dbh->quote($_)} 
                  ($sessionid, $k, $cgi->param($k))).')';
        $dbh->do($sql);
    }
    $variables->{'lid_target'} = "http://$ENV{'HTTP_HOST'}$ENV{'REQUEST_URI'}";
    $variables->{'lid_ticket'} = $sessionticket;

    $out = new Flutterby::Output::HTMLProcessed
        (
         -classcolortags => $configuration->{-classcolortags},
         -colorschemecgi => $cgi,
         -variables => $variables,
         -cgi =>
         {
          'logincomplete' =>
          {
           -cgi => $cgi,
           -action => 
           Flutterby::Util::buildGETURL($action,$cgi),
          }
         }
        );
    $out->output($tree);
}
1;

__END__

=head1 NAME

Flutterby::Users - Manage users in the Flutterby CMS schema

=head1 SYNOPSIS
    
 use Flutterby::Users;

 $fcmsweblog_id = Flutterby::Users::GetWeblogID($cgi->url(), $dbh);
 
=head1 DESCRIPTION

The C<Flutterby::Users> class is a wrapper for a bunch of functions
that do oft-repeated user tasks on the Flutterby schema.

=head2 GetWeblogID

C<Flutterby::Users::GetWeblogID> is a stub function which needs
development. It's based on Mark Hershberger's modification of the
schema to allow multiple weblogs, and it's this that will somehow
extract from the URL information about which weblog is being
accessed. For now it just returns "1".

