#! perl

use strict;
use warnings;
use Carp;

package Music::iRealPro::SongData;

our $VERSION = "0.01";

sub new {
    my ( $pkg, %args ) = @_;
    my $self = bless { %args }, $pkg;
    $self->parse( $args{data} ) if $args{data};
    return $self;
}

sub parse {
    my ( $self, $data ) = @_;

    # Split song data into components.
    my @a = split( '=', $data );
    unless ( @a == ( $self->{variant} eq "irealpro" ? 10 : 6 ) ) {
	Carp::croak( "Incorrect ", $self->{variant}, " format 1 " . scalar(@a) );
    }

    my $tokstring;

    if ( $self->{variant} eq "irealpro" ) {
	$self->{title}		 = shift(@a);
	$self->{composer}	 = shift(@a);
	$self->{a2}		 = shift(@a); # ??
	$self->{style}		 = shift(@a);
	$self->{key}		 = shift(@a);
	$self->{transpose}	 = shift(@a);
	$self->{raw}		 = shift(@a);
	$self->{actual_style}	 = shift(@a);
	$self->{actual_tempo}	 = shift(@a);
	$self->{actual_repeats}	 = shift(@a);
    }
    elsif ( $self->{variant} eq "irealbook" ) {
	$self->{title}	         = shift(@a);
	$self->{composer}        = shift(@a);
	$self->{style}	         = shift(@a);
	$self->{a3}	         = shift(@a); # ??
	$self->{key}	         = shift(@a);
	$self->{raw}	         = shift(@a);
	# Sometimes key and a3 seem swapped.
	$self->{key} = $self->{a3}, $self->{a3} = "n" if $self->{key} eq "n";
    }
    $tokstring = $self->{raw};

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

    $self->{data} = $tokstring;
    delete $self->{raw} unless $self->{debug};

    return $self;
}

sub export {
    my ( $self, %args ) = @_;

    my $v = $args{variant} || $self->{variant};

    if ( $v eq "irealbook" ) {
	return join( "=",
		     $self->{title},
		     $self->{composer},
		     $self->{style},
		     $self->{key},
		     $self->{a3} || '',
		     $self->{data},
		   );
    }

    return join( "=",
		 $self->{title},
		 $self->{composer},
		 $self->{a2} || '',
		 $self->{style},
		 $self->{key},
		 $self->{transpose} || '',
		 obfuscate( $self->{data} ),
		 $self->{actual_style} || '',
		 $self->{actual_tempo} || 0,
		 $self->{actual_repeats} || 0,
	       );
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

1;
