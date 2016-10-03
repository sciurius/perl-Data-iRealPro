#! perl

# Data::iRealPro::Output::Text -- produce editable text

# Author          : Johan Vromans
# Created On      : Tue Sep  6 14:58:26 2016
# Last Modified By: Johan Vromans
# Last Modified On: Mon Oct  3 08:37:52 2016
# Update Count    : 68
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Output::Text;

use parent qw( Data::iRealPro::Output::Base );

our $VERSION = "0.01";

use Data::iRealPro::URI;
use Data::iRealPro::Playlist;
use Data::iRealPro::Song;

sub options {
    my $self = shift;
    [ @{ $self->SUPER::options }, qw( select list ) ];
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

1;
