#! perl

use strict;
use warnings;
use Carp;

package Music::iRealPro::URI;

our $VERSION = "0.01";

use Music::iRealPro::Playlist;

sub new {
    my ( $pkg, %args ) = @_;
    my $self = bless { %args }, $pkg;
    $self->parse( $args{data} ) if $args{data};
    return $self;
}

sub parse {
    my ( $self, $data ) = @_;

    # Un-URI-escape.
    $data =~ s/[\r\n]*//g;
    $data =~ s/%([0-9a-f]{2})/sprintf("%c",hex($1))/gie;

    $data =~ s;^.+(irealb(?:ook)?://.*?)(?:$|\").*;$1;s;
    $self->{data} = $data if $self->{debug};

    if ( $data =~ m;^irealb(ook)?://; ) {
	$self->{variant} = $1 ? "irealbook" : "irealpro";
    }
    else {
	Carp::croak("Invalid input: ", substr($data, 0, 40) );
    }

    $self->{playlist} =
      Music::iRealPro::Playlist->new( variant => $self->{variant},
				      data    => $data,
				      debug   => $self->{debug},
				    );

    return $self;
}

package main;

unless ( caller ) {
    require Data::Dumper;
    my $d = Music::iRealPro::URI->new( debug => 0 );
    my $data = do { local $/; <> };
    $d->parse($data);
    warn Data::Dumper::Dumper($d);
}

1;
