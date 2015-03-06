#! perl

use strict;
use warnings;
use Carp;

package Music::iRealPro::Playlist;

our $VERSION = "0.01";

use Music::iRealPro::SongData;

sub new {
    my ( $pkg, %args ) = @_;
    my $self = bless { %args }, $pkg;
    $self->parse( $args{data} ) if $args{data};
    delete $self->{data} unless $self->{debug};
    return $self;
}

sub parse {
    my ( $self, $data ) = @_;

    if ( $data =~ s;^irealb(ook)?://;; && !$self->{variant} ) {
	$self->{variant} = $1 ? "irealbook" : "irealpro";
    }

    # Split the playlist into songs.
    my @a = split( '===', $data, -1 );

    if ( @a > 1 ) {		# song===song===song===ThePlaylist
	$self->{name} = pop(@a);
    }
    elsif ( $self->{variant} eq "irealbook" ) {
	my @b = split( '=', $data, -1 );
	$self->{name} = pop(@b);
	@a = ();
	while ( @b ) {
	    push( @a, join( "=", splice( @b, 0, 6 ) ) );
	}
    }

    # Process the song(s).
    foreach ( @a ) {
	push( @{ $self->{songs} },
	      Music::iRealPro::SongData->new( variant => $self->{variant},
					      data    => $_,
					      debug   => $self->{debug},
					    ) );
    }

    return $self;
}

sub export {
    my ( $self, %args ) = @_;

    my $dashes = $self->{variant} eq "irealbook" ? "=" : "===";

    my $r = join( $dashes,
		  map { $_->export( %args ) } @{ $self->{songs} } );

    $r .= $dashes . $self->{name} if defined $self->{name};

    return $r;
}

1;
