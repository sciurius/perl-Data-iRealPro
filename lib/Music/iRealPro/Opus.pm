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
sub key { shift->_setget( "key", @_ ) }
sub style { shift->_setget( "style" ) }

sub set_style {
    my ( $self, $style ) = @_;
    $self->{style} = $style;
}

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

sub irealbook {
    my ( $self, %args ) = @_;

    my $type = delete( $args{type} ) // "html";
    my $variant = delete( $args{variant} ) // "irealbook";
    my $ir = '';

    my $maybecomma = sub {
	$ir .= "," if $ir =~ /[[:alnum:]]$/i;
    };

    my $sysbeats = 0;

    foreach my $section ( @{ $self->data->{sections} } )  {
	my $beatspermeasure = $section->{style}->{beats} // 4;
	my $beatstype = $section->{style}->{divider} // 4;

	$ir .= " " x (16 - $sysbeats) if $sysbeats;
	$sysbeats = 0;

	$ir .= "[" . timesig( $beatspermeasure, $beatstype );
	if ( $section->{name} ) {
	    $ir .= ( $_namemap{ $section->{name} }
	      //  "<*72" . $section->{name} . ">" );
	}

	my $beats = 0;
	foreach my $el ( @{ $section->{chords} } ) {
	    if ( $el->{is_a} eq "chord" ) {
		my $chord = $el;
		my $did = 0;
		for ( 1..$chord->{duration} ) {
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
			$ir .= $chord->{root};
			$ir .= _type( $chord->{type} );
			if ( $chord->{bass} ) {
			    $ir .= "/" . $chord->{bass};
			}
			$did++;
		    }
		    $beats++;
		    $sysbeats++;
		    $sysbeats = 0 if $sysbeats == 16;
		}
		next;
	    }
	    if ( $el->{is_a} eq "timesig" ) {
		( $beatspermeasure, $beatstype ) = @{ $el->{param} };
		$ir .= "|" unless $ir =~ /[|\[]$/;
		$maybecomma->();
		$ir .= timesig( $beatspermeasure, $beatstype );
		$beats = 0;
		next;
	    }
	    if ( $el->{is_a} eq "coda" ) {
		my $space = '';
		if ( $ir =~ /^(.*) $/ ) {
		    $ir = $1;
		    $space = ' ';
		}
		$maybecomma->();
		$ir .= "Q" . $space;
		next;
	    }
	    if ( $el->{is_a} eq "space" ) {
		my $space = $el->{param}->[0] // 16 - $sysbeats;
		if ( $ir =~ /^(.*)\|$/ ) {
		    $ir = $1;
		}
		$space = 0 if $space == 16;
		$ir .= "]" . ( " " x $space ) . "[";
		$sysbeats = 0;
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

    $ir =~ s/\]$/Z/;		# End bar

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

    return $uri->export( html => 1 );
}

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

use Music::ChordBot::Opus::Section;
use Music::ChordBot::Opus::Section::Chord;

my $_dur = 4;

no warnings 'redefine';

#### We need the is_a....

sub Music::ChordBot::Opus::Section::add_chord {
    my ( $self, $chord ) = @_;

    my $ok = 0;
    my $data;

    eval { $data = $chord->{data};
	   push( @{$self->{data}->{chords}},
		 $data ); $ok = 1 };
    return if $ok;

    shift;

    my $c = Music::ChordBot::Opus::Section::Chord->new(@_);
    if ( $c->duration ) {
	$_dur = $c->duration;
    }
    else {
	$c->duration( $_dur );
    }
    $data = $c->data;

    push( @{$self->{data}->{chords}}, $data );
}

use warnings 'redefine';

#### TODO: Use SongData for this

# Obfuscate...
# IN:  [T44C   |G   |C   |G   Z
# OUT: 1r34LbKcu7[T44CXyQ|GXyQ|CXyQ|GXyQZ
sub obfuscate {
    my ( $t ) = @_;
    for ( $t ) {
	s/   /XyQ/g;		# obfuscating substitution
	s/ \|/LZ/g;		# obfuscating substitution
	s/\| x/Kcl/g;		# obfuscating substitution
	$_ = hussle($_);	# hussle
	s/^/1r34LbKcu7/;	# add magix prefix
    }
    $t;
}

# Deobfuscate...
# IN:  1r34LbKcu7[T44CXyQ|GXyQ|CXyQ|GXyQZ
# OUT: [T44C   |G   |C   |G   Z
sub deobfuscate {
    my ( $t ) = @_;
    for ( $t ) {
	s/^1r34LbKcu7//;	# remove magix prefix
	$_ = hussle($_);	# hussle
	s/XyQ/   /g;		# obfuscating substitution
	s/LZ/ |/g;		# obfuscating substitution
	s/Kcl/| x/g;		# obfuscating substitution
    }
    $t;
}

# Symmetric husseling.
sub hussle {
    my ( $string ) = @_;
    my $result = '';

    while ( length($string) > 50 ) {

	# Treat 50-byte segments.
	my $segment = substr( $string, 0, 50, '' );
	if ( length($string) < 2 ) {
	    $result .= $segment;
	    next;
	}

	# Obfuscate a 50-byte segment.
	$result .= reverse( substr( $segment, 45,  5 ) ) .
		   substr( $segment,  5, 5 ) .
		   reverse( substr( $segment, 26, 14 ) ) .
		   substr( $segment, 24, 2 ) .
		   reverse( substr( $segment, 10, 14 ) ) .
		   substr( $segment, 40, 5 ) .
		   reverse( substr( $segment,  0,  5 ) );
    }

    return $result . $string;
}

sub irealb {
    my ( $self, %args ) = @_;

    $self->irealbook( variant => "irealpro", %args );
}

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
