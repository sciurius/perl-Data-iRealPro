#! perl

# Data::iRealPro::Output -- pass data to backends

# Author          : Johan Vromans
# Created On      : Tue Sep  6 16:09:10 2016
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep  6 22:19:45 2016
# Update Count    : 24
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Output;

our $VERSION = "0.01";

use Data::iRealPro::Input;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant transpose npp ) ) {
	$self->{options}->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub processfiles {
    my ( $self, @files ) = @_;

    my $be;
    if ( $self->{options}->{output} =~ /\.jso?n$/i ) {
	require Data::iRealPro::JSON;
	$be = Data::iRealPro::JSON::;
    }
    elsif ( $self->{options}->{output} =~ /\.txt$/i ) {
	require Data::iRealPro::Text;
	$be = Data::iRealPro::Text::;
    }
    else {
	require Data::iRealPro::Imager;
	$be = Data::iRealPro::Imager::;
    }

    foreach my $file ( @files ) {
	my $u = Data::iRealPro::Input->new($self->{options})->parsefile($file);
	$be->new($self->{options})->process($u);
    }
}

1;
