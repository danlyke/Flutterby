#!/usr/bin/perl -w
use strict;
package Flutterby::DBUtil;
use utf8::all;
use Try::Tiny;

sub escapeToEntities($$@)
{
    my ($cgi, $t, $log) = @_;
    if (defined($t)) {
        if ($cgi->charset() eq 'utf-8') {
            use utf8;
            $$log .= "escaping UTF-8\n"
                if (defined($log));
            while ($t =~ /^(.*)([\x80-\x{fffffff}])(.*)$/s) {
                $$log .= sprintf(" added %x\n", ord($2))
                    if (defined($log));
                
                $t = sprintf("%s&#%d;%s",$1,ord($2),$3);
            }
        }
        else
        {
            $$log .= "escaping normal:\n\n$t\n"
                if (defined($log));
            while ($t =~ /^(.*)([\x80-\x{fffffff}])(.*)$/s) {
                $$log .= sprintf(" added %x\n", ord($2))
                    if (defined($log));
                
                $t = sprintf("%s&#%d;%s",$1,ord($2),$3);
            }
        }
    }
    return $t;
}


sub escapeFieldsToEntities($@)
{
    my ($cgi) = shift @_;

    foreach (@_)
    {
	$cgi->param($_ => escapeToEntities($cgi,$cgi->param($_)));
    }
    return "From original\n";
}

sub updateMultipleRecords
{
    my ($dbh, $cgi, $table, $primary, $fields,$additional,@escapefields) = @_;
    my (%records,$record);
    my ($sql);

    foreach ($cgi->param)
    {
	if ($_ =~ /^$primary\!(.*)$/)
	{
	    $records{$1} = 1 ;
	}
    }

    foreach $record (keys %records)
      {
	$sql = "UPDATE $table SET ";

	foreach (@escapefields)
	{
#	    escapeFieldsToEntities($cgi, "$_\!$record");
	}
	

	if (ref($fields) eq 'ARRAY')
	  {
	    $sql .= join(',',
			 map 
			 {
			   "$_=".$dbh->quote(scalar($cgi->param('_'.$_.'!'.$record)));
			 } grep {defined($cgi->param('_'.$_.'!'.$record))} @$fields);
	    $sql .= " WHERE $primary=".$dbh->quote($cgi->param('_'.$primary.'!'.$record));
	  }
	elsif (ref($fields) eq 'HASH')
	  {
	    $sql .= join(',',
			 map 
			 {
			   "$fields->{$_}=".$dbh->quote(scalar($cgi->param($_.'!'.$record)));
			 } grep {defined($cgi->param($_.'!'.$record))} keys %$fields);
	    $sql .= " WHERE $fields->{$primary}="
	      .$dbh->quote(scalar($cgi->param($primary.'!'.$record)));
	  }
	else
	  {
	    die "Unknown field structure type $fields in DBUtil::updateRecord\n";
	  }
	$sql .= " AND $additional" 
	  if (defined($additional));
	$dbh->do($sql);
      }
  }
  
sub updateRecord
  {
    my ($dbh, $cgi, $table, $primary, $fields,$additional) = @_;
    my ($sql,$where);
    if (ref($fields) eq 'ARRAY')
      {
	$sql = join(',',
		     map 
		     {
		       "$_=".$dbh->quote(scalar($cgi->param("_$_")));
		     } grep { defined($cgi->param("_$_")) } @$fields);
        $where = " WHERE $primary=".$dbh->quote(scalar($cgi->param("_$primary")));
      }
    elsif (ref($fields) eq 'HASH')
      {
	$sql = join(',',
 		     map 
		     {
		       "$fields->{$_}=".$dbh->quote(scalar($cgi->param("_$_")));
		     } grep { defined($cgi->param("_$_")) } keys %$fields);
        $where = " WHERE $fields->{$primary}=".$dbh->quote(scalar($cgi->param("_$primary")));
      }
    else
      {
	die "Unknown field structure type $fields in DBUtil::updateRecord\n";
      }
    if ($sql)
      {
	$sql = "UPDATE $table SET ".$sql.$where;
	$sql .= " AND $additional" 
	  if (defined($additional));
	return $dbh->do($sql);
      }
  }
  
1;
