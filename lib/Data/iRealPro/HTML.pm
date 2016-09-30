#! perl

# Data::iRealPro::HTML -- produce iRealPro HTML data

# Author          : Johan Vromans
# Created On      : Fri Sep 30 19:36:29 2016
# Last Modified By: Johan Vromans
# Last Modified On: Fri Sep 30 19:39:21 2016
# Update Count    : 6
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::HTML;

our $VERSION = "0.01";

use Data::iRealPro::URI;
use Data::iRealPro::Playlist;
use Data::iRealPro::SongData;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant transpose ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub process {
    my ( $self, $u, $options ) = @_;

    $self->{output} ||= "__new__.html";

    open( my $fd, ">:utf8", $self->{output} )
      or die( "Cannot create ", $self->{output}, " [$!]\n" );
    select($fd);
    print $u->export( uriencode => 1, html => 1 );
    close;
}

1;
