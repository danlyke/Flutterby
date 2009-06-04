use FbyDB;

use FbyObjects;






package FbyParserInfo;
use Moose;
has outputdir => (is => 'rw', isa => 'Str');
has stagingdir => (is => 'rw', isa => 'Str');
has sourcedir => (is => 'rw', isa => 'Str');
has db => (is => 'rw');
has suffix => (is => 'rw', isa => 'Str');
has wikiobj => (is => 'rw');
has googlemapnum => (is => 'rw', isa => 'Int');


sub WebPathFromFilename($)
{
	my ($self, $path) = @_;
	my $outputdir = $self->outputdir;
	$path =~ s/^$outputdir//;
	return $path;
}

sub ImageTagFromInstance($@)
{
	my ($self, $inst, $alt) = @_;
	my ($w,$h) = $inst->dimensions;
	return '<img src="'.$self->WebPathFromFilename($inst->filename)
		."\" width=\"$w\" height = \"$h\" alt=\""
			.(defined($alt) ? $alt : $inst->name)
				.'">';
}




no Moose;
__PACKAGE__->meta->make_immutable;



package Fby;

use Carp;
$Carp::Verbose = 1;

my $outputdir; # = '/var/www';


use File::Find;

my %images;
my $fbyimagesdb;

sub FoundImage()
{
	if ($File::Find::name =~ /^(.*\/)(.*\.(jpg|png))$/i
		&& -f $File::Find::name)
	{
		
		my $inst = $fbyimagesdb->load_or_create('ImageInstance', filename => $File::Find::name);

		my $imagename = $inst->name;

		my ($x, $y) = $inst->dimensions;
		my $image = $fbyimagesdb->load_or_create('Image', name=> $imagename);
		$images{$imagename} = $image;
		$inst->image_id($image->id);
		$fbyimagesdb->write($inst);
	}
}

#sub WebPathFromFilename($)
#{
#	my ($path) = @_;
#	$path =~ s/^$outputdir//;
#	return $path;
#}
#
#
#sub ImageTagFromInstance($@)
#{
#	my ($inst, $alt) = @_;
#
#	my ($w,$h) = $inst->dimensions;
#	return '<img src="'.WebPathFromFilename($inst->filename)
#		."\" width=\"$w\" height = \"$h\" alt=\""
#			.(defined($alt) ? $alt : $inst->name)
#				.'">';
#}

sub FindAllFiles($$)
{
	my ($fpi, $sourcedir) = @_;
	my $db = $fpi->db;
	my $outputdir = $fpi->outputdir;

	$fbyimagesdb = $db;

	find({ wanted=>\&FoundImage,
		   follow => 1 },
		 "$outputdir/wiki");

	while (my ($imgname, $img) = each %images)
	{
		if (!-f "$sourcedir/Image:$imgname.wiki")
		{
			my @desc;
			
			my $full = $img->fullsize($db);
			my $thumb = $img->thumb($db);
			$thumb = undef if ($thumb->filename eq $full->filename);

			if (defined($full))
			{
				print "$full\n";
				my $cmd = 'jhead "'.$full->filename.'"';
				@desc = `$cmd`;
				shift @desc;
			}
			
			open O, ">$sourcedir/Image:$imgname.wiki";
			print O "== Full Size ==\n\n"
				.$fpi->ImageTagFromInstance($full)
				."\n\n"
				if (defined($full));
			print O "== Thumbnail ==\n\n"
				.$fpi->ImageTagFromInstance($thumb)
				."\n\n"
				if (defined($thumb));

			print O join('<br>', grep {!/^File date:/} @desc)
				if (@desc);

			print O "\n\nAll sizes: "
				.join('|',
					  map {
						  '<a href="'.$fpi->WebPathFromFilename($_->filename)
							  .'">'.$_->width.'x'.$_->height.'</a>'
					  } $img->instances($db))
				."\n";
			close O;
			
		}
	}


}


use Flutterby::Parse::Text;
use Data::Dumper;
use Flutterby::Tree::Find;
use Flutterby::Output::HTML;
use Flutterby::Output::Text;
use XML::RSS;
use Email::Date::Format qw(email_date);
use Cwd;

my $stagingdir = getcwd.'/html_staging';
my $sourcedir = 'mvs';



my $dbfilename = 'var/fby.db';
my $existingdb = -f $dbfilename;
my $db = FbyDB::Connection->new(
	#debug=>1
	);
$db->connect(
	"dbi:SQLite:dbname=$dbfilename",
#	'bdb:dir=var/fby_bdb',
#	create => 1,
	);

unless (defined($existingdb))
{
	foreach ('ImageInstance', 'Image', 'WikiEntry', 'WikiEntryReference')
	{
		my $sql = $db->create_statement($_);
		print "Doing $sql\n";
		$db->do($sql);
	}
	$db->do('CREATE INDEX ImageInstance_image_id ON ImageInstance(image_id)');
	$db->do('CREATE INDEX ImageInstance_filename ON ImageInstance(filename)');
	$db->do('create unique index wikientryname on wikientry(name)');
	$db->do('create index to_id on wikientryreference(to_id)');
}



sub ReadConfig
{
    my %config;
	
    open(I, "/home/danlyke/.fby/config")
	|| die "Unable to open $ENV{'HOME'}/.fby/config\n";
    while (<I>)
    {
	$config{$1} = $2 if (/^(\w+)\s*\:\s*(.*$)/);
	$outputdir = $1 if (/^OutputDir:\s*(.*)$/);
	chdir $1 if (/^InstallDir\:\s*(.*)$/);
    }
    close I;
	return \%config;
}




sub ConvertTextToWiki($@)
{
	my ($t,$isfile) = @_;
	
	$t =~ s/\:\s+/\:/xsg;
	$t =~ s/\s+/_/xsg;
	$t = Flutterby::Util::escape($t) unless $isfile;
	return $t;
}

sub OutputNameToLinkName($)
{
	my ($n) = @_;
	$n =~ s/\.html$//;
	return $n;
}


sub TagWiki()
{
	my ($fpi, $ref, $text) = @_;
	my $r;
	my $db = $fpi->db;

	$ref =~ s/\s+/ /xsg;
	$ref =~ s/\:\s+/\:/xsg;
	$text = $ref unless defined($text);

	die "$ref $text $fpi\n" unless defined($ref);
	my $wikilink = ConvertTextToWiki($ref);

#	if ($ref =~ /^Category:/)
#	{
#		$fpi->categories->{$ref} = 1;
#	}

	if ($ref =~ /^Image:(.*)$/i) {
		my $imgname = $1;
		my $img = $fpi->db->load_one('Image', name => $imgname);
		my $imginst;
		my $desc = '';
		my $align = '';
		my $divclass = 'image';
		my $width = '';

		$imginst = $img->fullsize($db) if (defined($img));
		my @notes = split /\|/, $text;
		
		foreach (@notes) {
			if ($_ eq 'thumb' && defined($img)) {
				$imginst = $img->thumb($db);
			} elsif ($_ eq 'left' || $_ eq 'right') {
				$align = $_;
			} elsif ($_ eq 'frame')
			{
				$divclass = 'imageframed';
			} else {
				$desc .= $_;
			}
		}

		my ($w,$h);
		if (defined($imginst))
		{
			($w,$h) = $imginst->dimensions;
			$width = "style=\"width: $w"."px;\"";
		}
	
		unless (defined($img))
		{
		    $divclass = 'imagemissing';
		    print STDERR "Missing $imgname from database\n";
		}

		$r = "<div class=\"$divclass$align\" $width>";

		my $wikientry = $fpi->db->load_one('WikiEntry', name => $ref);

		$r .= "<a href=\"./$ref\">"
			if (defined($wikientry));
		$r .= $fpi->ImageTagFromInstance($imginst)
			if defined($imginst);
		$r .= "</a>"
			if (defined($wikientry));

		$r .= "<div class=\"imagecaption\"><p class=\"imagecaption\">$desc</p></div>" if $desc ne '';
		$r .= "</div>";
	}
	elsif (my $wikientry = $fpi->db->load_one('WikiEntry', name => $ref))
	{
		$r = '<a href="./'.OutputNameToLinkName($wikientry->outputname).'">'
			.HTML::Entities::encode($text)
				.'</a>';
		print $fpi->wikiobj->name." references ".$wikientry->name."\n"
			if ($fpi->wikiobj->name eq 'MFS');
		my $wer = $db->load_or_create('WikiEntryReference',
									  from_id => $fpi->wikiobj->id,
									  to_id => $wikientry->id);
		print "  ".$wer->from_id." to ".$wer->to_id." with object ".$wer->id."\n"
			if ($fpi->wikiobj->name eq 'MFS');
	} else {
		$r = '<i>'
			.HTML::Entities::encode($text)
				.'</i>';
		$fpi->wikiobj->_missingReferences->{$ref} = 1;
	}

	#	$text =~
	#									.HTML::Entities::encode($text).
	#									'"><img border="0" src="/adbanners/lookingglass.png" alt="[Wiki]" width="12" height="12"></a>');
	#
	#	print "Wiki: $arg, $ref, $text\n";
	return $r;
}


sub TagDPL
{
	my ($fpi, $tag, $attrs, $data) = @_;
	my $text = '';

	my $linkstoname = "Category:$attrs->{category}";
	my $wikiobj = $fpi->db->load_one('WikiEntry', name => $linkstoname);
	
	if (defined($wikiobj))
	{
		my @objs = map {$db->load_one('WikiEntry', id => $_->from_id) }
						$db->load('WikiEntryReference', to_id => $wikiobj->id);

		if (defined($attrs->{pattern}))
		{
			my $pattern = $attrs->{pattern};
			@objs = grep {$_->name =~ /$pattern/} @objs;
		}


		if ($attrs->{order} eq 'descending')
		{
			@objs = sort {$b->name cmp $a->name} @objs;
		}
		else
		{
			@objs = sort {$a->name cmp $b->name} @objs;
		}


		my $limit = defined($attrs->{count}) ? $attrs->{count} : 999999999;
		$text = '<ul>';
		
		for (my $i = 0; $i < @objs && $i < $limit; ++$i)
		{
			$text .= "<li><a href=\"./".ConvertTextToWiki($objs[$i]->name).'">'
					  .$objs[$i]->name."</a>\n";
		}
		$text .= '</ul>';
				 
	}
	else
	{
		warn "$linkstoname not found\n";
	}
	return $text;
}

sub TagVideoflash()
{
	my ($fpi, $tag, $attrs, $data) = @_;

	return <<EOF;
<object style="" width="425" height="350"> <param name="movie" value="http://www.youtube.com/v/$data"> <param name="allowfullscreen" value="true"> <param name="wmode" value="transparent"> <embed src="http://www.youtube.com/v/$data" type="application/x-shockwave-flash" wmode="transparent" allowfullscreen="true" style="" flashvars="" width="425" height="350"></object>
EOF
}



sub TagGooglemap()
{
	my ($fpi, $tag, $attrs, $data) = @_;

	
	my $r;

	unless ($fpi->googlemapnum) {
		$fpi->googlemapnum(0);
		$r = <<EOF;
<script src="http://maps.google.com/maps?file=api&amp;v=2&amp;key=ABQIAAAA5bnmoyI0qgIhAMohxYIDGRRnstFjj-VwPFW1Yamy-XfT3YF74RTtTIkyyd_WArVu_AjLpZ6ovlzZPw&amp;hl=en" type="text/javascript"></script>
<script type="text/javascript">
//<![CDATA[
var mapIcons = {};function addLoadEvent(func) {var oldonload = window.onload;if (typeof oldonload == 'function') {window.onload= function() {oldonload();func();};} else {window.onload = func;}}
//]]>
</script>
EOF

	}
	my $mapnum = $fpi->googlemapnum;
	$fpi->googlemapnum(++$mapnum);
	
	my $width = $attrs->{width} || 640;
	my $height = $attrs->{height} || 400;
	$width = $width . 'px';
	$height = $height . 'px';

	$r .= <<EOF;
<div class="map" id="map$mapnum" style="width: $width; height: $height; direction: ltr;"></div><script type="text/javascript">
//<![CDATA[
function makeMap$mapnum() 
{
    if (!GBrowserIsCompatible())
    {
        document.getElementById("map$mapnum").innerHTML = "In order to see the map that would go in this space, you will need to use a compatible web browser. <a href=\\"http://local.google.com/support/bin/answer.py?answer=16532&amp;topic=1499\\">Click here to see a list of compatible browsers.</a>";
        return;
    }
    var map = new GMap2(document.getElementById("map$mapnum"));
    map.addMapType(G_PHYSICAL_MAP);
    GME_DEFAULT_ICON = G_DEFAULT_ICON;
    map.setCenter(new GLatLng($attrs->{lat}, $attrs->{lon}), $attrs->{zoom}, G_HYBRID_MAP);
    GEvent.addListener(map, 'click', function(overlay, point)
		 {
           if (overlay)
		     {
               if (overlay.tabs)
               {
                   overlay.openInfoWindowTabsHtml(overlay.tabs);
               }
               else if (overlay.caption)
               {
                   overlay.openInfoWindowHtml(overlay.caption);
               }
           }
       });
    map.addControl(new GHierarchicalMapTypeControl());
    map.addControl(new GSmallMapControl());
EOF

	$data =~ s/^\s+//xsi;
	while ($data ne '') {
		$data =~ s/^\n+//xi;

		my $changed;
		#		if ($data =~ s/^(-?\d+\.\d+)\,\s*(-?\d+\.\d+)((\n([A-Z].*?))|(\,\s*(.*?))|)\n//xi)
		if ($data =~ s/^(kml|georss)\:(.*)(\n|$)//x)
		{
			$r .= "\nvar gx = new GGeoXml(\"$2\");\nmap.addOverlay(gx);\n";
			$changed = 1;
		}
		if ($data =~ s/^(-?\d+\.\d+)\,\s*(-?\d+\.\d+)(\,\s*(.*?))\n//xi)
		{
			my $lat = $1;
			my $lon = $2;
			my $caption = '';
			my $title = '';
			if (defined($3))
			{
				$title = $4;
				$caption = "<p><b>$4</b></p>";
			}

			while ($data =~ s/^([A-Z].*?)\n//xi) {
				$caption .= $1;
			}

			$caption =~ s/\n/\\n/xsi;
			$caption =~ s/\'/\\'/xsi;

			$r .= <<EOF;
	marker = new GMarker(new GLatLng($lat,$lon), {  'title' : '$title', 'icon': GME_DEFAULT_ICON,  'clickable': true  });
    marker.caption = '$caption';
    map.addOverlay(marker); GME_DEFAULT_ICON = G_DEFAULT_ICON;
EOF
			$changed = 1;
		}
		if ($data =~ s/^(-?\d+\.\d+)\,\s*(-?\d+\.\d+)\n([\w].*?)(\n+|$)//xi)
		{
			my $lat = $1;
			my $lon = $2;
			my $caption = '';
			my $title = '';
			if (defined($3))
			{
				$title = $3;
				$caption = "<p><b>$3</b></p>";
			}

			while ($data =~ s/^([A-Z].*?)\n//xi) {
				$caption .= $1;
			}

			$caption =~ s/\n/\\n/xsi;
			$caption =~ s/\'/\\'/xsi;

			$r .= <<EOF;
	marker = new GMarker(new GLatLng($lat,$lon), {  'title' : '$title', 'icon': GME_DEFAULT_ICON,  'clickable': true });
    marker.caption = '$caption';
    map.addOverlay(marker); GME_DEFAULT_ICON = G_DEFAULT_ICON;
EOF
			$changed = 1;
		}
		if ($data =~ s/^(\d+)\#([0-9A-F][0-9A-F])([0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F])\n//xi) {
			my $zoomq = $1;
			my $huh = $2;
			my $color = $3;
			$r .= 'map.addOverlay(new GPolyline( [ ';
			my $addComma;
			while ($data =~ s/^\n*(-?\d+\.\d+)\,\s*(-?\d+\.\d+)\n//x) {
				$r .= ($addComma ? ',' : '') . "new GLatLng($1,$2)";
				$addComma = 1;
			}
			$r .=  "], '#$color', $zoomq, 0.698039215686, {'clickable': false}));\n  GME_DEFAULT_ICON = G_DEFAULT_ICON;";
			$changed = 1;
		}
		if ($data =~ s/^\n*(-?\d+\.\d+)\,\s*(-?\d+\.\d+)\n//x)
		{
			$r .= 'map.addOverlay(new GPolyline( [ ';
			my $addComma;
			do
			{
				$r .= ($addComma ? ',' : '') . "new GLatLng($1,$2)";
				$addComma = 1;
			}
			while ($data =~ s/^\n*(-?\d+\.\d+)\,\s*(-?\d+\.\d+)\n//x);
			$r .=  "], '#758BC5', 6, 0.698039215686, {'clickable': false}));  GME_DEFAULT_ICON = G_DEFAULT_ICON;";
			$changed = 1;
		}
		if (!$changed) {
			print("Failed: $data\nFile: ".$fpi->wikiobj->inputname."\n");
			$data = '';
		}
	}
	$r .= <<EOF;
}
 addLoadEvent(makeMap$mapnum);
//]]>
</script>
EOF

	return $r;
}

sub SingleFile($$)
{
	my ($file, $fpi) = @_;
	open(I, $file)
		|| die "Unable to open $file for reading";
	my $t = join('',<I>);
	close I;

	my $parse = Flutterby::Parse::Text->new(-wiki => \&TagWiki,
											-specialtags =>
											{
												'dpl' => \&TagDPL,
												'googlemap' => \&TagGooglemap,
												'videoflash' => \&TagVideoflash,
											},
											-callbackobj => $fpi);
	my $tree = $parse->parse($t);
	return $tree;
}


sub OutputTreeAsHTML($$$$$)
{
	my ($tree, $title, $fpi, $subsections, $linkshere) = @_;
	my $head = Flutterby::Tree::Find::node($tree, 'head');
	if (!defined($head)) {
		my @additionalheaders;
		if ($title eq 'User:DanLyke')
		{
			@additionalheaders =
				(
				 'link',
				 [ { rel  => "openid.server",
					 href => "http://www.myopenid.com/server" },
				   '0', "\n", ],
				 'link',
				 [ { rel  => "openid.delegate",
					 href => "http://danlyke.myopenid.com/" },
				   '0', "\n", ],
				 'link',
				 [ { rel  => "openid2.local_id",
					 href => "http://danlyke.myopenid.com" },
				   '0', "\n", ],
				 'link',
				 [ { rel  => "openid2.provider",
					 href => "http://www.myopenid.com/server" },
				   '0', "\n", ],
				 'meta',
				 [ { 'http-equiv' => "X-XRDS-Location",
					 content      => "http://www.myopenid.com/xrds?username=danlyke.myopenid.com" },
				   '0', "\n", ],
				 '0', "\n",
				);
		}
		if ($title =~ /^Category:/)
		{
			my $syndifile = $title;
			$syndifile =~ s/\s/_/g;
			push @additionalheaders,
			(
			 'link',
			 [ { rel => 'alternate',
				 href => "http://www.flutterby.net/$syndifile.rss",
				 title => 'RSS',
				 type => 'application/rss+xml',
			   },
			   '0', "\n", ],
			);
		}

		$head = ['head', [{},
						  'title' => [{},
									  '0', $title
									 ],
						  '0', "\n",
						  'style' => [ { type=> 'text/css' },
									   '0', '@import "/screen.css";'
									 ],
						  '0', "\n",
						  'link' => [ { rel  => 'icon',
										href => '/favicon.ico',
										type => 'image/ico',
									  },
									],
						  '0', "\n",
						  'link' => [ { rel  => 'shortcut icon',
										href => '/favicon.ico',
									  },
									],
						  '0', "\n",
						  @additionalheaders
						 ],
				 '0', "\n",
				];
		my $html = Flutterby::Tree::Find::node($tree, 'html');
		$html = $html->[1];
		my $att = shift @$html;
		unshift @$html, $att, @$head;
		#splice @$html, 1, 0, $head;
	}

	my $body = Flutterby::Tree::Find::node($tree, 'body');
	$body = $body->[1];
 
	my @contentsections;


	if (@$subsections) {
		my @subs;
		
		foreach my $sub (@$subsections) {
			push @subs, 'li', [{},
							   'a', [ {href => '#'.$sub->[2]},
									  '0', $sub->[1],
									],
							   '0', "\n",
							  ];
		}
		push @contentsections,
			'div',
				[ {class=>'sections'}, 
				  'h2', [{}, '0', 'Sections' ],
				  '0', "\n",
				  'ul', [{}, @subs]],
					  '0', "\n",
	}
	
	{
		my @contentdiv = 
			(
			 {class=>'content'},splice(@$body, 1, $#$body),
			 'br', [{ clear => "all" }],
			);
		push @contentsections,
			 'div', \@contentdiv,
			 'div',
		[
				 { class => 'footer' },
				 'p',
				 [
				  {},
				  '0', 'Flutterby.net is a publication of ',
				  'a', [
					  {href=>'mailto:danlyke@flutterby.com'},
					  '0', 'Dan Lyke',
				  ],
				  '0', ' and unless otherwise noted, copyright by Dan Lyke',
				 ]
		];

		}
	



	push @$body, 'div',
	[
	 {
		 class => 'contentcolumn',
	 },
	 @contentsections,
	  
	];

	my @sidebar;

	if (@$linkshere)
	{
		my @linksherediv = {};
		foreach (@$linkshere)
		{
			push @linksherediv,
				'li', [ {}, 'a', [ { href => './'.ConvertTextToWiki($_->name)},
								   '0',
								   $_->name ],
						'0', "\n",
					  ];
		}
		push @sidebar,
			'div', [ {class => 'linkshere'},
					 'h2', [{}, '0', "Pages which link here" ],
					 '0', "\n",
					 'ul', \@linksherediv,
					 '0', "\n",
				   ],
	}
	

	if (1)
	{
		my @navbar = {};
		foreach (['Main_Page', 'Main Page'],
				 ['Categories', 'Categories'],
				['User%3aDanLyke', 'Dan Lyke'])
		{
			push @navbar,
				'li', [ {}, 'a', [ { href => $_->[0]},
								   '0',
								   $_->[1] ],
						'0', "\n",
					  ];
		}
		push @sidebar,
			'div', [ {class => 'navbar'},
					 'h2', [{}, '0', 'Navigation' ],
					 '0', "\n",
					 'ul', \@navbar,
					 '0', "\n",
				   ],
	}

	my $att = shift @$body;
	unshift @$body, $att, 'div', [ {class => 'sidebar'}, @sidebar];
	


	if (defined($title))
	{
		my $att = shift @$body;
		unshift @$body, $att, 
			'h1', [{}, '0', "$title"], 
				'0', "\n";
				
	}

	
	my $r;
	my $output = Flutterby::Output::HTML->new();
	$output->setOutput(\$r);
	$output->output($tree);
	return $r;
}





sub CopyIfChanged($$@)
{
	my ($outputfile, $stagingfile, $sourcefile) = @_;
	$sourcefile = $stagingfile unless defined($sourcefile);
 	if (-f $stagingfile) {
		my $changed;

		if (-f $outputfile) {
			open(F1, $stagingfile)
				|| die "Unable to open $stagingfile for reading\n";
			open(F2, $outputfile)
				|| die "Unable to open $outputfile for reading\n";

			my $l1 = join('', <F1>);
			my $l2 = join('', <F2>);
			close F1;
			close F2;
			$changed = 1 if ($l1 ne $l2);
		} else {
			$changed = 1;
		}

		if (defined($changed)) {
			open F1, $stagingfile
				|| die "Unable to open $stagingfile for reading\n";
			$outputfile = $1 if ($outputfile =~ /^(.*)$/);
			$sourcefile = $1 if ($sourcefile =~ /^(.*)$/);
			open F2, ">$outputfile"
				|| die "Unable to open $outputfile for writing\n";
			print F2 join('', <F1>);
			close F1;
			close F2;
			my $cmd = "/usr/bin/touch -r \"$sourcefile\" \"$outputfile\"";
			system($cmd);
		}
	}
}


sub CopyWikiObjIfChanged($$)
{
	my ($fpi, $wikiobj) = @_;
	$fpi->wikiobj($wikiobj);
		
	my $outputname = ConvertTextToWiki($wikiobj->name, 1);
	my $stagingfile = "$stagingdir/$outputname".$fpi->suffix;
	my $outputfile = "$outputdir/$outputname".$fpi->suffix;
	
	CopyIfChanged($outputfile, $stagingfile, 
				  "$sourcedir/".$wikiobj->inputname);
	if ($outputname =~ /^Category:/)
	{
		$stagingfile = "$stagingdir/$outputname.rss";
		$outputfile = "$outputdir/$outputname.rss";
		CopyIfChanged($outputfile, $stagingfile, 
					  "$sourcedir/".$wikiobj->inputname);
	}
}

sub DoRss($$)
{
	my ($fpi, $wikiobj) = @_;
	my $wikiname = $wikiobj->name;
	$fpi->wikiobj($wikiobj);
	my $t = SingleFile("$sourcedir/".$wikiobj->inputname,$fpi);
			
			
	my $rss = XML::RSS->new(version => '2.0');
	$rss->channel
		(
		 title => "Flutterby.net: $1",
		 link => "http://www.flutterby.net/".ConvertTextToWiki($wikiobj->name),
		 language => 'en',
		);
			
	my @refby = $wikiobj->referencedBy($db);
	foreach my $refby (@refby)
	{
		$refby->initStatStuff();
	}
#		my @entries = sort {$b->mtime() <=> $a->mtime()} @refby;
	my @entries = sort {$b->name() cmp $a->name()} @refby;
	@entries = grep {$_->name =~ /^\d\d\d\d-\d\d-\d\d/} @entries
		if ($wikiname =~ /life/);
	for (my $i = 0; $i < 15 && $i < @entries; ++$i)
	{
		my $entry = $entries[$i];
		my $fn = "$stagingdir/".$entry->outputname;
		open(I, $fn)
			|| die "Unable to open $fn for reading\n";
		my $t = join('',<I>);
		close I;
		
		$t =~ s/^.*?\<div\ class="content">//xsig;
		$t =~ s%</div><div\ class="footer">.*$%%xsig;
		$t =~ s%(href=)"./%$1"http://www.flutterby.net/%xsig;
		$t =~ s%(src=)"./%$1"http://www.flutterby.net/%xsig;
		$t =~ s%(href=)"/%$1"http://www.flutterby.net/%xsig;
		$t =~ s%(src=)"/%$1"http://www.flutterby.net/%xsig;
		
		$rss->add_item(title => $entry->name,
					   permaLink => 'http://www.flutterby.net/'.$entry->outputnameRoot.'.html',
					   description => $t,
					   dc => {date => email_date($entry->mtime())},
			);
		
	}
	my $savefilename = "$stagingdir/".$wikiobj->outputnameRoot.".rss";
	$savefilename = $1 if ($savefilename =~ /^(.*)$/);
	$rss->save($savefilename);
}

sub MarkWikiEntriesNeedingRebuildFromRefs($$)
{
	my ($db, $refs) = @_;
	foreach my $ref (@$refs)
	{
		my $toobj = $db->load_one('WikiEntry', id => $ref->to_id);
		$toobj->needsExternalRebuild(1);
		$db->write($toobj);
	}
}



sub DoWikiObj($$)
{
	my ($fpi, $wikiobj) = @_;
	confess("Undefined fpi\n") unless defined($fpi);
	confess("Undefined wikiobj\n") unless defined($wikiobj);
	$fpi->wikiobj($wikiobj);
	$fpi->googlemapnum(0);
		
	my $t = SingleFile("$sourcedir/".$wikiobj->inputname,$fpi);
		
	my @nodes = Flutterby::Tree::Find::allNodes($t, 
												{
													'h1' => 1,
													'h2' => 1,
													'h3' => 1,
													'h4' => 1,
													'h5' => 1,
													'h6' => 1,
												});
	my @subsections;
	foreach my $node (@nodes) {
		my $out = Flutterby::Output::Text->new();
		my $t;
		$out->setOutput(\$t);
		$out->output($node->[1],1);
		my $n = "$node->[0]:".ConvertTextToWiki($t);
		push @subsections, [$node->[0], $t, $n];
		splice @{$node->[1]}, 1, 0, 'a', [{name=>$n}];
	}
		
	my @linkshere = sort {$a->name cmp $b->name} ($wikiobj->referencedBy($db));
	
	my $r = OutputTreeAsHTML($t,$wikiobj->name, $fpi, \@subsections, \@linkshere);
	my $outfile = ConvertTextToWiki($wikiobj->name, 1);
	my $fullpath = "$stagingdir/$outfile".$fpi->suffix;
	$fullpath = $1 if ($fullpath =~ /^(.*)$/);

	if (open O, ">$fullpath")
	{
		print O '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"  "http://www.w3.org/TR/html4/loose.dtd">';
		print O "\n";
		print O $r;
		close O;
	}
	else
	{
		warn "Unable to write to $fullpath\n";
	}
}


sub DoDirtyFiles()
{
	ReadConfig();
	my $fpi = FbyParserInfo->new(outputdir => $outputdir,
								 db => $db,
								 suffix => '.html');

	my %allentries;
	my @entries = $db->load('WikiEntry', needsContentRebuild => 1);

	foreach my $wikiobj (@entries)
	{
		$allentries{$wikiobj->name} = $wikiobj;
		print "Rebuilding ".$wikiobj->name."\n";
		DoWikiObj($fpi, $wikiobj);
		my @refs = $db->load('WikiEntryReference',
							 from_id => $wikiobj->id);
		MarkWikiEntriesNeedingRebuildFromRefs($db, \@refs);
		$wikiobj->needsContentRebuild(0);
		$db->write($wikiobj);
	}
	@entries = $db->load('WikiEntry', needsExternalRebuild => 1);

	foreach my $wikiobj (@entries)
	{
		$allentries{$wikiobj->name} = $wikiobj;
		print "Rebuilding external links for ".$wikiobj->name."\n";
		DoWikiObj($fpi, $wikiobj);
		$wikiobj->needsContentRebuild(0);
		$db->write($wikiobj);
	}
	foreach my $wikiobj (values %allentries)
	{
		CopyWikiObjIfChanged($fpi,$wikiobj);
	}
}


sub DoWikiFiles()
{
	ReadConfig();

	opendir IN_DIR, $sourcedir
		|| die "Unable to open directory '$sourcedir' for reading\n";


	while (my $filename = readdir(IN_DIR))
	{
		if ($filename =~ /^(\w.*?).wiki$/)
		{
			my $wikiname = $1;
			$wikiname =~ s/\s+/\ /xsg;
			$wikiname =~ s/\:\s*/\:/xsg;
			my $wobj = $db->load_or_create('WikiEntry',
										   name => $wikiname);
			$wobj->inputname($filename);
			$db->write($wobj);
#			$wikiobjects{$wobj->name} = $wobj;
		}
	}
	
	closedir IN_DIR;

	
	
	my $fpi = FbyParserInfo->new(outputdir => $outputdir,
								 db => $db,
								 suffix => '.html');
	
	print "FPI 1 is $fpi\n";
	
	my %missingpages;

	my @wikiobjects = $db->load('WikiEntry');

	foreach my $wikiobj (@wikiobjects)
	{
		$fpi->wikiobj($wikiobj);
		$fpi->googlemapnum(0);
		
		
		my $t = SingleFile("$sourcedir/".$wikiobj->inputname,$fpi);
		
		
		foreach (keys %{$wikiobj->_missingReferences})
		{
			$missingpages{$_} = [] unless (defined($missingpages{$_}));
			push @{$missingpages{$_}},$wikiobj;
		}
	}
	
		
	print "FPI 2 is $fpi\n";

	foreach my $wikiobj (@wikiobjects)
	{
		DoWikiObj($fpi, $wikiobj);
	}
	
	print "FPI 3 is $fpi\n";
	
	foreach my $wikiobj (@wikiobjects)
	{
		my $wikiname = $wikiobj->name;
		$fpi->wikiobj($wikiobj);
		$fpi->googlemapnum(0);
		
		if ($wikiname =~ /^Category:\s*(.*)$/)
		{
			DoRss($fpi, $wikiobj);
		}
	}
	
	
	
	foreach my $wikiobj (@wikiobjects)
	{
		CopyWikiObjIfChanged($fpi, $wikiobj);
	}
	
	
	if (0)
	{
		foreach (keys %missingpages)
		{
			print "Missing '$_' : ". join(', ', @{$missingpages{$_}})."\n";
		}
	}
}

sub DoEverything()
{
	ReadConfig();
	my $fpi = FbyParserInfo->new(outputdir => $outputdir,
								 db => $db,
								 suffix => '.html');
	FindAllFiles($fpi, $sourcedir);

	DoWikiFiles();
}


sub GetWikiFiles()
{
	ReadConfig();
	opendir IN_DIR, $sourcedir
		|| die "Unable to open directory '$sourcedir' for reading\n";
	while (my $filename = readdir(IN_DIR))
	{
		print "$1\n" if ($filename =~ /^(\w.*?).wiki$/);

	}
	closedir IN_DIR;
}



sub WriteWikiFile()
{
	my ($wikifile) = @_;
	ReadConfig();
	$wikifile = $1 if ($wikifile =~ s/[><\/\\]//g);
	open(OUT, ">$sourcedir/$wikifile.wiki")
		|| die "Unable to open $sourcedir/$wikifile.wiki for writing\n";

	while (<STDIN>)
	{
		print OUT $_;
	}
	close OUT;

	my $wobj = $db->load_or_create('WikiEntry',
								   name => $wikifile);
	$wobj->needsContentRebuild(1);
	$wobj->inputname("$wikifile.wiki");
	my @refs = $db->load('WikiEntryReference',
						 from_id => $wobj->id);
	MarkWikiEntriesNeedingRebuildFromRefs($db, \@refs);
	$db->write($wobj);
	$db->delete('WikiEntryReference', from_id => $wobj->id);
}

sub ReadWikiFile()
{
	my ($wikifile) = @_;
	ReadConfig();
	open(IN, "$sourcedir/$wikifile.wiki")
		|| die "Unable to open $sourcedir/$wikifile.wiki for writing\n";
	while (<IN>)
	{
		print $_;
	}
	close IN;
}


sub RebuildDetached()
{
	ReadConfig();
	my $cmd = "setsid sh -c './bin/fby.pl dowikifiles \& :' > /dev/null 2>\&1 < /dev/null";
	system($cmd);
}

sub GetISO8601Day()
{
    my ($mday,$mon,$year) = (localtime(time))[3..5];
    return sprintf("%04.4d-%02.2d-%02.2d", $year + 1900, $mon + 1, $mday);
}


sub FindLatestNumInDir($)
{
    my ($dir) = @_;
    opendir(NID, $dir)
	|| die "FindLatestNumInDir: Unable to open $dir\n";
    my $highest = -1;

    while (my $file = readdir(NID))
    {
	if ($file =~ /^\d+$/)
	{
	    $highest = $file if ($file > $highest);
	}
    }
    closedir NID;
    return $highest;
}

sub ImportKML()
{
	my ($subject, $categories, $directory) = @_;
	$directory = $1 if ($directory =~ /^(.*)$/);
	my $config = ReadConfig();
	$subject =~ s/[^\w\ ]//xsig;

	my $isoday = GetISO8601Day();

	my $target = $outputdir;
	my $kmlpath = ''; 

	my $dirnum = FindLatestNumInDir($target);
	++$dirnum;

	foreach ('kml', $isoday, $dirnum)
	{
		$target .= "/$_";
		$kmlpath .= "/$_";
		print "Making $target\n";
		mkdir $target;
	}

	opendir(DI, $directory)
		|| die "Unable to open $directory\n";
	my @files = grep {/^[^\.]/} readdir DI;
	closedir DI;

	print "Found files ".join(', ', @files)."\n";

	my $kmlfile;

	foreach (@files)
	{
		$kmlfile = $_ if /\.kml$/i;
	}

	die "Unable to find KML file\n"
		unless defined($kmlfile);

	chdir $directory;
	my $targetkmz = "$target/GPSLog.kmz";
	$targetkmz = $1 if ($targetkmz =~ /^(.*)$/);
	for (my $i = 0; $i < @files; ++$i)
	{
	    $files[$i] =$1 if ($files[$i] =~ /^(.*)$/);
	}
	system('zip',
	       "$target/GPSLog.kmz",
	       @files);
	system('cp',
		   @files,
		   $target);
	chdir $config->{InstallDir};

	print "Processing $target/$kmlfile\n";

    open(I,"$target/$kmlfile")
		|| die "Unable to open $target/$kmlfile\n";
    my $t = join('', <I>);
    close I;

    $t =~ s%(img src\=\")(\w)%$1$kmlpath/$2%g;
	my $targetkmlfile = "$target/$kmlfile";
	$targetkmlfile = $1 if $targetkmlfile =~ /^(.*)$/;

    open(O, ">$targetkmlfile")
		|| die "Unable to open $target/$kmlfile for writing\n";
    print O $t;
    close O;

    my ($minlat,$minlon, $maxlat, $maxlon) = (999,999,-999,-999);
    while ($t =~ s/\<coordinates\>([\-0-9\.]+?)\,([\-0-9\.]+?)(\,[\-0-9\.]+?)?\<\/coordinates\>//)
    {
		$minlon = $1 if ($1 < $minlon);
		$minlat = $2 if ($2 < $minlat);
		$maxlon = $1 if ($1 > $maxlon);
		$maxlat = $2 if ($2 > $maxlat);
    }

    my $wikikmlfile = "./mvs/$isoday $subject.wiki";

	my @categories = ('KML Files',	split(/ *\, */, $categories));
    $t = join(' ', map{'[[Category: '.$_.']]'} @categories);

    if (-f $wikikmlfile)
    {
		open(I, $wikikmlfile)
			|| die "Unable to open $wikikmlfile\n";
		$t = join('', <I>);
		close I;
    }

    if ($t !~ /\=\= KML \$dirnum \=\=/)
    {
		my $lat = ($minlat + $maxlat) / 2;
		my $lon = ($minlon + $maxlon) / 2;
		my $newt = <<EOF;

== KML $dirnum ==

Here is <a href="$kmlpath/GPSLog.kmz"</a>the KMZ for $isoday $dirnum</a>,
centered at lat=$lat lon=$lon, KML is at $kmlpath/GPSLog.kml
			
<googlemap version="0.9" lat="$lat" lon="$lon" zoom="12">
kml:http://www.flutterby.net$kmlpath/$kmlfile
</googlemap>

EOF

$wikikmlfile = $1 if $wikikmlfile =~ /^(.*)$/;
		open(O, ">$wikikmlfile")
			|| die "Unable to open $wikikmlfile for writing\n";
		print O "$newt$t";
		close O;
    }
}




sub commands()
{
	return 
	{
	 'doeverything' => \&Fby::DoEverything,
	 'dowikifiles' => \&Fby::DoWikiFiles,
	 'getwikifiles' => \&Fby::GetWikiFiles,
	 'writewikifile' => \&Fby::WriteWikiFile,
	 'readwikifile' => \&Fby::ReadWikiFile,
	 'rebuilddetached' => \&Fby::RebuildDetached,
	 'importkml' => \&Fby::ImportKML,
	 'dodirtyfiles' => \&Fby::DoDirtyFiles,
	};
}


1;

=head1 NAME

Fby - The interface to the Flutterby.net wiki system

=head1 SYNOPSIS

Right now this is just a dumbing ground for the actual contents of a
script that does some SUID stuff and then calls the functions
retrieved from the hash returned by the Fby::commands subroutine.

=head1 DESCRIPTION

Available commands:

=head2 &{Fby::commands->{'doeverything'}}()

Find all image files, make sure they have .wiki files, and then
rebuild the wiki files. This is a great function to have but should
eventually go away as the system gets smarter.

=head2 &{Fby::commands->{'dowikifiles'}()

Rebuild all of the wiki files, but don't do the image scan.

=head2 &{Fby::commands->{'getwikifiles'}()

Get a list of all of the wiki files

=head2 &{Fby::commands->{'writewikifile'}('Wiki entry name')

Write an individual wiki file from STDIN to the wiki file repository.

=head2 &{Fby::commands->{'readwikifile'}('Wiki entry name')

Read an individual wiki file from STDIN from the wiki file repository.

=head2 &{Fby::commands->{'rebuilddetached'}()

Respawn './bin/fby.pl dowikifiles' as an setsid detached process.

=head2 &{Fby::commands->{'importkml'}('subject', 'categories', 'directory')

Import a KML file, creating a 'YYYY-MM-DD subject' Wiki file
referencing the comma separated categories listed, and an embedded
Google map.

'directory' is where to find the KML file.

=head2 &{Fby::commands->{'dodirtyfiles'}()

Just rebuild the files that have been marked dirty, right now just by
'writewikifile'.

