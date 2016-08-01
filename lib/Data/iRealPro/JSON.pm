#! perl

# Data::iRealPro::JSON -- parse iRealPro data and produce JSON

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Mon Aug  1 11:02:03 2016
# Update Count    : 1070
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::JSON;

our $VERSION = "0.04";

use Data::iRealPro::URI;
use Data::iRealPro::Tokenizer;
use JSON::PP;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant transpose ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub parsefile {
    my ( $self, $file, $options ) = @_;

    open( my $fd, '<', $file ) or die("$file: $!\n");
    my $data = do { local $/; <$fd> };
    $self->parsedata( $data, $options );
}

sub parsedata {
    my ( $self, $data, $options ) = @_;

    # Extract URL.
    $data =~ s;^.*(irealb(?:ook)?://.*?)(?:$|\").*;$1;s;
    $data = "irealbook://" . $data
      unless $data =~ m;^(irealb(?:ook)?://.*?);;

    my $u = Data::iRealPro::URI->new( data => $data,
				      debug => $self->{debug} );

    $self->{output} ||= "__new__.json";

    my $json = JSON::PP->new->utf8(1)->pretty->indent->canonical;
    $json->allow_blessed->convert_blessed;
    *UNIVERSAL::TO_JSON = sub {
	my $b_obj = B::svref_2object( $_[0] );
	return    $b_obj->isa('B::HV') ? { %{ $_[0] } }
	  : $b_obj->isa('B::AV') ? [ @{ $_[0] } ]
	    : undef
	      ;
    };

    # Process the song(s).
    my @goners = qw( variant debug a2 data );
    for my $item ( $u, $u->{playlist} ) {
	delete( $item->{$_} ) for @goners;
    }
    my $songix;
    foreach my $song ( @{ $u->{playlist}->{songs} } ) {
	$songix++;
	warn( sprintf("Song %3d: %s\n", $songix, $song->{title}) )
	  if $self->{verbose};
	$song->{tokens} = $self->decode_song($song->{data});
	delete( $song->{$_} ) for @goners;
    }
    open( my $fd, ">:utf8", $self->{output} )
      or die( "Cannot create ", $self->{output}, " [$!]\n" );
    $fd->print( $json->encode($u) );
    $fd->close;
}

sub decode_song {
    my ( $self, $str ) = @_;

    # Build the tokens array. This reflects as precisely as possible
    # the contents of the pure data string.
    my $tokens = Data::iRealPro::Tokenizer->new
      ( debug   => $self->{debug},
	variant => $self->{variant},
	transpose => $self->{transpose},
      )->tokenize($str);

    return $tokens;
}

1;
