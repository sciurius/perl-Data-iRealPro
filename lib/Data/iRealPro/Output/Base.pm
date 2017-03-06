#! perl

# Data::iRealPro::Output::Base -- base class for output backends

# Author          : Johan Vromans
# Created On      : Mon Oct  3 08:13:17 2016
# Last Modified By: Johan Vromans
# Last Modified On: Mon Mar  6 16:31:46 2017
# Update Count    : 29
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Output::Base;

our $VERSION = "1.02";

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( @{ $self->options } ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub options {
    # The list of options this backend can handle.
    # Note that 'output' is handled by Output.pm.
    [ qw( trace debug verbose variant playlist catalog neatify select
	  suppress-upbeat suppress-text override-alt condense
        ) ]
}

1;
