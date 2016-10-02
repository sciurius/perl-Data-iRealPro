#! perl

# Data::iRealPro::Text -- parse iRealPro data and produce editable text

# Author          : Johan Vromans
# Created On      : Tue Sep  6 14:58:26 2016
# Last Modified By: Johan Vromans
# Last Modified On: Sun Oct  2 21:20:27 2016
# Update Count    : 63
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Text;

our $VERSION = "0.01";

use Data::iRealPro::URI;
use Data::iRealPro::Playlist;
use Data::iRealPro::Song;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant transpose select list ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub process {
    my ( $self, $u, $options ) = @_;

    $self->{output} ||= "__new__.txt";

    my $pl;
    my $list = $self->{list};
    my $select = $self->{select};

    if ( defined $u->{playlist}->{name} ) {
	$pl = $u->{playlist}->{name} || "<NoName>";
    }

    my $song = 0;
    my @songs;

    foreach my $s ( @{ $u->{playlist}->{songs} } ) {
	$song++;
	my @t = split( ' ', $s->{composer} );
	@t[0,1] = @t[1,0] if @t == 2;
	push( @songs,
	      { index => $song,
		title =>
		$list
		?
		  sprintf("%4d: %s (%s)", $song, $s->{title}, "@t" )
		:
		  join( "",
			( $song > 1 || $pl ) ? "Song $song: " : "Song: ",
			$s->{title},
			" (@t)" ),
		subtitle =>
		  join( "",
			"Style: ", $s->{style},
			$s->{actual_style}
			? ( " (", $s->{actual_style}, ")" ) : (),
			$s->{key} ? ( "; key: ", $s->{key} ) : (),
			$s->{actual_tempo}
			? ( "; tempo: ", $s->{actual_tempo} ) : (),
			$s->{actual_repeats}
			? ( "; repeat: ", $s->{actual_repeats} ) : (),
		      ),
		cooked => neatify( $s->{data} ),
	      } );
    }

    if ( $self->{output} eq "-" ) {
	binmode( STDOUT, ':utf8' );
    }
    else {
	open( my $fd, ">:utf8", $self->{output} )
	  or die( "Cannot create ", $self->{output}, " [$!]\n" );
	select($fd);
    }

    my $res;
    print( "Playlist: $pl\n" ) if $list && $pl;
    foreach my $song ( @songs ) {
	$res = $song->{title} . "\n";
	if ( $list ) {
	    print($res);
	    next;
	}
	if ( $select && $song->{index} != $select ) {
	    next;
	}
	$res .= $song->{subtitle} . "\n";
	$res .= "Playlist: " . $pl . "\n" if $pl;
	$res .= "\n";
	$res .= $song->{cooked} . "\n";
	print( $res, "\n" );
    }

    close;
}

sub neatify {
    my ( $t ) = @_;
    my @a = split( /(\<.*?\>)/, $t );
    $t = "";
    while ( @a > 1 ) {
	$t .= neatify1(shift(@a));
	$t .= shift(@a);
    }
    $t .= neatify1(shift(@a)) if @a;
    return $t;
}

sub neatify1 {
    my ( $t ) = @_;
    # Insert spaces and newlines at tactical places to obtain
    # something readable and editable.
    $t =~ s/ / _ /g;
    while ( $t =~ s/_ +_/__/g ) {}
    $t =~ s/([\]\}])/$1\n/g;
    $t =~ s/([\[\{])/\n$1/g;
    $t =~ s/([\[\{])(\*[ABCDVi])/$1$2 /gi;
    $t =~ s/\n\n+/\n/g;
    $t =~ s/^\n+//;
    $t =~ s/^ +_/_/mg;
    $t =~ s/_ +$/_/mg;
    $t =~ s/\n+$/\n/;

    return $t;
}

sub yfitaen {
    my ( $t ) = @_;
    my @a = split( /(\<.*?\>)/, $t );
    $t = "";
    while ( @a > 1 ) {
	$t .= yfitaen1(shift(@a)) . shift(@a);
    }
    $t .= yfitaen1(shift(@a)) if @a;
    return $t;
}

sub yfitaen1 {
    my ( $t ) = @_;
    # Indeed, the reverse of neatify. And a bit easier.
    $t =~ s/\s+//g;
    $t =~ s/_/ /g;
    return $t;
}

sub encode {
    my ( $self, $data ) = @_;
    my $variant = "irealpro";

    my $plname;
    if ( $data =~ /^Playlist:\s*(.*)/m ) {
	$plname = $1 unless $1 eq "<NoName>";
    }

    my @songs;
    while ( $data =~ /\A(Song(?: (\d+))?:.*?)^(Song(?: \d+)?:.*)/ms ) {
	warn("Expecting song ", 1+@songs, " but got $2\n")
	  unless $2 == 1 + @songs;
	push( @songs, $self->encode_song($1) );
	$data = $3;
    }
    if ( $data =~ /^Song(?: (\d+))?:.*/ ) {
	warn("Expecting song number ", 1+@songs, " but got number $1\n")
	  if $1 && $1 != 1 + @songs;
	push( @songs, $self->encode_song($data) );
    }

    # Build a playlist for the songs...
    my $pl = Data::iRealPro::Playlist->new
      ( variant      => $variant,
	songs        => \@songs,
	$plname ? ( name => $plname ) : (),
      );

    # Build a URI for the playlist...
    my $uri = Data::iRealPro::URI->new
      ( variant      => $variant,
	playlist     => $pl,
      );

    # And deliver.
    return $uri;
}

sub encode_song {
    my ( $self, $data ) = @_;
    my $tv = {};
    my $variant = "irealpro";

    if ( $data =~ /^Playlist:\s*(.*)/m ) {
	$tv->{pl_name} = $1 unless $1 eq "<NoName>";
    }

    if ( $data =~ /^Song(?:\s+\d+)?:\s+(.*?)\s+\((.*?)\)/m ) {
	$tv->{title} = $1;
	my @t = split( ' ', $2 );
	@t[0,1] = @t[1,0] if @t == 2;
	$tv->{composer} = "@t";
    }

    if ( $data =~ /Style:\s+([^;(\n]*)(?:\s+\(([^)\n]+)\))?(?:;|$)/m ) {
	$tv->{style} = $1;
	$tv->{actual_style} = $2;
    }

    if ( $data =~ /; key:\s+([^;\n]+)/ ) {
	$tv->{key} = $1;
    }

    if ( $data =~ /; tempo:\s+(\d+)/ ) {
	$tv->{actual_tempo} = $1;
    }
    if ( $data =~ /; repeats?:\s+(\d+)/ ) {
	$tv->{actual_repeats} = $1;
    }

    $data =~ s/^.*?\n\n//s;

    # Build the song...
    my $song = Data::iRealPro::Song->new
      ( variant	       => $variant,
	title	       => $tv->{title},
	composer       => $tv->{composer}       || "Composer",
	style	       => $tv->{style}          || "Rock Ballad",
	key	       => $tv->{key}            || "C",
	actual_tempo   => $tv->{actual_tempo}   || "0",
	actual_style   => $tv->{actual_style}   || "",
	actual_repeats => $tv->{actual_repeats} || "",
     );
    $song->{data} = yfitaen($data);

    # And deliver.
    return $song;
}

1;
