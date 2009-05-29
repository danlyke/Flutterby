#!/usr/bin/perl -w
use strict;
package Flutterby::Output::HTMLProcessed;
use HTML::Entities;
use Flutterby::Output::HTML;
use Flutterby::Tree::Find;


sub new()
  {
    my ($type,%args) = @_;
    my $class = ref($type) || $type;
    my ($self) = 
      {
       -outputfunc => \&sendToOutput,
       -overridetags =>
       {
	'flutterbyquery' => \&process_tag_query,
	'flutterbyrow' => \&process_tag_row,
	'form' => \&process_tag_form,
	'input' => \&process_tag_input,
	'select' => \&process_tag_select,
	'textarea' => \&process_tag_textarea,
	'option' => \&process_tag_option,
       },
       -classcolortags => {},
       -sqlqueries => {},
      };
    foreach (keys %args)
    {
	$self->{$_} = $args{$_}
	if (defined({
	    -variables => 1,
	    -cgi => 1,
	    -dbh => 1,
	    -textconverters => 1,
	    -outputfunc => 1,
	    -colorscheme => 1,
	    -colorschemecgi => 1,
	    -classcolortags => 1,
	    -sqlqueries => 1,
	}->{$_}));
    }
    $self->{-outputhtml} = new Flutterby::Output::HTML()
	if ($self->{-textconverters});

    return bless($self, $class);
  }

sub setOutput()
  {
    my ($self, $dest) = @_;
    $self->{-outputdest} = $dest;
  }

sub sendToOutput()
  {
    my ($self, $t) = @_;
    my ($r) = $self->{-outputdest};
    
    if (!defined($r))
      {
	print $t;
      }
    else
      {
	if (ref($r) eq 'GLOB')
	  {
	    print {*$r} $t;
	  }
	elsif (ref($r) eq 'SCALAR')
	  {
	    $$r .= $t;
	  }
	else
	  {
	    print $t;
	  }
      }
  }

sub outputChildren
  {
    my ($self, $childinfo, $start) = @_;
    $start = 1 unless defined($start);
    my ($varlist);
    $varlist = $self->{-varlist};
    my ($outputfunc) = $self->{-outputfunc};

    my ($i);
    for ($i = $start; $i <= $#$childinfo; $i += 2)
      {
	if ($childinfo->[$i] eq '0')
	  {	    &$outputfunc($self,
				 Flutterby::Util::subst($childinfo->[$i + 1],
							@$varlist));
	  }
	elsif ($childinfo->[$i] eq '!')
	{
	    &$outputfunc($self, '<!-- ');
	    if (ref($childinfo->[$i + 1]) eq 'ARRAY')
	    {
		$self->outputChildren($childinfo->[$i + 1]);
	    }
	    else
	    {
		&$outputfunc($self, $childinfo->[$i + 1]);
	    }
	    &$outputfunc($self, ' -->');
	}
	else
	  {
	    $self->outputLeaf($childinfo->[$i],$childinfo->[$i + 1]);
	  }
      }
  }


sub load_next_row($$$$)
{
    my ($sth, $textconverters,$formats,$outputhtml) = @_;
    my ($row);
    $row = $sth->fetchrow_hashref;
    if ($row)
    {
	if (defined($textconverters))
	{
	    foreach (keys %$formats)
	    {
		if (defined($row->{$_})
		    and defined($row->{$formats->{$_}}))
		{
		    if (defined($textconverters->{$row->{$formats->{$_}}}))
		    {
			my ($t) = '';
			my ($tree,$node,@tree);
			$outputhtml->setOutput(\$t);
			$tree = $textconverters->{$row->{$formats->{$_}}}
			->parse($row->{$_});
			if ($node = Flutterby::Tree::Find::nodeChildInfo($tree,'body'))
			{
			    @tree = @$node;
			    shift @tree;
			    $outputhtml->output(\@tree);
			}
			else
			{
			    $outputhtml->output($tree);
			}
			$row->{$_} = $t;
		    }
		    elsif (defined($row->{$formats->{$_}})
			   and defined($textconverters->{$_}))
		    {
			my ($t) = '';
			my ($tree,$node,@tree);
			$outputhtml->setOutput(\$t);
			$tree = $textconverters->{$_}
			->parse($row->{$_});
			if ($node = Flutterby::Tree::Find::nodeChildInfo($tree,'body'))
			{
			    @tree = @$node;
			    shift @tree;
			    $outputhtml->output(\@tree);
			}
			else
			{
			    $outputhtml->output($tree);
			}
			$row->{$_} = $t;
		    }
		}
	    }
	}
    }
    return $row;
  }

sub process_tag_query()
  {
    my ($self, $tag, $childinfo) = @_;
    my ($attributes) = $childinfo->[0];
    my ($textconverters) = $self->{-textconverters};
    my ($varlist);
    $varlist = $self->{-varlist};
    if (defined($attributes->{'sql'}))
      {
	my ($sql,$sth,$row);
	$sql = $attributes->{'sql'};
	$sql = $self->{-sqlqueries}->{$attributes->{'sql'}}
	  if (defined($self->{-sqlqueries}->{$attributes->{'sql'}}));
	$sql = Flutterby::Util::subst($sql, @$varlist);
	$sth = $self->{-dbh}->prepare($sql) or die $self->{-dbh}->errstr."\n$sql\n";
	my (%formats);
	%formats = split(/=>|,/, $attributes->{'format'})
	  if (defined($attributes->{'format'}));
	$sth->execute or die $sth->errstr."\n$sql";
	if ($row = load_next_row($sth,$textconverters,\%formats,$self->{-outputhtml}))
	  {
	    my ($formatstack) = $self->{-sql_format_stack};
	    my ($sthstack) = $self->{-sql_sth_stack};
	    push @$formatstack, \%formats;
	    push @$sthstack, $sth;
	    push @$varlist, $row;
	    $self->outputChildren($childinfo);
	    pop @$varlist;
	    pop @$sthstack;
	    pop @$formatstack;
	  }
      }
    elsif (defined($attributes->{'variable'}))
      {
	my ($v,$i);
	$i = $#$varlist;
	do
	  {
	    $v = $varlist->[$i]->{$attributes->{'variable'}};
	    $i--;
	  }
	while ($i > -1 && !defined($v));

	if (defined($v))
	  {
	    if ((ref($v) eq 'ARRAY')
		&& ($#$v >= 0))
	      {
		my ($sthstack) = $self->{-sql_sth_stack};
		push (@$sthstack, $v);
		push @$varlist, $v->[0];
		$self->outputChildren($childinfo);
		pop @$varlist;
		pop @$sthstack;
	      }
	  }
      }
  }
sub process_tag_row()
  {
    my ($self, $tag, $childinfo) = @_;
    my ($attributes) = $childinfo->[0];
    my ($sthstack) = $self->{-sql_sth_stack};
    my ($sth,$row,$varlist);
    my ($formatstack) = $self->{-sql_format_stack};
    my ($formats) = $formatstack->[$#$formatstack];
    my ($textconverters) = $self->{-textconverters};
    my ($output) = $self->{-outputhtml};
    my ($queryrow);
    $sth = $sthstack->[$#$sthstack];
    $varlist = $self->{-varlist};
    if (ref($sth) eq 'ARRAY')
      {
	for ($queryrow = 0; $queryrow <= $#$sth; $queryrow++)
	  {
	    $varlist->[$#$varlist] = $sth->[$queryrow];
	    $varlist->[$#$varlist]->{'_result_row'} = $queryrow;
	    $self->outputChildren($childinfo);
	  }
      }
    else
      {
	$queryrow = 0;
	$row = $varlist->[$#$varlist];
	do
	  {
	    $row->{'_result_row'} = $queryrow;
	    $queryrow++;
	    $varlist->[$#$varlist] = $row;
	    $self->outputChildren($childinfo);
	  } while ($row = load_next_row($sth,$textconverters,$formats,$output));
      }
  }

sub postprocess_tag_form()
  {
    my ($self, $tag, $attributes, $childinfo) = @_;
    my ($outputfunc) = $self->{-outputfunc};

    my ($cgi) = $self->{-currentcgi};
    my ($usedcgivariables) = $self->{-usedcgivariables};

    if (defined($cgi))
      {
	foreach ($cgi->param)
	  {
	    unless ($_ =~ /^\!/ or defined($usedcgivariables->{$_}))
	    {
		my ($t);
		$t = $cgi->param($_);
		$cgi->param($_ => $t) if ($t =~ s/\r\n/\n/g);
		$cgi->param($_ => $t) if ($t =~ s/\&\#13\;\&\#10\;/\&\#10\;/g);
		&$outputfunc($self,$cgi->hidden($_));
	    }
	  }
      }
  }

sub process_tag_form()
  {
    my ($self, $tag, $childinfo) = @_;
    my ($attributes) = $childinfo->[0];

    if (defined($self->{-cgi}))
      {
	if (ref($self->{-cgi}) eq 'ARRAY')
	  {
	    $self->{-currentcgi} = $self->{-cgi}->[$self->{-currentcginum}];
	    $self->{-currentcginum}++;
	  }
	elsif (ref($self->{-cgi}) eq 'HASH')
	  {
	    if (defined($attributes->{'action'}) 
		&& ref($self->{-cgi}->{$attributes->{'action'}}) eq 'HASH')
	      {
		$self->{-currentcgi} = $self->{-cgi}->{$attributes->{'action'}}->{-cgi};
		my (%attr);
		%attr = %$attributes;
		$attributes->{'action'} = 
		  $self->{-cgi}->{$attributes->{'action'}}->{-action}
		    if (defined($self->{-cgi}->{$attributes->{'action'}}->{-action}));
	      }
	    else
	      {
		$self->{-currentcgi} = $self->{-cgi}->{$attributes->{'action'}};
	      }
	  }
	else
	  {
	    $self->{-currentcgi} = $self->{-cgi};
	  }
	$self->{-usedcgivariables} = {};
      }

    $self->outputTag($tag,$attributes,$childinfo,\&postprocess_tag_form);
    delete ($self->{-currentcgi});
    delete ($self->{-usedcgivariables});
  }

sub process_tag_input()
  {
    my ($self, $tag, $childinfo) = @_;
    my ($attributes) = $childinfo->[0];
    my ($outputfunc) = $self->{-outputfunc};
    if ($self->{-currentcgi})
      {
	my ($cgi) = $self->{-currentcgi};
	my ($varlist);
	$varlist = $self->{-varlist};

	my (%attr);
        foreach ('name',
		 'value',
		 'checked',
		 'size',
		 'maxlength',
		 'src',
		 'align',

		 'onchange',
		 'onfocus',
		 'onblur',
		 'onmouseover',
		 'onmouseout',
		 'onselect',
		)
	  {
	    $attr{'-'.$_} = Flutterby::Util::subst($attributes->{$_},@$varlist)
	      if (exists($attributes->{$_}));
	  }
        if (lc($attributes->{'type'}) eq 'password')
	  {
	    &$outputfunc($self,$cgi->password_field(%attr));
	  }
	elsif (lc($attributes->{'type'}) eq 'checkbox')
	{
	    if (defined($attr{'checked'})
		&& ($attr{'checked'} eq 'false'
		    || $attr{'checked'} eq 'f'))
	    {
		undef $attr{'checked'};
	    }
	    &$outputfunc($self,$cgi->checkbox(%attr,-label=>''));
	}
	elsif (lc($attributes->{'type'}) eq 'radio')
	{
	    if (defined($attributes->{'name'})
	       && defined($cgi->param($attributes->{'name'})))
	    {
		%attr = ();
		foreach (keys %$attributes)
		{
		    $attr{$_} = Flutterby::Util::subst($attributes->{$_},@$varlist);
		}
		$attr{'value'} = $cgi->param($attr{'name'});
		$self->outputTagNoSubst($tag,\%attr,$childinfo);
	    }
	    else
	    {
		$self->outputTag($tag,$attributes,$childinfo);
	    }
	}
	elsif (lc($attributes->{'type'}) eq 'submit')
	  {
	    &$outputfunc($self,$cgi->submit(%attr));
	  }
	elsif (lc($attributes->{'type'}) eq 'reset')
	  {
	    &$outputfunc($self,$cgi->reset(%attr));
	  }
	elsif (lc($attributes->{'type'}) eq 'hidden')
	  {
	    &$outputfunc($self,$cgi->hidden(%attr));
	  }
	elsif (lc($attributes->{'type'}) eq 'image')
	  {
	    &$outputfunc($self,$cgi->image_button(%attr));
	  }
	elsif (lc($attributes->{'type'}) eq 'file')
	  {
	    $self->outputTag($tag,$attributes,$childinfo);
	  }
	elsif (lc($attributes->{'type'}) eq 'text')
	  {
	    &$outputfunc($self,$cgi->textfield(%attr));
	  }
	else
	  {
	    &$outputfunc($self,$cgi->textfield(%attr));
	  }
	$self->{-usedcgivariables}->{$attr{-name}} = 1
	    if (defined $attr{-name})
      }
    else
      {
	$self->outputTag($tag,$attributes,$childinfo);
      }
  }
sub process_tag_select()
  {
    my ($self, $tag, $childinfo) = @_;
    my ($attributes) = $childinfo->[0];
    my ($cgi) = $self->{-currentcgi};

    if ($cgi)
      {
	my (%attr);
	my ($varlist);
	$varlist = $self->{-varlist};

        foreach (keys %$attributes)
	  {
	    $attr{$_} = Flutterby::Util::subst($attributes->{$_},@$varlist);
	  }
	$self->{-currentselectvalue} = $cgi->param($attr{'name'})
	  if (defined($attr{'name'})
	      && defined($cgi->param($attr{'name'})));
	$self->{-usedcgivariables}->{$attr{'name'}} = 1;
	$self->outputTagNoSubst($tag,\%attr,$childinfo);
	delete($self->{-currentselectvalue});
      }
    else
      {
	$self->outputTag($tag,$attributes,$childinfo);
      }
  }
sub process_tag_option()
  {
    my ($self, $tag, $childinfo) = @_;
    my ($attributes) = $childinfo->[0];

    if (exists($self->{-currentselectvalue}))
      {
	my (%attr);
	my ($varlist);
	$varlist = $self->{-varlist};

        foreach (keys %$attributes)
	  {
	    $attr{$_} = Flutterby::Util::subst($attributes->{$_},@$varlist);
	  }
	if ($self->{-currentselectvalue} eq $attr{'value'})
	  {
	    $attr{'selected'} = undef
	      unless exists($attr{'selected'});
	  }
	else
	  {
	    delete($attr{'selected'})
	      if exists($attr{'selected'});
	  }
	$self->outputTag($tag,\%attr,$childinfo);
      }
    else
      {
	$self->outputTag($tag,$attributes,$childinfo);
      }
  }
sub process_tag_textarea()
  {
    my ($self, $tag, $childinfo) = @_;
    my ($attributes) = $childinfo->[0];
    my ($outputfunc) = $self->{-outputfunc};

    if ($self->{-currentcgi}
       && defined($attributes->{'name'})
       && defined($self->{-currentcgi}->param($attributes->{'name'})))
      {
	my $t = $self->{-currentcgi}->param($attributes->{'name'});
        while ($t =~ /^(.*?)([\x80-\x{ffff}])(.*)$/)
        {
            $t = sprintf("%s&#%d;%s",$1,ord($2),$3);
        }
        $t =~ s/\&/\&amp\;/g;
	$self->outputTag($tag,$attributes,
			[$attributes,
			 '0',
			 $t
			]);
	
	$self->{-usedcgivariables}->{$attributes->{'name'}} = 1;
      }
    else
      {
	if ($#$childinfo > 1)
	  {
	    $self->outputTag($tag,$attributes,$childinfo);
	  }
	else
	  {
	    $self->outputTag($tag,$attributes,
			[$attributes,
			 '0',
			 ''
			]);
	  }
      }
  }


sub outputTag
  {
    my ($self, $tag, $attributes, $childinfo,$post) = @_;
    my ($varlist);
    $varlist = $self->{-varlist};
    my ($outputfunc) = $self->{-outputfunc};

    &$outputfunc($self,"<$tag");
    foreach (keys %$attributes)
    {
	if (/^\w+/)
	{
	    if (defined($attributes->{$_}))
	    {
		&$outputfunc($self," $_");
		&$outputfunc($self,Flutterby::Util::subst('="'.
							HTML::Entities::encode($attributes->{$_})
							  .'"',@$varlist));
	    }
	    else
	    {
		&$outputfunc($self," $_=\"$_\"");
	    }
	}
    }
    if ($#$childinfo > 0)
      {
	&$outputfunc($self,'>');
	$self->outputChildren($childinfo);
	&$post($self,$tag,$attributes,$childinfo)
	  if (defined($post));
	&$outputfunc($self,"</$tag>");
      }
    else
      {
	&$outputfunc($self,' />');
	&$outputfunc($self,\&$post($self,$tag,$attributes,$childinfo))
	  if (defined($post));
      }
  }

sub outputTagNoSubst
  {
    my ($self, $tag, $attributes, $childinfo,$post) = @_;
    my ($varlist);
    $varlist = $self->{-varlist};
    my ($outputfunc) = $self->{-outputfunc};

    &$outputfunc($self,"<$tag");
    foreach (keys %$attributes)
    {
	if (defined($attributes->{$_}))
	{
	    &$outputfunc($self," $_");
	    &$outputfunc($self,Flutterby::Util::subst('="'.
						    HTML::Entities::encode($attributes->{$_})
						      .'"',@$varlist));
	}
	else
	{
	    &$outputfunc($self," $_=\"$_\"");
	}
    }
    if ($#$childinfo > 0)
      {
	&$outputfunc($self,'>');
	$self->outputChildren($childinfo);
	&$outputfunc($self,\&$post($self,$tag,$attributes,$childinfo))
	  if (defined($post));
	&$outputfunc($self,"</$tag>");
      }
    else
      {
	&$outputfunc($self,' />');
	&$outputfunc($self,\&$post($self,$tag,$attributes,$childinfo))
	  if (defined($post));
      }
  }


sub outputLeaf
  {
    my ($self, $tag, $childinfo) = @_;

    if (defined($self->{-overridetags}->{$tag}))
      {
	my ($func) = $self->{-overridetags}->{$tag};
	$self->$func($tag, $childinfo);
      }
    else
      {
	$self->outputTag($tag,$childinfo->[0], $childinfo);
      }
  }

sub DumpRefTree
  {
    my ($r, $depth) = @_;
    $depth = 0 unless ($depth);
    
    print ' 'x$depth."$r\n";
    if (ref($r))
      {
	if (ref($r) eq 'ARRAY')
	  {
	    foreach (@$r)
	      {
		DumpRefTree($_,$depth + 1);
	      }
	  }
	if (ref($r) eq 'HASH')
	  {
	    $depth++;
	    
	    foreach (keys %$r)
	      {
		print ' 'x$depth."$_\n";
		DumpRefTree($r->{$_},$depth + 1);
	      }
	  }

      }
  }

sub output
  {
    my ($self, $childinfo) = @_;
    my (@v);
    push @v, $self->{-variables} if (defined($self->{-variables}));
    $self->{-varlist} = \@v;
    $self->{-sql_sth_stack} = [];
    $self->{-sql_format_stack} = [];
    $self->{-currentcginum} = 0;
    $self->outputChildren($childinfo,0);
#    $self->outputLeaf($tree->[0], $tree->[1]);
  }

1;
