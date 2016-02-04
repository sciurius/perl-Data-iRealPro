#!/usr/bin/perl -wT

# Author          : Johan Vromans
# Created On      : Tue Mar  3 11:09:45 2015
# Last Modified By: Johan Vromans
# Last Modified On: Thu Feb  4 09:51:54 2016
# Update Count    : 313
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use utf8;
use CGI qw( -debug );
use CGI::Carp qw(fatalsToBrowser);

use lib "/home/jv/lib/perl5";
use lib "/home/jv/src/Music-iRealPro/lib";

chdir("/home/jv/src/Music-iRealPro/cgi-bin");
$ENV{FONTDIR} = "../fonts";

use Template::Tiny;
use Music::iRealPro::URI;
use Music::iRealPro::PDF;

my $my_package = "Sciurix";
my ($my_name, $my_version) = qw( iRealPro 0.02 );

print "Content-Type: text/html\n\n";

################ Program parameters ################

my $q = CGI->new;

my $uri = $q->param("uri");

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

    my $image = "tmp/ir$$.png";
    my $options = { output => $image, scale => 1.4, crop => 1 };
    Music::iRealPro::PDF->new($options)->parsedata( $uri, $options );

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
		    $s->{a2}
		    ? ( "; a2: ", $s->{a2} ) : (),
		    $s->{a5}
		    ? ( "; a5: ", $s->{a5} ) : (),
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
