#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Tue Mar  3 11:09:45 2015
# Last Modified By: Johan Vromans
# Last Modified On: Wed Feb 11 11:24:04 2026
# Update Count    : 409
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use utf8;
use CGI qw( -debug );
use CGI::Carp qw(fatalsToBrowser);

use Config;
$ENV{RESDIR}  = $Config{sitelib}."/Data/iRealPro/res";
$ENV{FONTDIR} = $ENV{RESDIR}."/fonts";

use Template::Tiny;
use Data::iRealPro::URI;
use Data::iRealPro::Song;
use Data::iRealPro::Output::Imager;
use Data::iRealPro::Input;
use FindBin;
use File::Temp qw( tempfile );

my $my_package = "Sciurix";
my ($my_name, $my_version) = qw( iRealPro/WebViewer 1.000 );

print "Content-Type: text/html\n\n";

################ Program parameters ################

my $q = CGI->new;

my $uri = $q->param("uri");
my $npp = $q->param("npp") // "hand";

################ Presets ################

my @majkeys = split( ' ', 'C  Dd  D  Eb E   F  Gb  G  Ab A   Bb B'   );
my @minkeys = split( ' ', 'A- Bb- B- C- C#- D- Eb- E- F- F#- G- G#-' );

# print CGI::Dump(), "\n";

################ The Process ################

binmode STDOUT => ':utf8';

my $tt = Template::Tiny->new;
my $tv = { uri => $uri };	# template variables

################ Main ################

my $u = Data::iRealPro::URI->new( data => $uri );

my $v = $u->{variant};
$v =~ s/^(.)(....)(.*)/$1.ucfirst($2).ucfirst($3)/e;

my $irp_site = "https://www.irealpro.com";
my $irp_icon = datasrc("irealpro-icon.png");

$tv->{site}->{name} = "iREAL&#x2009;PRO Song viewer";
$tv->{site}->{bottom} = "Powered by Perl and Data::iRealPro $Data::iRealPro::VERSION";
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

    # Make output names unique per song.
    ( undef, my $image ) = tempfile( "irpXXXXX", SUFFIX => '.png' );
    my $options = { output => $image, scale => 1.4, crop => 1 };
    $options->{npp} = $npp if $npp;

    # Re-package the song in a playlist.
    my $pl = Data::iRealPro::Playlist->new
      ( variant      => "irealpro",
	songs        => [ $s ],
	 $tv->{playlist}->{name} ? ( name => $tv->{playlist}->{name}  ) : (),
      );

    # Build a URI for the playlist.
    my $uri = Data::iRealPro::URI->new
      ( variant      => "irealpro",
	playlist     => $pl,
      );

    # Generate image.
    Data::iRealPro::Output::Imager->new($options)->process($uri);

    my $sep = " — ";
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
		    $s->{key} ? ( "${sep}key: ", $s->{key} ) : (),
		    $s->{actual_key} ne ''
		    ? ( "${sep}actual key: ",
			$s->{key} =~ /-$/ ? $minkeys[$s->{actual_key}] : $majkeys[$s->{actual_key}] ) : (),
		    $s->{actual_tempo}
		    ? ( "${sep}tempo: ", $s->{actual_tempo} ) : (),
		    $s->{actual_repeats} && $s->{actual_repeats} > 1
		    ? ( "${sep}repeat: ", $s->{actual_repeats} ) : (),
		    $s->{a2}
		    ? ( "${sep}a2: ", $s->{a2} ) : (),
		  ),
	    cooked => $s->{data},
	    rows => 10,
	    image => datasrc($image),
	  } );
}

$tv->{songs} = \@songs;

print( $tt->expand( tpl_playlist() ) );

################ Subroutines ################

sub Template::Tiny::expand {
    my ( $self, $inp ) = @_;
    my $res;
    $self->process( $inp, $tv, \$res );
    $res;
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
* {
  font-family: "sans", "sans-serif";
}
body {
   max-width: 900px;
   margin: auto;
   background: lightblue;
}
div.outer {
   margin: auto;
   width: 100%;
}
h1 {
  font-weight: bold;
  text-align: center;
  margin-bottom: 0pt;
}
p.title {
  font-weight: bold;
  margin-bottom: 0pt;
  margin-top: 0pt;
  text-align: center;
}
p.subtitle {
  margin-top: 0pt;
  margin-bottom: 0pt;
  text-align: center;
}
p.image {
  text-align: center;
}
img.image {
  width: 833px;
  padding: 5px;
  border: 1px solid black;
}
p.bottom {
  margin-top: 0pt;
  margin-bottom: 0pt;
  text-align: center;
  font-family: "mono", "monospace";
  font-size: 60%;
}
</style>
</head>
<body>
  <dov class="outer">
  <h1>
    iRPWeb&#x2001;<a href="[% irp.site %]"><img src="[% irp.icon %]" height="32" width="32"></a>
    [% site.name %]
  </h1>
  [% IF playlist.name %]
  <p class="title">Playlist: [% playlist.name %]</p>
  [% END %]
  [% FOREACH song IN songs %]
  <p class="title">[% song.title %]</p>
  <p class="subtitle">[% song.subtitle %]</p>
  <p class="image"><img class="image" src="[% song.image %]"></p>
  [% END %]
  <p class="bottom">[% site.bottom %]</p>
  </div>
</body>
</html>
EOD
}

sub datasrc {
    my ( $file ) = @_;
    use MIME::Base64 qw( encode_base64 );
    use File::LoadLines qw( loadblob );
    my $ext = "png";
    if ( $file =~ /\.(\w+)$/ ) {
	$ext = $1 eq 'jpg' ? 'jpeg' : $1;
    }

    return "data:image/$1;base64,".encode_base64( loadblob($file) )
}

1;
