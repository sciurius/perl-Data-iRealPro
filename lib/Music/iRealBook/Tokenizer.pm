#! perl

use strict;
use warnings;
use Carp;

package Music::iRealBook::Tokenizer;

our $VERSION = "0.01";

use Data::Dumper;

sub new {
    my ( $pkg, %args ) = @_;
    bless { %args }, $pkg;
}

sub tokenize {
    my ( $self, $string ) = @_;
    my $debug = $self->{debug};

    $_ = $string;

    # Clean markup spaces.
    s/(\}) +([\[\]\{\|])/$1$2/g;

    # Make tokens.
    my @d;
    my $bpm = 0;
    my $time_d = 0;
    my $time_n = 0;
    my $measures = 0;
    my $multiplier = 1;

    my $barcheck = sub {
	unless ( $bpm == $time_d ) {
	    if ( $measures == 0 && ( $time_d % $bpm ) == 0 ) {
		$multiplier = $time_d / $bpm;
	    }
	    else {
		push( @d, "barcheck failed at $bpm/$time_n" );
	    }
	}
    };

    while ( length($_) ) {
	if ( /^\{/p ) {
	    push( @d, "start section" ) unless @d;
	    push( @d, "start repeat" );
	}
	elsif ( /^\}/p ) {
	    push( @d, "end repeat" );
	}
	elsif ( /^\[/p ) {
	    push( @d, "start section" );
	}
	elsif ( /^\]/p ) {
	    $barcheck->();
	    $bpm = 0;
	    $measures++;
	    push( @d, "end section" );
	}
	elsif ( /^\*([ABCDvi])/p ) {
	    push( @d, "mark $1" );
	}
	elsif ( /^T(\d)(\d)/p ) {
	    push( @d, "time " . _timesig( $time_d = $1, $time_n = $2) );
	}
	elsif ( /^([sl])/p ) {
	    push( @d, $1 eq "s" ? "small" : "large" );
	    $bpm++;
	}
	elsif ( /^([ABCDEFGW][-^bo#0-9]*)(?:\/[ABCDEFGW][b#]?)?(?:\(.*?\))?/p ) {
	    push( @d, "chord $1 $multiplier" );
	    $bpm++;
	}
	elsif ( /^n/p ) {
	    push( @d, "chord NC $multiplier" );
	    $bpm++;
	}
	elsif ( /^\s*x\s*/p ) {
	    push( @d, "measure repeat" );
	    $bpm = $time_d;
	}
	elsif ( /^\s*%\s*/p ) {
	    push( @d, "?repeat" );
	    $bpm = $time_d;
	}
	elsif ( /^ /p ) {
	    if ( $d[-1] =~ /^chord\s+(\S+)\s+(\d+)$/ ) {
		$d[-1] = join( " ", "chord", $1, $multiplier + $2 );
		$bpm += $multiplier;
	    }
	    else {
		push( @d, "space" );
	    }
	}
	elsif ( /^\|/p ) {
	    $barcheck->();
	    $bpm = 0;
	    $measures++;
	    push( @d, "bar" );
	}
	elsif ( /^N(\d)/p ) {
	    push( @d, "alternative $1" );
	}
	elsif ( /^,/p ) {	# token separator
	}
	elsif ( /^Z/p ) {
	    push( @d, "end" );
	    last;
	}
	elsif ( /^p/p ) {
	    push( @d, "slash repeat" );
	}
	elsif ( /^Q/p ) {
	    push( @d, "coda" );
	}
	elsif ( /^f/p ) {
	    push( @d, "fermata" );
	}
	elsif ( /^S/p ) {
	    push( @d, "segno" );
	}
	elsif ( /^Y/p ) {
	    push( @d, "vspace" );
	}
	elsif ( /^\<(?:\*(\d\d))?(.*?)\>/p ) {
	    push( @d, "text " . ( $1 || 0 ) . " " . $2 );
	}
	elsif ( /^(.)/p ) {
	    push( @d, "ignore $1" );
	}
	$_ = ${^POSTMATCH};
    }

    return \@d;
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
