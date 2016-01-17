#! perl

package Music::iRealPro::Opus;

use strict;
use warnings;
use 5.010;
use utf8;
use parent qw( Music::ChordBot::Opus );
use Music::iRealPro;
use Music::iRealPro::URI;
use Music::iRealPro::Playlist;
use Music::iRealPro::SongData;

use Carp qw( croak );

=head2 composer I<title>

Sets the composer name for the song.

=cut

sub composer { shift->_setget( "composer", @_ ) }

=head2 key I<key>

Sets the key signature for the song.

=cut

sub key { shift->_setget( "key", @_ ) }

=head2 style I<name>

Sets the style for the song.

iRealPro songs have a single style but the styles have builtin
variants per section (Intro, A, B, C, D, and Coda).

=cut

sub style { shift->_setget( "style" ) }

################ Output Generation ################

# Map section names to internal codes.

my %_namemap = (
		Verse	 => '*v',
		Intro	 => '*i',
		Coda	 => 'Q',
		Segno	 => 'S',
		Fermata	 => 'f',
		A	 => '*A',
		B	 => '*B',
		C	 => '*C',
		D	 => '*D',
);

=head2 irealb I<args>

Produces the song in iRealPro (iReal-B) format.

The I<args> are key/value pairs.

=over 4

=item variant

Determines which format is wanted for the generated song. Values are
B<irealbook> and B<irealpro> (default).

=item type

Determines the format of the generated song. Values are B<html>
(default) and B<text>.

=back

=cut

sub irealb {
    my ( $self, %args ) = @_;

    $self->irealbook( variant => "irealpro", %args );
}

=head2 irealbook I<args>

Produces the song in iRealBook format.

The I<args> are the same as for irealb(), but I<variant> defaults to
B<irealbook>.

=cut

sub irealbook {
    my ( $self, %args ) = @_;

    my $type    = delete( $args{type}    ) // "html";
    my $variant = delete( $args{variant} ) // "irealbook";
    my $ir = '';

    my $maybecomma = sub {
	$ir .= "," if $ir =~ /[[:alnum:]]$/i;
    };

    my $sysbeats = 0;
    my $p_timesig = "";

    foreach my $section ( $self->sections )  {

	my $beatspermeasure = $section->style->beats // 4;
	my $beatstype = $section->style->divider // 4;

	$ir .= " " x (16 - $sysbeats) if $sysbeats;
	$sysbeats = 0;

	$ir .= "[";
	my $t = timesig( $beatspermeasure, $beatstype );
	if ( $t ne $p_timesig ) {
	    $ir .= $t;
	    $p_timesig = $t;
	}

	if ( $section->name ) {
	    $ir .= ( $_namemap{ $section->name }
	      //  "<*72" . $section->name . ">" );
	}

	my $beats = 0;
	foreach my $el ( @{ $section->chords } ) {
	    if ( $el->is_a eq "chord" ) {
		my $chord = $el;
		my $did = 0;
		for ( 1..$chord->duration ) {
		    if ( $beats == $beatspermeasure ) {
			$beats = 0;
			$ir .= "|";
			$did = 0;
		    }
		    if ( $did ) {
			$ir .= " ";
		    }
		    else {
			$maybecomma->();
			if ( $chord->type eq "Silence" ) {
			    $ir .= "n";
			}
			else {
			    $ir .= $chord->root;
			    $ir .= _type( $chord->type );
			    if ( $chord->bass ) {
				$ir .= "/" . $chord->bass;
			    }
			}
			$did++;
		    }
		    $beats++;
		    $sysbeats++;
		    $sysbeats = 0 if $sysbeats == 16;
		}
		next;
	    }
	    if ( $el->is_a eq "timesig" ) {
		( $beatspermeasure, $beatstype ) = $el->params;
		$ir .= "|" unless $ir =~ /[|\[]$/;
		$maybecomma->();
		$ir .= timesig( $beatspermeasure, $beatstype );
		$beats = 0;
		next;
	    }
	    if ( $el->is_a eq "coda" ) {
		#### TODO: jump must be in last cell
		#### TODO: position must precede chord
		my $space = '';
		if ( $ir =~ /^(.*) $/ ) {
		    $ir = $1;
		    $space = ' ';
		}
		$maybecomma->();
		$ir .= "Q" . $space;
		next;
	    }
	    if ( $el->is_a eq "segno" ) {
		#### TODO: Must precede chord
		$maybecomma->();
		$ir .= "S";
		next;
	    }
	    if ( $el->is_a =~ /^D\.S\. al (Coda|Fine)$/ ) {
		#### TODO: Must precede chord
		$ir .= "<*66D.S. al $1>";
		next;
	    }
	    if ( $el->is_a eq "repeat" ) {
		$ir =~ s/[|\[]$//;
		$ir .= "{";
		next;
	    }
	    if ( $el->is_a eq "end repeat" ) {
		$ir =~ s/[|\]]$//;
		$ir .= "}";
		next;
	    }
	    if ( $el->is_a =~ /^ending (\d+)/ ) {
		$ir .= "|N$1";
		$beats = 0;
		next;
	    }
	    if ( $el->is_a eq "space" ) {
		my $space = $el->params->[0] // 16 - $sysbeats;
		if ( $ir =~ /^(.*)\|$/ ) {
		    $ir = $1;
		}
		$space = 0 if $space == 16;
		$ir .= " " x $space;
		$sysbeats = $space;
		next;
	    }
	}
	if ( $ir =~ /^(.*)\[$/ ) {
	    $ir = $1;
	}
	else {
	    $ir .= "]";
	}
    }

    $ir =~ s/\]$/Z /;		# End bar

    # Aestethics.
    $ir =~ s/\[\{/{/g;
    $ir =~ s/\}\]/}/g;

    my $song = Music::iRealPro::SongData->new
      ( variant	     => $variant,
	title	     => $self->name,
	composer     => $self->composer || "Composer",
	style	     => $self->style    || "Rock Ballad",
	key	     => $self->key      || "C",
	actual_tempo => $self->tempo    || "0",
     );
    $song->{data} = $ir;

    my $uri = Music::iRealPro::URI->new
      ( variant  => $variant,
	playlist =>
	Music::iRealPro::Playlist->new
	( variant => $variant,
	 songs    => [ $song ],
	)
      );

    return $uri->export( $type => 1 );
}

=head2 html

Produces output in the form of a small HTML document that can be
imported into iRealPro.

=cut

sub html {
    my ( $self, %args ) = @_;
    $self->irealbook( variant => "irealpro", type => "html", %args );
}

################ Helper routines ################

sub timesig {
    my ( $beatspermeasure, $beatstype ) = @_;

    # Invalid time sigs will crash iRealPro in a nasty way.
    croak("Invalid time signature $beatspermeasure/$beatstype")
      unless ( $beatstype == 2 && $beatspermeasure >= 2 && $beatspermeasure <= 3 )
	|| ( $beatstype == 4 && $beatspermeasure >= 2 && $beatspermeasure <= 7 )
	|| ( $beatstype == 8 && ( $beatspermeasure == 6
				  || $beatspermeasure == 7
				  || $beatspermeasure == 9
				  || $beatspermeasure == 12 ) );

    my $r = "T" . $beatspermeasure . $beatstype;
    $r =~ s/T128$/T12/;	# 12/8 -> T12
    return $r;
}

# Map chord types WORK IN PROGRESS -- INCOMPLETE AND FAULTY

my %types = ( "Maj"	  => "",
	      "Min"	  => "-",
	      "7"	  => "7",
	      "Min7"	  => "-7",
	      "Maj7"	  => "^7",
	      ""	  => "7sus",
	      ""	  => "ø7",
	      "Dim7"	  => "o7",
	      ""	  => "5",
	      ""	  => "2",
	      ""	  => "add9",
	      "Aug"	  => "+",
	      "Dim"	  => "o",
#	      "Min7(b5)"  => "o7",
	      "Min7(b5)"  => "h7",
	      ""	  => "ø",
	      "Sus"	  => "sus",
	      "Sus4"	  => "sus",
	      ""	  => "^",
	      ""	  => "-",
	      ""	  => "^9",
	      ""	  => "^13",
	      "6"	  => "6",
	      "69"	  => "69",
	      ""	  => "^7#11",
	      ""	  => "^9#11",
	      ""	  => "^7#5",
	      "Min6"	  => "-6",
	      "Min69"	  => "-69",
	      ""	  => "-b6",
	      ""	  => "-^7",
	      ""	  => "-^9",
	      "Min9"	  => "-9",
	      "Min11"	  => "-11",
	      ""	  => "ø9",
	      ""	  => "-7b5",
	      "9"	  => "9",
	      ""	  => "7b9",
	      ""	  => "7#9",
	      ""	  => "7#11",
	      ""	  => "9#11",
	      ""	  => "9#5",
	      ""	  => "9b5",
	      "7(b5)"	  => "7b5",
	      ""	  => "7#5",
	      ""	  => "7b13",
	      ""	  => "7#9#5",
	      ""	  => "7#9b5",
	      ""	  => "7#9#11",
	      ""	  => "7b9#11",
	      ""	  => "7b9b5",
	      ""	  => "7b9#5",
	      ""	  => "7b9#9",
	      ""	  => "7b9b13",
	      ""	  => "7alt",
	      "13"	  => "13",
	      ""	  => "13#11",
	      ""	  => "13#9",
	      ""	  => "13b9",
	      ""	  => "7b9sus",
	      ""	  => "7susadd3",
	      ""	  => "9sus",
	      ""	  => "13sus",
	      ""	  => "7b13sus",
	      "11"	  => "11",

	    );

sub _type {
    $types{ shift() } // "";
}

1;
