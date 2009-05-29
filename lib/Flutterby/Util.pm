package Flutterby::Util;

sub UnixTimeAsISO8601 {
  my ($time) = @_;
  if ($time)
    {
      my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($time))[0..5];
      $mon++;
      $year += 1900;
      return sprintf('%04.4d-%02.2d-%02.2d %02.2d:%02.2d:%02.2d',
		     $year,$mon,$mday,$hour,$min,$sec);
    }
  return undef;
}

sub escape {
  my $toencode = shift;
  return '' unless defined($toencode);
  $toencode=~s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
  return $toencode;
}

sub subst($@)
{
    my ($s) = shift;
    return '' unless defined($s);
    my $ret;
    my (%escapedChars) =
	(
	 '$' => '$'
	 );
    $ret = '';
    while ($s =~ s/^(|.*?[^\$]|.*?\$\$)\$([a-z\_]+\w*|\([a-z\_]+\w*\))//si)
      {
	 my ($b,$v,$a) = ($1,$2);
	 my ($orig) = $v;
	 $v = $1 if ($v =~ /^\((.*)\)$/);
	 $ret .= $b;
	 my ($i, $replaced);

	 for ($i = $#_; $i >= 0 and !$replaced; $i--)
	   {
	     if (ref($_[$i]) eq 'HASH')
	       {
		 if (defined($_[$i]->{$v}))
		   {
		     $ret .= $_[$i]->{$v};
		     $replaced = 1;
		   }
	       }
	     elsif (ref($_[$i]) ne '')
	       {
		 if (defined($_[$i]->param($v)))
		   {
		     $ret .= $_[$i]->param($v);
		     $replaced = 1;
		   }	
	       }
	   }
	 #$ret .= "\$UNMATCHED-->$orig<--" unless ($replaced);
    }
    $ret .= $s;
    $ret =~ s/\$\$/\$/g;
    return $ret;
}


sub random_string($)
{
    my ($len) = @_;
    my ($ret, $validChars);
    $validChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890';
    $ret = '';
    while ($len--)
    {
	$ret .= substr($validChars, rand(length($validChars)),1);
    }
    return $ret;
}

sub build_insert_statement($$@)
  {
    my ($table,$hashref,@fieldslist) = @_;
    my ($fields,$dbh,$sql);
    $dbh = $self->get_dbh;
    if ($#fieldslist >= 0)
      {
	if ('ARRAY' == ref($fieldslist[0]))
	  {
	    $fields = $fieldslist[0];
	  }
	else
	  {
	    $fields = \@fieldslist;
	  }
      }
    else
      {
	@fieldslist = keys %$hashref;
	$fields = \@fieldslist;
      }

    return "INSERT INTO $table ("
      .join(',',@$fields)
	.') VALUES ('
	  .join(',', 
		map
		{
		  $dbh->quote($hashref->{$_})
		}
		@$fields).')';
  }

sub build_update_statement($$@)
  {
    my ($table,$hashref,@fieldslist) = @_;
    my ($fields,$dbh,$sql);
    $dbh = $self->get_dbh;
    if ($#fieldslist >= 0)
      {
	if ('ARRAY' == ref($fieldslist[0]))
	  {
	    $fields = $fieldslist[0];
	  }
	else
	  {
	    $fields = \@fieldslist;
	  }
      }
    else
      {
	@fieldslist = keys %$hashref;
	$fields = \@fieldslist;
      }

    return "UPDATE $table SET "
	  .join(',', 
		map
		{
		  "$_=".$dbh->quote($hashref->{$_})
		}
		@$fields);
  }

sub buildGETURL($$)
  {
    my ($base, $cgi) = @_;
    return "$base?".join('&',
			 map
			 {
			   "$_=".escape($cgi->param($_))
			 } (grep {/^[^\_\!]/} ($cgi->param)));
  }


sub CreateRandomString($)
{
    my ($len) = @_;
    my ($ret, $validChars);
    $validChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890';
    $ret = '';
    while ($len--)
    {
	$ret .= substr($validChars, rand(length($validChars)),1);
    }
    return $ret;
}

sub EnsureDirectory($)
{
    my ($dir);
    $dir = $_[0];

    foreach $dir (@_)
    {
	my (@paths) = split /\//, $dir;
	my ($path, $p);
	shift @paths;
	pop @paths;
	
	foreach $p (@paths)
	{
	    if (defined($p))
	    {
		$path .= "/$p";
		mkdir $path unless -d $path;
	    }
	}
    }
}

sub determineUrl($) {
    my $q = shift;

    my $uri = $q->protocol();
    $uri .= "://";
    $uri .= $q->server_name();
    $uri .= ":" . $q->server_port() if( $q->server_port() != 80 );
    $uri .= $ENV{'REQUEST_URI'};

    $uri =~ s/(.*?)\?(.*)/$1/; # strip off arguments after ?
    $uri =~ s#(.*?)$ENV{'PATH_INFO'}$#$1# if( $ENV{'PATH_INFO'} ); # strip off path-info
    return $uri;
}

1;
