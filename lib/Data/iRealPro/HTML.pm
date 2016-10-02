#! perl

# Data::iRealPro::HTML -- produce iRealPro HTML data

# Author          : Johan Vromans
# Created On      : Fri Sep 30 19:36:29 2016
# Last Modified By: Johan Vromans
# Last Modified On: Sun Oct  2 21:21:37 2016
# Update Count    : 35
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::HTML;

our $VERSION = "0.01";

use Data::iRealPro::URI;
use Data::iRealPro::Playlist;
use Encode qw( encode_utf8 );
use HTML::Entities;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant transpose split dir ) ) {
	$self->{options}->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub process {
    my ( $self, $u, $options ) = @_;

    unless ( $self->{options}->{split} ) {

	$self->{options}->{output} ||= "__new__.html";

	open( my $fd, ">:utf8", $self->{options}->{output} )
	  or croak( "Cannot create ", $self->{options}->{output}, " [$!]\n" );
	print $fd to_html($u);
	close($fd);
	return;
    }

    my $outdir = $self->{options}->{dir} || "";
    $outdir .= "/" if $outdir && $outdir !~ m;/$;;

    foreach my $song ( @{ $u->{playlist}->{songs} } ) {

	# Make a playlist with just this song.
	my $pls = Data::iRealPro::Playlist->new( song => $song );

	# Make an URI for this playlist.
	my $uri = Data::iRealPro::URI->new( playlist => $pls );

	# Write it out.
	my $title = $song->{title};
	# Mask dangerous characters.
	$title =~ s/[:?\\\/*"<>|]/@/g;
	my $file = $outdir.$title.".html";
	my $out = encode_utf8($file);
	open( my $fd, '>:utf8', $out )
	  or die( "$out: $!\n" );
	print $fd to_html($uri);
	close($fd);
	warn( "Wrote $out\n" )
	  if $self->{options}->{verbose};
    }
}

sub to_html {
    my ( $u ) = @_;

    my $pl = $u->{playlist};
    my $title;
    if ( $pl->{name} ) {
	$title = _html($pl->{name});
    }
    else {
	$title = _html($pl->{songs}->[0]->{title});
    }

    my $html = <<EOD;
<!DOCTYPE html>
<html>
  <head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <title>$title</title>
  <style type="text/css">
  body {
    color: rgb(230, 227, 218);
    background-color: rgb(27, 39, 48);
    font-family: Helvetica,Arial,sans-serif;
  }
  a         { text-decoration: none }
  a:active  { color: #b2e0ff }
  a:link    { color: #94d5ff }
  a:visited { color: #b2e0ff }
  .info {
    font-size: small;
    color: #999999;
  }
  </style>
</head>
<body>
  <h1>$title</h1>
EOD

    if ( $pl->{name} || @{ $pl->{songs} } > 1 ) {
	$html .= "  <p><a href=\"irealb://" . _esc($pl->as_string) .
	  "\" target=\"_blank\">(All songs)</a></p>\n  <ol>\n";
	foreach my $s ( @{ $pl->{songs} } ) {
	    my @c = split(' ', $s->{composer});
	    my $c = @c == 2 ? "$c[1] $c[0]" : $s->{composer};
	    $html .= "    <li><a href=\"irealb://" .
	      _esc($s->as_string) .
		"\" target=\"_blank\">" .
		  _html($s->{title}) .
		    "</a> - " .
		      _html($c) .
			( $s->{ts} ? " <span class=\"info\">(@{[$s->{ts}]})</span>" : "" ) .
			  "</li>\n";
	}

	$html .= "  </ol>\n";
    }
    else {
	$html .= qq{  <p><a href="@{[ _enc($u->as_string) ]}" target=\"_blank\">$title</a></p>\n};
    }

    $html .= <<EOD;
    <p class="info">Generated by <a href="https://metacpan.org/pod/Data::iRealPro" target="_blank">Data::iRealPro</a> version $Data::iRealPro::VERSION.</p>
</body>
</html>
EOD
}

sub _esc {
    # We must encode first before the uri-escape.
    my $t = encode_utf8($_[0]);
    $t =~ s/([^-_."A-Z0-9a-z*\/\'])/sprintf("%%%02X", ord($1))/ge;
    return $t;
}

sub _html {
    encode_entities($_[0]);
}

1;