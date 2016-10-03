#! perl

use v5.10;
use strict;
use warnings;
use Carp;

package Data::iRealPro::Tokenizer;

our $VERSION = "0.10";

my $p_root  = qr{ (?: [ABCDEFG][#b]? | W) }x;
my $p_qual  = qr{ (?: \*[^*]*\*|o|h|dim|[79]?sus[24]?|13sus|[79]?alt|-?\^?7|-?\^7?|-|\+)* }x;
my $p_extra = qr{ (?: (?:add|sub)? [b#]? [0-9])* }x;
#my $p_chord = qr{ $p_root $p_qual $p_extra (?: / $p_root )? }x;
# Give up... Allow any garbage.
# OOPS: Doesn't work on Windows?
#my $p_chord = qr{ $p_root [-\w\d#+*^]* (?: / $p_root )? }x;
my $p_chord = qr{ $p_root [^\s\(\)\[\]\{\}\|,\240\<\>]* (?: / $p_root )? }x;

sub new {
    my ( $pkg, %args ) = @_;
    bless { variant => "irealpro", %args }, $pkg;
}

sub tokenize {
    my ( $self, $string ) = @_;

    $_ = $string;

    # Make tokens.
    my @d;
    my $l0 = length($_);
    my $index = 0;

    my $d = sub {
	push( @d, [ $_[0], $_[1] // ${^MATCH}, $index ] );
	printf STDERR ("%3d  %-8s %s\n", $index, $_[1] // ${^MATCH}, $_[0] )
	  if $self->{debug};
    };

    # IMPORTANT: iReal design is visually oriented. All info is added
    # to the current cell until the pointer advances to the next cell.

    # Mark markup spaces.
    s/([\}\]])( +)([\[\]\{\|])/$1 . ( "\240" x length($2) ) . $3/ge;

    while ( length($_) ) {
	if ( /^\{/p ) {		# |:
	    $d->( "start repeat" );
	}
	elsif ( /^\}/p ) {	# :|
	    $d->( "end repeat" );
	}
	elsif ( /^\[/p ) {	# start section
	    $d->( "start section" );
	}
	elsif ( /^\]/p ) {	# end section
	    $d->( "end section" );
	}
	elsif ( /^\*([ABCDvi])/p ) { # section mark
	    $d->( "mark $1" );
	}
	elsif ( /^T(\d)(\d)/p ) { # time signature
	    $d->( "time " . _timesig( $1, $2) );
	}
	elsif ( /^([sl])/p ) {	# small/large indicator for chords
	    $d->( $1 eq "s" ? "small" : "large" );
	}
	elsif ( /^$p_chord(?:\($p_chord\))?/p ) {
	    my $t = ${^MATCH};
	    if ( $t =~ /^(.+)Z$/ ) {
		$d->( "chord " . $self->xpose($1) );
		$d->( "end" );
	    }
	    else {
		$d->( "chord " . $self->xpose($t) );
	    }
	}
	elsif ( /^$p_root/p ) {
	    warn( "Unparsable chord: " . ${^MATCH} . "\n" );
	    $d->( "chord? " . $self->xpose(${^MATCH}) );
	}
	elsif ( /^\($p_chord\)/p ) {
	    $d->( "chord " . $self->xpose(${^MATCH}) );
	}
	elsif ( /^n/p ) {	# silent chord
	    $d->( "chord NC" );
	}
	elsif ( /^x/p ) {	# repeat the previous measure
	    $d->( "measure repeat single" );
	}
	elsif ( /^r/p ) {	# repeat the previous two measures
	    $d->( "measure repeat double" );
	}
	elsif ( /^ +/p ) {	# advance to next cell
	    $d->( "advance " . length(${^MATCH}), " " );
	}
	elsif ( /^\|/p ) {	# bar
	    $d->( "bar" );
	}
	elsif ( /^N(\d)/p ) {
	    $d->( "alternative $1" );
	}
	elsif ( /^,/p ) {	# token separator
	}
	elsif ( /^Z/p ) {	# end of song or major section
	    $d->( "end" );
	}
	elsif ( /^U/p ) {	# end repetition
	    $d->( "stop" );
	}
	elsif ( /^p/p ) {
	    $d->( "slash repeat" );
	}
	elsif ( /^Q/p ) {	# 1: jump to coda; 2: coda location
	    $d->( "coda" );
	}
	elsif ( /^f/p ) {	# fermata; precedes the chord
	    $d->( "fermata" );
	}
	elsif ( /^S/p ) {	# segno
	    $d->( "segno" );
	}
	elsif ( /^Y/p ) {	# add vertical space
	    $d->( "vspace" );
	}
	elsif ( /^\240+/p ) {	# markup space
	    $d->( "hspace " . length(${^MATCH}), " " );
	}
	elsif ( /^\<(?:\*(\d\d))?(.*?)\>/p ) { # text
	    $d->( "text " . ( $1 || 0 ) . " " . $2 );
	}
	elsif ( /^(.)/ps ) {
	    $d->( "ignore $1" );
	    warn( "Unhandled token: " . ${^MATCH} . "\n" );
	}
	$_ = ${^POSTMATCH};
	$index = $l0 - length($_);
    }

    return $self->{raw} ? [ @d ] : [ map { $_->[0] } @d ];
}

use Data::Struct;

my @fields = qw( vs sz chord subchord text mark sign time lbar rbar alt );
struct Cell => @fields;

sub make_cells {
    my ( $self, $tokens ) = @_;

    my $cells = [];
    my $cell;
    my $chordsize = 0;		# normal
    my $vspace = 0;		# normal

    my $new_cell = sub {
	$cell = struct "Cell";
	$cell->sz = $chordsize if $chordsize;
	$cell->vs = $vspace if $vspace;
	push( @$cells, $cell );
    };

    my $new_measure = sub {
	@$cells >= 2 and $cells->[-2]->rbar ||= "barlineSingle";
	$cells->[-1]->lbar ||= "barlineSingle";
    };

    $new_cell->();		# TODO section? measure?

    foreach my $t ( @$tokens ) {

	if ( $t eq "start section" ) {
	    $cell->lbar = "barlineDouble";
	    next;
	}

	if ( $t eq "start repeat" ) {
	    $cell->lbar = "repeatLeft";
	    next;
	}

	if ( $t eq "end repeat" ) {
	    $cells->[-2]->rbar = "repeatRight";
	    next;
	}

	if ( $t =~ /time (\d+)\/(\d+)/ ) {
	    $cell->time = [ $1, $2 ];
	    next;
	}

	if ( $t =~ /^hspace\s+(\d+)$/ ) {
	    $new_cell->() for 1..$1;
	    next;
	}

	# |Bh7 E7b9 ZY|QA- |
	if ( $t eq "vspace" ) {
	    $vspace++;
	    $cells->[-1]->vs = $vspace;
	    next;
	}

	if ( $t eq "end" ) {
	    $cells->[-2]->rbar = "barlineFinal";
	    next;
	}

	if ( $t eq "end section" ) {
	    $cells->[-2]->rbar = "barlineDouble";
	    next;
	}

	if ( $t eq "bar" ) {
	    $new_measure->();
	    next;
	}

	if ( $t =~ /^(segno|coda|fermata)$/ ) {
	    $cell->sign = $1;
	    next;
	}

	if ( $t =~ /^chord\s+(.*)$/ ) {
	    my $c = $1;

	    if ( $c =~ s/\((.+)\)// ) {
		if ( $c ) {
		    $cell->subchord = $1;
		}
		else {
		    $cells->[-2]->subchord = $1;
		    next;
		}
	    }

	    $cell->chord = $c;
	    $new_cell->();
	    next;
	}

	if ( $t =~ /^alternative\s+(\d)$/ ) {
	    $cell->alt = $1;
	}

	if ( $t eq "small" ) {
	    $cell->sz = $chordsize = 1;
	    next;
	}

	if ( $t eq "large" ) {
	    $cell->sz = $chordsize = 0;
	    next;
	}

	if ( $t =~ /^mark (.)/ ) {
	    $cell->mark = $1;
	    next;
	}

	if ( $t =~ /^text\s+(\d+)\s(.*)/ ) {
	    $cell->text =  [ $1, $2 ];
	    next;
	}

	if ( $t =~ /^advance\s+(\d+)$/ ) {
	    $new_cell->() for 1..$1;
	    next;
	}

	if ( $t =~ /^measure repeat (single|double)$/ ) {
	    my $c = $1 eq "single" ? "repeat1Bar" : "repeat2Bars";
	    $cell->chord = $c;
	    $new_cell->();
	    next;
	}

	if ( $t =~ /^slash repeat$/ ) {
	    $cell->chord = "repeatSlash";
	    $new_cell->();
	    next;
	}

	next;

    }
    return $cells;
}

my $notesS  = [ split( ' ', "A A# B C C# D D# E F F# G G#" ) ];
my $notesF  = [ split( ' ', "A Bb B C Db D Eb E F Gb G Ab" ) ];
my %notes = ( A => 1, B => 3, C => 4, D => 6, E => 8, F => 9, G => 11 );

sub xpose {
    my ( $self, $c ) = @_;
    return $c unless $self->{transpose};

    return $c unless $c =~ m/
				^ (
				    [CF](?:\#)? |
				    [DG](?:\#|b)? |
				    A(?:\#|b)? |
				    E(?:b)? |
				    B(?:b)?
				  )
				  (.*)
			    /x;
    my ( $r, $rest ) = ( $1, $2 );
    my $mod = 0;
    $mod-- if $r =~ s/b$//;
    $mod++ if $r =~ s/\#$//;
    warn("WRONG NOTE: '$c' '$r' '$rest'") unless $r = $notes{$r};
    $r = ($r - 1 + $mod + $self->{transpose}) % 12;
    return ( $self->{transpose} > 0 ? $notesS : $notesF )->[$r] . $rest;
}

my $_sigs;

sub _timesig {
    my ( $time_d, $time_n ) = @_;
    $_sigs ||= { "22" => "2/2",
		 "32" => "3/2",
		 "24" => "2/4",
		 "34" => "3/4",
		 "44" => "4/4",
		 "54" => "5/4",
		 "64" => "6/4",
		 "74" => "7/4",
		 "28" => "2/8",
		 "38" => "3/8",
		 "48" => "4/8",
		 "58" => "5/8",
		 "68" => "6/8",
		 "78" => "7/8",
		 "98" => "9/8",
		 "12" => "12/8",
	       };

    $_sigs->{ "$time_d$time_n" }
      || Carp::croak("Invalid time signature: $time_d/$time_n");
}

1;
