#!/usr/bin/perl -wT

# Author          : Johan Vromans
# Created On      : Tue Mar  3 11:09:45 2015
# Last Modified By: Johan Vromans
# Last Modified On: Tue Nov  6 08:28:03 2018
# Update Count    : 344
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use utf8;
use CGI qw( -debug );
use CGI::Carp qw(fatalsToBrowser);

use lib "/home/jv/src/Data-iRealPro/CPAN";
use lib "/home/jv/src/Data-iRealPro/lib";

chdir("/home/jv/src/Data-iRealPro/cgi-bin");
$ENV{FONTDIR} = "res/fonts";

use Template::Tiny;
use Data::iRealPro::URI;
use Data::iRealPro::Song;
use Data::iRealPro::Output::Imager;
use Data::iRealPro::Input;
use FindBin;

my $my_package = "Sciurix";
my ($my_name, $my_version) = qw( iRealPro/Web 0.07 );

print "Content-Type: text/html\n\n";

################ Program parameters ################

my $q = CGI->new;

my $uri = $q->param("uri");
my $npp = $q->param("npp");

################ Presets ################

my @majkeys = split( ' ', 'C  Dd  D  Eb E   F  Gb  G  Ab A   Bb B'   );
my @minkeys = split( ' ', 'A- Bb- B- C- C#- D- Eb- E- F- F#- G- G#-' );

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

my $u = Data::iRealPro::URI->new( data => $uri );

my $v = $u->{variant};
$v =~ s/^(.)(....)(.*)/$1.ucfirst($2).ucfirst($3)/e;

my $irp_site = "http://www.irealpro.com";
my $irp_icon = "$irp_site/wp-content/uploads/2013/10/irealpro-icon.png";

$tv->{site}->{name} = "$v Song viewer";
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
    my $image = sprintf( "tmp/ir%ds%d.png", $$, $song );
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
		    $s->{actual_key} ne ''
		    ? ( "; actual key: ",
			$s->{key} =~ /-$/ ? $minkeys[$s->{actual_key}] : $majkeys[$s->{actual_key}] ) : (),
		    $s->{actual_tempo}
		    ? ( "; tempo: ", $s->{actual_tempo} ) : (),
		    $s->{actual_repeats} && $s->{actual_repeats} > 1
		    ? ( "; repeat: ", $s->{actual_repeats} ) : (),
		    $s->{a2}
		    ? ( "; a2: ", $s->{a2} ) : (),
		  ),
	    cooked => $s->{data},
	    rows => 10,
	    image => $image,
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
img.image {
  width: 833px;
  border: 1px solid black;
}
</style>
</head>
<body>
  <h1>
    <a href="[% irp.site %]"><img src="[% irp.icon %]" height="72" width="72"></a>
    [% site.name %]
  </h1>
  [% IF playlist.name %]
  <p class="title">Playlist: [% playlist.name %]</p>
  [% END %]
  [% FOREACH song IN songs %]
  <form method="post" name="edit[% song.index %]">
  <p class="title">[% song.title %]</p>
  <p class="subtitle">[% song.subtitle %]</p>
  <p class="image"><img class="image" src="[% song.image %]"></p>
    <textarea class="irealbook" id="irealbook[% song.index %]"
     rows="5" cols="100"
     class="cooked">[% song.cooked %]</textarea>
    <input type="hidden" name="uri" value="[% uri %]">
  </form>
  [% END %]
  <hr>
</body>
</html>
EOD
}

1;
