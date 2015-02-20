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

    while ( length($_) ) {
	if ( /^\{/p ) {
	    push( @d, "start repeat" );
	}
	elsif ( /^\}/p ) {
	    push( @d, "end repeat" );
	}
	elsif ( /^\[/p ) {
	    push( @d, "start section" );
	}
	elsif ( /^\]/p ) {
	    push( @d, "barcheck failed at $bpm/$time_n" )
	      unless $bpm == $time_d;
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
	elsif ( /^[sl]?([ABCDEFG][-b#0-9]*)/p ) {
	    push( @d, "chord $1 1" );
	    $bpm++;
	}
	elsif ( /^ +x\s*/p ) {
	    push( @d, "measure repeat" );
	    $bpm = $time_d;
	}
	elsif ( /^ /p ) {
	    if ( $d[-1] =~ /^chord\s+(\S+)\s+(\d+)$/ ) {
		$d[-1] = join( " ", "chord", $1, 1+$2 );
		$bpm++;
	    }
	    else {
		push( @d, "space" );
	    }
	}
	elsif ( /^\|/p ) {
	    push( @d, "barcheck failed at $bpm/$time_n" )
	      unless $bpm == $time_d;
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
