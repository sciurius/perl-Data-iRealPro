#! perl

# Data::iRealPro::Output::Base -- base class for output backends

# Author          : Johan Vromans
# Created On      : Mon Oct  3 08:13:17 2016
# Last Modified By: Johan Vromans
# Last Modified On: Tue Dec  6 08:28:47 2016
# Update Count    : 20
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Output::Base;

our $VERSION = "1.00";

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
    [ qw( trace debug verbose variant playlist catalog select ) ]
}

1;
