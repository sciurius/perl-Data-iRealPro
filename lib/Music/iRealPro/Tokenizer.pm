#! perl

use strict;
use warnings;
use Carp;

package Music::iRealPro::Tokenizer;

our $VERSION = "0.01";

use Data::Dumper;

my $p_root  = qr{ (?: [ABCDEFG][#b]? | W) }x;
my $p_qual  = qr{ (?: -|\*[^*]*\*|o|h|dim|sus(?:[24])?|\^?7)? }x;
my $p_extra = qr{ (?: (?:add|sub)? [b#]? [0-9])* }x;
my $p_chord = qr{ $p_root $p_qual $p_extra (?: / $p_root )? }x;

my $debug;
my $raw;			# wants parse details
my $variant = "irealpro";	# "irealpro" or "irealbook"

sub new {
    my ( $pkg, %args ) = @_;
    $debug   = delete $args{debug};
    $raw     = delete $args{raw};
    $variant = delete $args{variant} || "irealpro";
    bless { %args }, $pkg;
}

sub tokenize {
    my ( $self, $string ) = @_;

    $_ = $string;

    # Mark markup spaces.
    s/(\}) +([\[\]\{\|])/$1\240$2/g;

    # Make tokens.
    my @d;
    my $l0 = length($_);
    my $index = 0;

    my $d = sub {
	push( @d, [ $_[0], $_[1] // ${^MATCH}, $index ] );
	printf STDERR ("%3d  %-8s %s\n", $index, $_[1] // ${^MATCH}, $_[0] )
	  if $debug;
    };

    if ( $variant eq "irealpro" ) {

	# Pre-substitutions. I don't know why iRealPro thought this was a
	# good idea... Obfuscation, maybe?
	# Anyway, they affect the contents of user texts as well :).

	s/XyQ/   /g;
	s/LZ/ |/g;
	s/Kcl/| x/g;
	warn( "TOKSTR: >>$_<<\n" ) if $debug;
    }
    else {
	# I'm not sure irealbook allows the chord *mods* .
	$p_qual  = qr{ (?: -|o|h|dim|sus(?:[24])?|\^?7)? }x;
    }

    # IMPORTANT: iReal design is visually oriented. All info is added
    # to the current cell until the pointer advances to the next cell.

    while ( length($_) ) {
	if ( /^\{/p ) {		# |:
	    $d->( "start section" ) unless @d;
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
	elsif ( /^$p_chord/p ) {
	    $d->( "chord " . ${^MATCH} );
	}
	elsif ( /^$p_root/p ) {
	    warn( "Unparsable chord: " . ${^MATCH} . "\n" );
	    $d->( "chord? " . ${^MATCH} );
	}
	elsif ( /^n/p ) {	# silent chord
	    $d->( "chord NC" );
	}
	elsif ( /^x/p ) {	# repeat the previous measure
	    $d->( "measure repeat" );
	}
	elsif ( /^r/p ) {	# repeat the previous measure twice
	    $d->( "measure repeat twice" );
	}
	elsif ( /^ /p ) {	# advance to next cell
	    $d->( "advance" );
	}
	elsif ( /^\|/p ) {	# bar
	    $d->( "bar" );
	}
	elsif ( /^N(\d)/p ) {
	    $d->( "alternative $1" );
	}
	elsif ( /^,/p ) {	# token separator
	}
	elsif ( /^Z/p ) {	# end of song
	    $d->( "end" );
	    last;
	}
	elsif ( /^U/p ) {	# end repetition ### pro only???
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
	elsif ( /^\240/p ) {	# markup space
	    $d->( "hspace", " " );
	}
	elsif ( /^\<(?:\*(\d\d))?(.*?)\>/p ) { # text
	    $d->( "text " . ( $1 || 0 ) . " " . $2 );
	}
	elsif ( /^(.)/p ) {
	    $d->( "ignore $1" );
	    warn( "Unhandled token: " . ${^MATCH} . "\n" );
	}
	$_ = ${^POSTMATCH};
	$index = $l0 - length($_);
    }

    return $raw ? [ @d ] : [ map { $_->[0] } @d ];
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
		 "68" => "6/8",
		 "78" => "7/8",
		 "98" => "9/8",
		 "12" => "12/8",
	       };

    $_sigs->{ "$time_d$time_n" }
      || Carp::croak("Invalid time signature: $time_d/$time_n");
}

1;
