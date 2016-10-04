#! perl

# Data::iRealPro::Input -- parse iRealPro data

# Author          : Johan Vromans
# Created On      : Tue Sep  6 16:09:10 2016
# Last Modified By: Johan Vromans
# Last Modified On: Tue Oct  4 13:41:02 2016
# Update Count    : 28
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Input;

our $VERSION = "0.02";

use Data::iRealPro::URI;
use Data::iRealPro::Input::Text;

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

    open( my $fd, '<:utf8', $file ) or die("$file: $!\n");
    my $data = do { local $/; <$fd> };
    $self->parsedata($data);
}

sub parsedata {
    my ( $self, $data ) = @_;

    if ( eval { $data->[0] } ) {
	my $all;
	foreach my $d ( @$data ) {
	    my $u = $self->parsedata($d);
	    if ( $all ) {
		$all->{playlist}->add_songs( $u->{playlist}->songs );
	    }
	    else {
		$all = $u;
		$all->{playlist}->{name} ||= "NoName";
	    }
	}
	return $all;
    }

    my $u;
    if ( $data =~ /^Song( \d+)?:/ ) {
	$u = Data::iRealPro::Input::Text->encode($data);
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
