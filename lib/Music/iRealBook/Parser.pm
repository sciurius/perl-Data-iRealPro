#! perl

use strict;
use warnings;
use Carp;
use utf8;

package Music::iRealBook::Parser;

our $VERSION = "0.01";

use Music::iRealBook::Tokenizer;
use Data::Dumper;

sub new {
    my ( $pkg, %args ) = @_;
    bless { %args }, $pkg;
}

sub decode {
    my ( $self, $url ) = @_;
    my $debug = $self->{debug};
    $url =~ s/\n$//;

    if ( $url =~ m;^irealb(ook)?://(.*); ) {
	Carp::croak("Only irealbook format allowed")
	    if defined $1;
	$url = $2;
    }

    if ( $url =~ /%[0-9a-f]{2}/i ) { # assume uri-encoded
	$url =~ s/%([0-9a-f]{2})/sprintf("%c",hex($1))/gie;
    }

    warn( "STRING: >>", $url, "<<\n" ) if $debug;
    my $res;

    unless ( $url =~ /^(.*?)=(.*?)=(.*?)=(.*?)=(.*?)=(.*)/ ) {
	Carp::croak("Incorrect format 1");
    }

    $res->{title} = $1;
    $res->{composer} = $2;
    $res->{style} = $3;
    $res->{n} = $4;
    $res->{key} = $5;

    for ( values %$res ) {
	s/'/’/g;
    }

    my $tokens = Music::iRealBook::Tokenizer->new->tokenize($6);
    $res->{sections} = [];

    my $section = { tokens => [] };

    my $measures = 0;
    my $allmeasures = 0;
    my $newbar = 0;
    my $i = -1;
    my $i0 = 0;
    my $pbar = -1;
    foreach my $t ( @$tokens ) {
	$i++;

	if ( $t eq "end section" ) {
	    push( @{ $section->{tokens} }, $t );
	    $section->{measures} = $measures;
	    $allmeasures += $measures;
	    $measures = 0;
	    push( @{ $res->{sections} }, { %$section } );
	    printf STDERR "> %3d %3d %2d %d $t\n", $i, $i-$i0, $measures, $newbar;
	    $section = { tokens => [] };
	    $i0 = $i + 1;
	    $pbar = -1;
	    $newbar = 0;
	    next;
	}

	if ( $newbar == 0 && $t =~ /^(measure)/ ) {
	    $measures++;
	    $newbar++;
	    $t .= " " . $pbar;
	}
	if ( $newbar == 0 && $t =~ /^(chord|measure|rest)/ ) {
	    $measures++;
	    $newbar++;
	    $pbar = $i - $i0;
	}
	if ( $t =~ /^(bar|end)/ ) {
	    $newbar = 0;
	}
	if ( $t =~ /^mark\s+(.*)/ ) {
	    $section->{title} = $1;
	}
	push( @{ $section->{tokens} }, $t );
	printf STDERR "> %3d %3d %2d %d $t\n", $i, $i-$i0, $measures, $newbar;
    }
    if ( @{ $section->{tokens} } ) {
	$section->{measures} = $measures;
	$allmeasures += $measures;
	push( @{ $res->{sections} }, { %$section } );
    }

    $res->{measures} = $allmeasures;
    $self->{song} = $res;
    warn( Dumper( $res ) ) if $debug;
}

sub lilypond {
    my ( $self ) = @_;
    my $song = $self->{song} || Carp::croak("No song?");

    open( my $fd, '>&STDOUT' );
    binmode( $fd, ':utf8' );
    my $time_d;
    my $time_n;
    my $time = "1/1";
SLOOP:
    foreach ( @{ $song->{sections} } ) {
	foreach ( @{ $_->{tokens} } ) {
	    next unless /time (\d\/\d)/;
	    $time = $1;
	    last SLOOP;
	}
    }
    ( $time_d, $time_n ) = $time =~ m;^(\d+)/(\d+)$;;

    $fd->print(<<EOD);
%! lilypond

\\version "2.18.2"

\\header {
  title = "@{[ $song->{title} ]}"
  subtitle = "@{[ $song->{style} ]}"
  composer = "@{[ $song->{composer} ]}"
  tagline = \\markup {
    \\tiny "Converted from iRealBook by App::Music::iRealPro $VERSION"
  }
}

% Paper size. A4, no headings, no indent.
\\paper {
  #(set-paper-size "a4")
  left-margin = 20\\mm
  line-width = 170\\mm
  ragged-last-bottom = ##t
  indent = 0\\mm
}

myStaffSize = #18
#(set-global-staff-size 18)

global = {
  \\key @{[ $self->key2lp( $song->{key} ) ]}
  \\time $time
  \\tempo 4 = 120   % dummy; no info from iRealBook
}

harmonics = \\chordmode {

EOD
    my $measures = [];

  foreach my $section ( @{ $song->{sections} } ) {

    my $song = $section->{tokens};
    my $pdur = 0;
    my $inline = 0;
    my $inalt = 0;
    my $inrepeat = 0;

    $fd->print("%% Section: ", $section->{title}, "\n");
    my $mark = $section->{title};

    for ( my $i = 0; $i < @$song; $i++ ) {
	my $s = $song->[$i];
	if ( $s =~ /^chord\s+(\S+)\s+(\d+)/ ) {
	    my $dur = $2;
	    if ( $time_d == 4 ) {
		if ( $dur == 1 ) {
		    $dur = "4";
		}
		elsif ( $dur == 2 ) {
		    $dur = "2";
		}
		elsif ( $dur == 3 ) {
		    $dur = "2.";
		}
		elsif ( $dur == 4 ) {
		    $dur = "1";
		}
	    }
	    my $chord = $self->chord2lp($1, $dur == $pdur ? 0 : $dur );
	    $fd->print("  | ") unless $inline++;
	    $fd->print("\\mark\\markup{\\box $mark} ") if $mark;
	    $mark = "";
	    $fd->print($chord, "  ");
	    $pdur = $dur;
	}
	elsif ( $s =~ /^bar$/ ) {
	    $fd->print("|\n");
	    $inline = 0;
	    push( @$measures, [ $time_d, $time_n ] );
	}
	elsif ( $s =~ /^end$/ ) {
	    $fd->print("  }\n") if $inrepeat;
	    $inrepeat = 0;
	    $fd->print("  }\n  }\n") if $inalt;
	    $fd->print("\\bar \"|.\"\n");
	    $inline = 0;
	    push( @$measures, [ $time_d, $time_n ] );
	}
	elsif ( $s =~ /^mark (.*)$/ ) {
	    next;
	    $fd->print("|\n") if $inline;
	    $fd->print("  }\n"), $inrepeat = 0 if $inrepeat > 1;
            $fd->print("  }\n  }\n") if $inalt;
            $inalt = 0;
	    $fd->print("%% Section: ", $1, "\n");
	    $inline = 0;
	    $inrepeat++ if $inrepeat;
	}
	elsif ( $s =~ /^start repeat$/ ) {

	    my $volta = 2;
            for ( my $j = $i+1; $j < @$song; $j++ ) {
		my $t = $song->[$j];
		last if $t eq "start repeat";
		$volta = $1 if $t =~ /^alternative (\d+)/;
	    }
	    $fd->print( "  \\repeat volta $volta {\n" );
	    $inrepeat = 1;
	}
	elsif ( $s =~ /^alternative (\d)$/ ) {
	    $fd->print("|\n") if $inline;
	    $fd->print("  }\n") if $inrepeat;
	    $inrepeat = 0;
	    $fd->print("  \\alternative {\n") unless $inalt;
	    $fd->print("  }\n") if $inalt;
	    $fd->print("  {\n");
	    $inline = 0;
            $inalt = 1;
	}
	elsif ( $s =~ /^measure repeat (\d+)/ ) {
	    my $t = $1;
	    $song->[$i] = 'noop';
	    $song->[$i+1] = 'noop' if $song->[$i+1] eq 'bar';
	    $i = $t - 1;
	}
	elsif ( $s =~ /^end section/ ) {
	    $fd->print("  \\bar \"||\"\n" );
	    push( @$measures, [ $time_d, $time_n ] );
	}
	elsif ( $s =~ /^time\s+(\S+)/ ) {
	    if ( $1 ne $time ) {
		$time = $1;
		( $time_d, $time_n ) = $time =~ m;^(\d+)/(\d+)$;;
		$fd->print("  \\time $time\n" );
	    }
	}
    }
    $fd->print("\n") if $inline;
    $fd->print("  }\n  }\n") if $inalt;
  }
    $fd->print(<<EOD) if 1;

}

% Create metronome ticks.
ticktock = \\drummode {
EOD

    ( $time_d, $time_n ) = ( 0, 0 );
    foreach ( @$measures ) {
	if ( $_->[0] != $time_d || $_->[1] != $time_n ) {
	    ( $time_d, $time_n ) = @$_;
	    $fd->print( "  \\time $time_d/$time_n\n" );
	}
	$fd->print( "  hiwoodblock $time_n",
		    ( " lowoodblock" ) x ( $time_d - 1 ),
		    " |\n" );
    }

    $fd->print(<<EOD) if 1;
}

% Create silent track.
highMusic = {
EOD

    ( $time_d, $time_n ) = ( 0, 0 );
    foreach ( @$measures ) {
	if ( $_->[0] != $time_d || $_->[1] != $time_n ) {
	    ( $time_d, $time_n ) = @$_;
	    $fd->print( "  \\time $time_d/$time_n\n" );
	}
	$fd->print( "  s1 * $time_d/$time_n |\n" );
    }

    $fd->print(<<EOD) if 1;
}

allMusic = {
  \\new ChoirStaff
  <<
    \\new ChordNames {
      \\set midiInstrument = "percussive organ"
      \\set midiMaximumVolume = #0.3
      \\set chordChanges = ##f
      \\set additionalPitchPrefix = "add"
      \\global
      \\harmonics
    }
    \\new Staff = High {
       \\new Voice {
	 \\set Staff.midiInstrument = "acoustic grand"
	 \\global
	 \\highMusic
       }
    }
    \\tag #'midiOnly \\new DrumStaff = TickTock {
      \\new DrumVoice {
	\\set DrumStaff.midiMaximumVolume = #0.3
	\\global
	\\ticktock
      }
    }
  >>
}

%% Generate the printed score.
\\score {
  \\removeWithTag #'midiOnly \\allMusic
  \\layout {
    \\context {
      \\Score
      \\omit BarNumber
      \\remove "Metronome_mark_engraver"
    }
    \\context {
      \\Staff
      \\override TimeSignature #'style = #'()
    }
  }
}

%% Generate the MIDI.
\\score {
  \\removeWithTag #'scoreOnly \\unfoldRepeats \\allMusic
  \\midi { }
}

EOD

}

sub key2lp {
    my ( $self, $key ) = @_;

    unless ( $key =~ /^([ABCDEFGW])([b#])?([-m^o])?$/ ) {
	Carp::croak("Invalid key: $key");
    }

    my ( $root, $shfl, $min ) = ( $1, $2, $3 );

    $root = lc($root);
    if ( $shfl ) {
	$root .= $shfl eq 'b' ? "es" : "is";
    }
    $root .= $min ? " \\minor" : " \\major";

    return $root;

}

sub chord2lp {
    my ( $self, $chord, $dur ) = @_;

    unless ( $chord =~ /^([ABCDEFGW])([b\#]?)([-m^o]?)(.*)$/ ) {
	Carp::croak("Invalid chord key: $chord");
    }

    my ( $root, $shfl, $min, $mod ) = ( $1, $2, $3, $4 );

    $root = lc($root);
    if ( $shfl ) {
	$root .= $shfl eq 'b' ? "es" : "is";
    }
    $root .= $dur if $dur;
    $root .= ":";

    $root .= $min eq "-" ? "m"
	     : $min eq "^" ? "maj"
	       : $min eq "o" ? "dim"
		 : "";

    while ( $mod =~ s/([2345679])//g ) {
	$root .= $1 . ".";
    }

    $root =~ s/[:.]+$//;
    return $root;

}

sub timesig {
    my ( $self, $time_d, $time_n ) = @_;
    my $sigs = { "22" => "2/2",
		 "32" => "3/2",
		 "24" => "2/4",
		 "34" => "3/4",
		 "44" => "4/4",
		 "54" => "5/4",
		 "64" => "6/4",
		 "74" => "7/4",
		 "68" => "6/8",
		 "78" => "7/8",
		 "98" => "9/8",
		 "12" => "12/8",
	       };

    $sigs->{ "$time_d$time_n" } || Carp::croak("Invalid time signature: $time_d/$time_n");
}

package main;

unless ( caller ) {
    my $d = Music::iRealBook::Parser->new( debug => 1 );

=for later

    my $res = $d->decode( <<'EOD' );
Ain't She Sweet XXX=Ager Milton=Medium Up Swing=n=Eb={*AT44Eb6 A9 |Bb7   |Eb6 A9 |Bb7   |Eb6 G7 |C7   |F7 Bb7 |N1Eb6 Bb7, }            |N2Eb7   ][*BAb7   | x  |Eb6   |Eb7   |Ab7   | x  |Eb6   |F-7 Bb7 ][*AEb6 A9 |Bb7   |Eb6 A9 |Bb7   |Eb G7 |C7   |F7 Bb7 |sEb,Ab7,lEb Z 
EOD

    my $res = $d->decode( <<'EOD' );
All Of Me=Marks Gerald=Medium Swing=n=C=*A[T44C^7   | x  |E7   | x  |A7   | x  |D-7   | x  ]*B[E7   | x  |A-7   | x  |D7   | x  |D-7   |G7   ]*A[C^7   | x  |E7   | x  |A7   | x  |D-7   | x  ]*C[F^7   |F-6(F#o7)   |E-7(C^7/G)   |A7   |D-7   |G7   |C6 Ebo7 |D-7 G7 Z
EOD

    my $res = $d->decode( <<'EOD' );
Bossa 3=Exercise=Bossa Nova=n=D-=[*AT44D- |D-7/C |E7b9/B |x |Eh7/Bb |A7b9 |D- |sEh,A7,|lD- |sBh,E7,|lA- |x |Bb^7 |x |Eh7 |A7b9 ][*BD- |D-7/C |E7b9/B |x |Eh7/Bb |A7b9 |D- |D7b9 |G- |A7b9 |D- |D-7/C |E7b9/B |A7b9 |D- |sE-7,A7,]Y[*ClD^7 |B7/D# |E-7 |x |A7sus |A7 |Do7 |D^7 |F#-7 |Fo7 |E-7 |x |E7 |x |Eh7 |A7 ][*DD^7 |B-7 |E7 |x |F#7 |x |sB-7,Bb-7,|A-7,D7,|lG^7 |G-7 |F#-7 |B7 |E7 |A7 |F#-7 |B7 |E7 |A7 |D6 |A7 Z 
EOD
    $d->lilypond;

=cut

    my $res = $d->decode( <<'EOD' );
A015: Venice - The Family Tree=Lennons=Rock Ballad=n=D=[T44*iD, F#-, |G, F#-, |G, F#-, |A, D, ][T44*AD, F#-, |G, D, |G, D, |E, A, |D, F#-, |G, D, |G, D, |A, D, ][T24*CD, |T44B-, A, |G, D, |G, D, |E, A, |B-, A, |G, D, |E-, A, |T24B-, |T44B-/A,   |E-, A, ][T44*DD, F#-, |G, F#-, |G, F#-, |A, D, |D,   Z
EOD

    $d->lilypond;
}
1;
