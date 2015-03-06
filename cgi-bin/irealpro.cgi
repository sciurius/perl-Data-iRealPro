#!/usr/bin/perl -wT

# Author          : Johan Vromans
# Created On      : Tue Mar  3 11:09:45 2015
# Last Modified By: Johan Vromans
# Last Modified On: Fri Mar  6 17:35:34 2015
# Update Count    : 189
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use utf8;
use CGI ();
use CGI::Carp qw(fatalsToBrowser);

use lib "/home/jv/lib/perl5";
use lib "/home/jv/src/Music-iRealPro/lib";

use Template::Tiny;
use Music::iRealPro::URI;

my $my_package = "Sciurix";
my ($my_name, $my_version) = qw( iRealPro 0.01 );

################ Program parameters ################

my $uri = CGI::param("uri");

################ Presets ################

################ The Process ################

binmode STDOUT => ':utf8';

my $tt = Template::Tiny->new;
my $tv;				# template variables

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

$tv->{site}->{name} = "$v Data Analyzer";
$tv->{irp}->{site} = $irp_site;
$tv->{irp}->{icon} = $irp_icon;
$tv->{data}->{raw} = CGI::param("uri");

print( "Content-Type: text/html\n\n");

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
    print( "Content-type: text/html\n\n",
	   $tt->expand( tpl_form() ) );
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
</style>
<script>
function showspaces(form,on) {
  e = document.getElementById(form);
  if ( on ) {
    e.irealbook.value=e.irealbook.value.replace(/ /g,"\\u2423");
  }
  else {
    e.irealbook.value=e.irealbook.value.replace(/\\u2423/g," ");
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
  <form method="post"name="irform">
    <textarea name="uri" rows="5" cols="100">[% data.raw %]</textarea>
    <br>
    <input name="clear" value="Clear" type="submit"
           onclick='document.irform.uri.value="";return false'>
    <input name="submit" value="Analyze" type="submit">
  </form>
  [% IF playlist.name %]
  <p class="title">Playlist: [% playlist.name %]</p>
  [% END %]
  [% FOREACH song IN songs %]
  <p class="title">[% song.title %]</p>
  <p class="subtitle">[% song.subtitle %]</p>
  <form method="post" id="form[% song.index %]">
    <textarea name="irealbook" rows="5" cols="100" class="cooked">[% song.cooked %]</textarea>
    <br>
    <input name="ws" value="Show spaces" type="submit"
           onclick='javascript:showspaces("form[% song.index %]",1);return false'>
    <input name="hs" value="Hide spaces" type="submit"
           onclick='javascript:showspaces("form[% song.index %]",0);return false'>
  </form>
  <hr>
  [% END %]
</body>
</html>
EOD
}

1;
