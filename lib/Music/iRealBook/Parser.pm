#! perl

use strict;
use warnings;
use Carp;

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
    $res->{tokens} = Music::iRealBook::Tokenizer->new->tokenize($6);
    for ( $res->{measures} ) {
	my $newbar = $_ = 0;
	my $i = -1;
	my $pbar = -1;
	foreach my $t ( @{ $res->{tokens} } ) {
	    $i++;
	    if ( $newbar == 0 && $t =~ /^(measure)/ ) {
		$_++;
		$newbar++;
		$t .= " " . $pbar;
	    }
	    if ( $newbar == 0 && $t =~ /^(chord|measure|rest)/ ) {
		$_++;
		$newbar++;
		$pbar = $i;
	    }
	    if ( $t =~ /^(bar|end)/ ) {
		$newbar = 0;
	    }
	    printf STDERR "> %3d %2d %d $t\n", $i, $_, $newbar;
	}
    }
    $self->{song} = $res;
    warn( Dumper( $res ) ) if $debug;
}

sub lilypond {
    my ( $self ) = @_;
    my $song = $self->{song} || Carp::croak("No song?");

    open( my $fd, '>&STDOUT' );
    my $time_d = 4;
    my $time_n = 4;
    my $time = $self->timesig( $time_d, $time_n );
    foreach ( @{ $song->{song} } ) {
	next unless /time_(\d)_(\d)/;
	$time = $self->timesig( $1, $2 );
	( $time_d, $time_n ) = $time =~ m;^(\d+)/(\d+)$;;
	last;
    }

    $fd->print(<<EOD);
%! lilypond

\\version "2.18.2"

\\header {
  title = "@{[ $song->{title} ]}"
  subtitle = "@{[ $song->{style} ]}"
  composer = "@{[ $song->{composer} ]}"
  tagline = \\markup {
    \\tiny "Converted from iRealBook by Johan vromans <jvromans\@squirrel.nl>"
  }
}

% Paper size. A4, no headings, no indent.
\\include "a4paper-nh.ily"

% Define the voice names.
\\include "voicenames.ily"

% Staff size. Currently supported are 14 15 16 17 18 19 20.
\\include "staff18.ly"

% Use a sans font for the lyrics.
\\include "lyricssans.ly"

% Use popular notation for chords.
\\include "popchords.ly"

% Helper modules.
\\include "ifdefined.ly"
\\include "makeunfold.ly"

global = {
  \\key @{[ $self->key2lp( $song->{key} ) ]}
  \\time $time
  \\tempo 4 = 120   % dummy; no info from iRealBook
}

harmonics = \\chordmode {

EOD
    my $measures = $song->{measures};
    $song = $song->{tokens};
    my $pdur = 0;
    my $inline = 0;
    my $inalt = 0;
    my $inrepeat = 0;

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
	    $fd->print($chord, "  ");
	    $pdur = $dur;
	}
	elsif ( $s =~ /^bar$/ ) {
	    $fd->print("|\n");
	    $inline = 0;
	}
	elsif ( $s =~ /^end$/ ) {
	    $fd->print("  }\n") if $inrepeat;
	    $inrepeat = 0;
	    $fd->print("  }\n  }\n") if $inalt;
	    $fd->print("\\bar \"|.\"\n");
	    $inline = 0;
	}
	elsif ( $s =~ /^mark (.*)$/ ) {
	    $fd->print("|\n") if $inline;
	    $fd->print("  }\n"), $inrepeat = 0 if $inrepeat > 1;
            $fd->print("  }\n  }\n") if $inalt;
            $inalt = 0;
	    $fd->print("%% Section: ", $1, "\n");
	    $inline = 0;
	    $inrepeat++ if $inrepeat;
	}
	elsif ( $s =~ /^start repeat$/ ) {
	    $fd->print( "  \\repeat volta 2 {\n" );
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
	}
    }

    $fd->print(<<EOD) if 1;

}

% Create metronome ticks.
ticktock = \\drummode {
  \\makeUnfold \\unfoldRepeats \\removeWithTag #'scoreOnly \\harmonics {
    hiwoodblock $time_d @{[ ( "lowoodblock" ) x ( $time_n - 1 ) ]}
  }
}

highMusic = { s1 * @{[ $measures ]} }

allMusic = {
  \\new ChoirStaff
  <<
    \\include  "chordstaff.ily"
    #(define-public thisStaff "high")   \\include "genericstaff.ily"
    \\tag #'midiOnly \\include "ticktock.ily"
  >>
}

%% Generate the printed score.
\\score {
  \\removeWithTag #'midiOnly \\allMusic
  \\layout {
    \\context {
      % To remove empty staffs:
      % \\RemoveEmptyStaffContext 
      % To use the setting globally, uncomment the following line:
      % \\override VerticalAxisGroup #'remove-first = ##t
    }
    \\context {
      \\Score
      \\omit BarNumber
      \\remove "Metronome_mark_engraver"
    }
    \\context {
      \\Staff
      \\override TimeSignature #'style = #'()
      %\\remove "Time_signature_engraver"
    }
  }
}

%% Generate the MIDI.
\\score {
  \\removeWithTag #'scoreOnly \\unfoldRepeats \\allMusic
  \\midi {
  }
}

EOD

}

sub key2lp {
    my ( $self, $key ) = @_;

    unless ( $key =~ /^([ABCDEFG])([b#])?([-m])?$/ ) {
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

    unless ( $chord =~ /^([ABCDEFG])([b\#])?([-m])?(.*)$/ ) {
	Carp::croak("Invalid chord key: $chord");
    }

    my ( $root, $shfl, $min, $mod ) = ( $1, $2, $3, $4 );

    $root = lc($root);
    if ( $shfl ) {
	$root .= $shfl eq 'b' ? "es" : "is";
    }
    $root .= $dur if $dur;
    $root .= ":";

    $root .= $min ? "m" : "";

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
    my $res = $d->decode( <<'EOD' );
Ain't She Sweet=Ager Milton=Medium Up Swing=n=Eb={*AT44Eb6 A9 |Bb7   |Eb6 A9 |Bb7   |Eb6 G7 |C7   |F7 Bb7 |N1Eb6 Bb7, }            |N2Eb7   ][*BAb7   | x  |Eb6   |Eb7   |Ab7   | x  |Eb6   |F-7 Bb7 ][*AEb6 A9 |Bb7   |Eb6 A9 |Bb7   |Eb G7 |C7   |F7 Bb7 |sEb,Ab7,lEb Z 
EOD

    $d->lilypond;

}
1;
