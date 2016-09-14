#! perl

# Data::iRealPro::Input -- parse iRealPro data

# Author          : Johan Vromans
# Created On      : Tue Sep  6 16:09:10 2016
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 14 20:46:27 2016
# Update Count    : 20
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Input;

our $VERSION = "0.01";

use Data::iRealPro::URI;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant transpose ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub parsefile {
    my ( $self, $file ) = @_;

    open( my $fd, '<', $file ) or die("$file: $!\n");
    my $data = do { local $/; <$fd> };
    $self->parsedata($data);
}

sub parsedata {
    my ( $self, $data ) = @_;

    my $u;
    if ( $data =~ /^Song( \d+)?:/ ) {
	require Data::iRealPro::Text;
	$u = Data::iRealPro::Text->encode($data);
    }
    else {
	# Extract URL.
	$data =~ s;^.*(irealb(?:ook)?://.*?)(?:$|\").*;$1;s;
	$data = "irealbook://" . $data
	  unless $data =~ m;^(irealb(?:ook)?://.*?);;

	$u = Data::iRealPro::URI->new( data => $data,
				       debug => $self->{debug} );
    }

    return $u;
}

1;
