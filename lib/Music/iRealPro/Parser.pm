#! perl

use strict;
use warnings;
use Carp;
use utf8;

package Music::iRealPro::Parser;

our $VERSION = "0.01";

use Music::iRealPro::Tokenizer;
use Data::Dumper;

sub new {
    my ( $pkg, %args ) = @_;
    bless { variant => "irealpro", %args }, $pkg;
}

sub decode_playlist {		# or single song
    my ( $self, $url ) = @_;
    $url =~ s/\n$//;

    if ( $url =~ m;^irealb(ook)?://(.*); ) {
	$self->{variant} = "irealbook" if defined $1;
	$url = $2;
    }

    # Assume uri-encoded.
    $url =~ s/%([0-9a-f]{2})/sprintf("%c",hex($1))/gie;

    warn( "STRING: >>", $url, "<<\n" ) if $self->{debug};

    # Split the playlist into songs.
    my @a = split( '===', $url );

    my $playlist;
    if ( @a > 1 ) {		# song===song===song===ThePlaylist
	$playlist = pop(@a);
	warn( "PLAYLIST: $playlist, ", scalar(@a), " songs\n" );
    }

    # Process the song(s).
    foreach ( @a ) {
	my $res = $self->decode_song($_);
	$self->interpret($res);
    }
}

sub decode_song {
    my ( $self, $str ) = @_;

    my @a = split( '=', $str );
    unless ( @a == ( $self->{variant} eq "irealpro" ? 10 : 6 ) ) {
	Carp::croak( "Incorrect ", $self->{variant}, " format 1 " . scalar(@a) );
    }

    my $res;
    my $tokstring;

    if ( $self->{variant} eq "irealpro" ) {
	$res->{title} = shift(@a);
	$res->{composer} = shift(@a);
	shift(@a); # ??
	$res->{style} = shift(@a);
	$res->{key} = shift(@a);
	shift(@a); # ??
	$res->{raw} = shift(@a);
	$res->{actual_style} = shift(@a);
	$res->{actual_tempo} = shift(@a);
	$res->{actual_repeats} = shift(@a);
    }
    elsif ( $self->{variant} eq "irealbook" ) {
	$res->{title} = shift(@a);
	$res->{composer} = shift(@a);
	$res->{style} = shift(@a);
	shift(@a); # ??
	$res->{key} = shift(@a);
	$res->{raw} = shift(@a);
    }
    $tokstring = $res->{raw};

    # Polish some values.
    for ( qw(title composer) ) {
	$res->{$_} =~ s/'/’/g;
    }

    # iRealPro format must start with "1r34LbKcu7" magic.
    unless ( !!($self->{variant} eq "irealpro")
	     ==
	     !!($tokstring =~ /^1r34LbKcu7/) ) {
	Carp::croak( "Incorrect ", $self->{variant},
		     " format 2 " . substr($tokstring,0,20) );
    }

    # If iRealPro, deobfuscate. This will also get rid of the magic.
    if ( $self->{variant} eq "irealpro" ) {
	$tokstring = deobfuscate($tokstring);
	warn( "TOKSTR: >>", $tokstring, "<<\n" ) if $self->{debug};
    }

    # FROM HERE we have a pure data string, independent of the
    # original data format.
    # Nevertheless we pass the variant to the tokenizer, just in case
    # we learn some day that a subtile difference in treatment is
    # necessary.

    # Build the tokens array. This reflects as precisely as possible
    # the contents of the pure data string.
    my $tokens = Music::iRealPro::Tokenizer->new
      ( debug   => $self->{debug},
	variant => $self->{variant},
      )->tokenize($tokstring);

    return $tokens;
}

sub interpret {
    my ( $self, $tokens ) = @_;

    my $res = { tokens => [ @$tokens ],
		content => [] };

    my $cell;			# current cell
    my $new_cell = sub {
	$cell = [];
    };

    my $measure;		# current measure
    my $new_measure = sub {
	$measure = { type    => "measure",
		     content => [],
		   };
	$new_cell->();
    };

    my $section;		# current section
    my $new_section = sub {
	$section = { type    => "section",
		     content => [],
		     tokens  => [ @_ > 0 ? @_ : () ],
		   };
	$new_measure->();
    };

    $new_section->();

    my $i = 0;
    my $barskip = 0;
    foreach my $t ( @$tokens ) {
	$i++;

	my $done = 0;

	if ( $t eq "start section" ) {
	    $new_section->($t);
	    next;
	}

	if ( $t =~ /^hspace\s+(\d+)$/ ) {
	    push( @{ $res->{content} },
		  { type => "hspace",
		    tokens => [ $t ],
		    value => 0+$1 } );
	    next;
	}

	push( @{ $section->{tokens} }, $t );

	if ( $barskip ) {
	    if ( $t =~ /^bar|end$/ ) {
		$barskip = 0;
	    }
	    else {
		next;
	    }
	}

	if ( $t eq "end" || $t eq "end section" ) {
	    push( @{ $res->{content} }, { %{ $section } } );
	    next;
	}

	if ( $t eq "bar" || $t eq "end repeat" ) {
	    push( @{ $section->{content} }, { %{ $measure } } )
	      if @{ $measure->{content} };
	    $new_measure->();
	    next;
	}

	if ( $t =~ /^(chord\s+(.*)|advance\s+\d+)$/ ) {
	    push( @$cell, $t );
	    push( @{ $measure->{content} }, [ @$cell ] );
	    $new_cell->();
	    next;
	}

	if ( $t =~ /^measure repeat (single|double)$/ ) {
	    my $need = $1 eq "single" ? 1 : 2;
	    my @m;
	    for ( my $i = @{ $section->{content} }-1; $i >= 0; $i-- ) {
		if ( $section->{content}->[$i]->{type} =~ /^measure\b/ ) {
		    $section->{content}->[$i]->{repeat} = "percent";
		    unshift( @m, { %{ $section->{content}->[$i] } } );
		    last if @m == $need;
		}
	    }

	    for ( my $i = 0; $i < @m; $i++ ) {
		$m[$i]->{type} = "measure repeat ".(1+$i)."-".scalar(@m);
		delete $m[$i]->{repeat};
		push( @{ $section->{content} }, { %{ $m[$i] } } );
	    }

	    $new_measure->();
	    $barskip = 1;
	    next;
	}

	push( @$cell, $t );
	next;

    }

    $Data::Dumper::Deepcopy = 1;
    warn Dumper($res) if $self->{debug};
    return $res;
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
	elsif ( $s =~ /^bar(\s+fill)$/ ) {
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

package main;

unless ( caller ) {
    my $d = Music::iRealPro::Parser->new( debug => 1 );
    my $data = do { local $/; <> };
    # Extract URL.
    $data =~ s;^.*(irealb(?:ook)?://.*?)(?:$|\").*;$1;s;
    $d->decode_playlist($data);
}
