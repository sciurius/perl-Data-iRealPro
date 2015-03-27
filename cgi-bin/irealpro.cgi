#!/usr/bin/perl -wT

# Author          : Johan Vromans
# Created On      : Tue Mar  3 11:09:45 2015
# Last Modified By: Johan Vromans
# Last Modified On: Fri Mar 13 23:39:05 2015
# Update Count    : 279
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use utf8;
use CGI qw( -debug );
use CGI::Carp qw(fatalsToBrowser);

use lib "/home/jv/lib/perl5";
use lib "/home/jv/src/Music-iRealPro/lib";

use Template::Tiny;
use Music::iRealPro::URI;

my $my_package = "Sciurix";
my ($my_name, $my_version) = qw( iRealPro 0.01 );

print "Content-Type: text/html\n\n";

################ Program parameters ################

my $q = CGI->new;

my $edituri = $q->param("edituri");

my $uri = $q->param("uri");
if ( $edituri ) {
    $uri = parse_edit( $edituri );
    $q->param("uri", $uri);
}

my $edit = $q->param("edit");

################ Presets ################

# print CGI::Dump(), "\n";

################ The Process ################

binmode STDOUT => ':utf8';

my $tt = Template::Tiny->new;
my $tv = { uri => $uri };	# template variables

unless ( $uri ) {
    print_form();
    exit;
}

################ Main ################

my $u = Music::iRealPro::URI->new( data => $uri );

my $v = $u->{variant};
$v =~ s/^(.)(....)(.*)/$1.ucfirst($2).ucfirst($3)/e;

my $irp_site = "http://www.irealpro.com";
my $irp_icon = "$irp_site/wp-content/uploads/2013/10/irealpro-icon.png";

$tv->{site}->{name} = "$v Song " . ( $edit ? "Editor" : "Analyzer" );
$tv->{irp}->{site} = $irp_site;
$tv->{irp}->{icon} = $irp_icon;
$tv->{data}->{raw} = $uri;

if ( 0 && CGI::param("uri") ne $u->export ) {
    my @t1 = split( //, $u->export );
    my @t2 = split( //, CGI::param("uri") );
    my $i = 0;
    for ( ;; ) {
	last unless $t1[$i] eq $t2[$i];
	$i++;
    }
    print( "  <p class=\"title\">Import/export check: " .
	   "<font color=\"FF4040\">FAIL</font></p>\n",
	   "  <p class=\"subtitle\">", @t1[0..$i-1],
	   "<font color=\"FF4040\">$t1[$i]</font>",
	   @t1[$i+1..$#t1], "</p>\n" );
}
if ( defined $u->{playlist}->{name} ) {
    $tv->{playlist}->{name} = $u->{playlist}->{name} || "<NoName>";
}

# Process the song(s).
my $song = 0;
my @songs;

foreach my $s ( @{ $u->{playlist}->{songs} } ) {
    $song++;
    my $ed = $edit ? editable($s->{data}) : "";
    push( @songs,
	  { index => $song,
	    title =>
	      join( "",
		    ( $song > 1 || $tv->{playlist}->{name} ) ? "Song $song: " : "Song: ",
		    $s->{title},
		    " (", $s->{composer},  ")" ),
	    subtitle =>
	      join( "",
		    "Style: ", $s->{style},
		    $s->{actual_style}
		    ? ( " (", $s->{actual_style}, ")" ) : (),
		    $s->{key} ? ( "; key: ", $s->{key} ) : (),
		    $s->{actual_tempo}
		    ? ( "; tempo: ", $s->{actual_tempo} ) : (),
		    $s->{actual_repeats} && $s->{actual_repeats} > 1
		    ? ( "; repeat: ", $s->{actual_repeats} ) : (),
		  ),
	    cooked => $s->{data},
	    edit => $ed,
	    rows => 10 + ( $ed =~ tr/\n// ),
	  } );
}

$tv->{songs} = \@songs;

print( $tt->expand( tpl_playlist() ) );

exit (0);

################ Subroutines ################

sub Template::Tiny::expand {
    my ( $self, $inp ) = @_;
    my $res;
    $self->process( $inp, $tv, \$res );
    $res;
}

sub print_form {
    my $url = "http://" . $ENV{SERVER_NAME} . ":" . $ENV{SERVER_PORT} .
      $ENV{SCRIPT_NAME} . "?uri=%s";
    $tv->{url} = $url;
    print( $tt->expand( tpl_form() ) );
}

sub editable {
    my $t = "";

    foreach my $x ( split(/(\<[^\>]+>)/, $_[0] ) ) {
	if ( $x =~ /^\<.*\>$/ ) {
	    $t .= $x;
	    next;
	}
	$x =~ s/ / _ /g;
	$t .= $x;
    }

    while ( $t =~ s/_ +_/__/g ) {}
    $t =~ s/([\]\}])/$1\n/g;
    $t =~ s/([\[\{])/\n$1/g;
    $t =~ s/\n\n+/\n/g;
    $t =~ s/^\n+//;
    $t =~ s/^ +_/_/mg;
    $t =~ s/_ +$/_/mg;
    $t =~ s/\n+$/\n/;

    return $t;
}

sub parse_edit {
    my ( $data ) = @_;

    $data =~ s/[\r\n]+/\n/g;
    my $variant = "irealpro";
    my $tv = {};

    if ( $data =~ /^#\s*Playlist:\s*(.*)/m ) {
	$tv->{pl_name} = $1 unless $1 eq "<NoName>";
    }

    if ( $data =~ /^#\s*Song(?:\s+\d+)?:\s+(.*?)\s+\((.*?)\)/m ) {
	$tv->{title} = $1;
	$tv->{composer} = $2;
    }

    if ( $data =~ /^#\s*Style:\s+([^;(]*)(?:\s+\(([^)]+)\))?(?:;|$)/m ) {
	$tv->{style} = $1;
	$tv->{actual_style} = $2;
    }

    if ( $data =~ /; key:\s+(.+?)(;|$)/ ) {
	$tv->{key} = $1;
    }

    if ( $data =~ /; tempo:\s+(\d+)/ ) {
	$tv->{actual_tempo} = $1;
    }

    $data =~ s/^#.*//mg;
    $data =~ s/^\n+//;

    my $ir;
    foreach my $x ( split(/(\<[^\>]+>)/, $data ) ) {
	if ( $x =~ /^\<.*\>$/ ) {
	    $ir .= $x;
	    next;
	}
	$x =~ s/\s+//g;
	$x =~ s/_/ /g;
	$ir .= $x;
    }

    my $song = Music::iRealPro::SongData->new
      ( variant	     => $variant,
	title	     => $tv->{title},
	composer     => $tv->{composer}     || "Composer",
	style	     => $tv->{style}        || "Rock Ballad",
	key	     => $tv->{key}          || "C",
	actual_tempo => $tv->{actual_tempo} || "0",
	actual_style => $tv->{actual_style} || "",
     );
    $song->{data} = $ir;

    my $pl = Music::iRealPro::Playlist->new
      ( variant      => $variant,
	songs        => [ $song ],
	$tv->{pl_name} ? ( name => $tv->{pl_name} ) : (),
	);

    my $uri = Music::iRealPro::URI->new
      ( variant      => $variant,
	playlist     => $pl,
      );

    $uri->export( html => 0 );
}

################ Templates ################

sub tpl_form {
    \<<'EOD';
<!DOCTYPE html>
<html>
<head>
  <title>Register iRealPro Protocol Handlers</title>
  <script type="text/javascript">
    navigator.registerProtocolHandler("irealb", "[% url %]", "iRealPro handler");
    navigator.registerProtocolHandler("irealbook", "[% url %]", "iRealPro handler");
  </script>
</head>
<body>
  <h1>Register iRealPro Protocol Handlers</h1>
  <p>The web protocol handlers for
<code>irealb:</code> and <code>irealbook:</code> protocols will be installed.</p>
</body>
</html>
EOD
}

sub tpl_playlist {
    \<<'EOD';
<!DOCTYPE html>
<html>
<head>
<title>[% site.name %]</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<style>
p.title {
  font-weight: bold;
  margin-bottom: 0pt;
}
p.subtitle {
  margin-top: 0pt;
  margin-bottom: 0pt;
}
textarea.uri {
  font-family: "courier", "monospace";
}
textarea.irealbook {
  font-family: "courier", "monospace";
}
</style>
<script>
function showspaces(el,on) {
  b = document.getElementById("ws" + el);
  e = document.getElementById("irealbook" + el);
  if ( b.value == "Show spaces" ) {
    e.value = e.value.replace(/ /g,"\u2423");
    b.value = "Hide spaces";
  }
  else {
    e.value = e.value.replace(/\u2423/g," ");
    b.value = "Show spaces";
  }
}
</script>
</head>
<body>
  <h1>
    <a href="[% irp.site %]"><img src="[% irp.icon %]" height="72" width="72"></a>
    [% site.name %]
  </h1>
  <p class="title">Original URI:</p>
  <form method="post" name="irform">
    <textarea class="uri" name="uri" rows="5" cols="100">[% data.raw %]</textarea>
    <br>
    <input name="clear" value="Clear" type="submit"
           onclick='document.irform.uri.value="";return false'>
    <input name="submit" value="Analyze" type="submit">
  </form>
  [% IF playlist.name %]
  <p class="title">Playlist: [% playlist.name %]</p>
  [% END %]
  [% FOREACH song IN songs %]
  [% IF song.edit %]
  <p class="title">Edit: whitespace will be ignored, _ denote actual spaces.</p>
  [% END %]
  <form method="post" name="edit[% song.index %]">
    [% IF song.edit %]
    <textarea name="edituri" class="irealbook" id="irealbook[% song.index %]"
     rows="[% song.rows %]" cols="100"
     class="edit"># [% song.title %]
# [% song.subtitle %]

[% song.edit %]</textarea>
    <br>
    <input name="submit" value="Submit" type="submit">
    [% ELSE %]
  <p class="title">[% song.title %]</p>
  <p class="subtitle">[% song.subtitle %]</p>
    <textarea class="irealbook" id="irealbook[% song.index %]"
     rows="5" cols="100"
     class="cooked">[% song.cooked %]</textarea>
    <br>
    <input name="ws" id="ws[% song.index %]" value="Show spaces" type="submit"
           onclick='javascript:showspaces([% song.index %],1);return false'>
    <input name="edit" id="edit[% song.index %]" value="Edit" type="submit">
    [% END %]
    <input type="hidden" name="uri" value="[% uri %]">
  </form>
  <hr>
  [% END %]
</body>
</html>
EOD
}

1;
