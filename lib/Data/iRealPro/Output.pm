#! perl

# Data::iRealPro::Output -- pass data to backends

# Author          : Johan Vromans
# Created On      : Tue Sep  6 16:09:10 2016
# Last Modified By: Johan Vromans
# Last Modified On: Fri Sep 30 20:39:43 2016
# Update Count    : 32
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

    # Common options.
    for ( qw( trace debug verbose output variant transpose select ) ) {
	$self->{options}->{$_} = $options->{$_}
	  if exists $options->{$_};
    }

    if ( $self->{options}->{output} =~ /\.jso?n$/i ) {
	require Data::iRealPro::JSON;
	$self->{_backend} = Data::iRealPro::JSON::;
    }
    elsif ( $self->{options}->{output} =~ /\.txt$/i ) {
	require Data::iRealPro::Text;
	$self->{_backend} = Data::iRealPro::Text::;
    }
    elsif ( $self->{options}->{output} =~ /\.html$/i ) {
	require Data::iRealPro::HTML;
	$self->{_backend} = Data::iRealPro::HTML::;
    }
    else {
	require Data::iRealPro::Imager;
	$self->{_backend} = Data::iRealPro::Imager::;
	for ( qw( npp ) ) {
	    $self->{options}->{$_} = $options->{$_}
	      if exists $options->{$_};
	}
    }

    return $self;
}

sub processfiles {
    my ( $self, @files ) = @_;

    foreach my $file ( @files ) {
	my $u = Data::iRealPro::Input->new($self->{options})
	  ->parsefile($file);
	$self->{_backend}->new($self->{options})
	  ->process($u, $self->{options} );
    }
}

1;
