#! perl

# Data::iRealPro::Output -- pass data to backends

# Author          : Johan Vromans
# Created On      : Tue Sep  6 16:09:10 2016
# Last Modified By: Johan Vromans
# Last Modified On: Mon Oct  3 09:16:50 2016
# Update Count    : 66
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Data::iRealPro::Output;

our $VERSION = "0.01";

use Data::iRealPro::Input;
use Encode qw (decode_utf8 );

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );
    my $opts;

    $opts->{output} = $options->{output} || "";
    if ( $options->{list}
	 || $opts->{output} =~ /\.txt$/i ) {
	require Data::iRealPro::Output::Text;
	$self->{_backend} = Data::iRealPro::Output::Text::;
	$opts->{output} ||= "-";
    }
    elsif ( $opts->{output} =~ /\.jso?n$/i ) {
	require Data::iRealPro::Output::JSON;
	$self->{_backend} = Data::iRealPro::Output::JSON::;
    }
    elsif ( $options->{split}
	    || $opts->{output} =~ /\.html$/i ) {
	require Data::iRealPro::Output::HTML;
	$self->{_backend} = Data::iRealPro::Output::HTML::;
    }
    else {
	require Data::iRealPro::Output::Imager;
	$self->{_backend} = Data::iRealPro::Output::Imager::;
    }

    for ( @{ $self->{_backend}->options } ) {
	$opts->{$_} = $options->{$_} if exists $options->{$_};
    }

    $self->{options} = $opts;
    return $self;
}

sub processfiles {
    my ( $self, @files ) = @_;
    my $opts = $self->{options};

    my $all;
    foreach my $file ( @files ) {
	my $u = Data::iRealPro::Input->new($opts)->parsefile($file);
	unless ( $all ) {
	    $all = $u;
	}
	else {
	    $all->{playlist}->add_songs( $u->{playlist}->songs );
	}
    }
    $all->{playlist}->{name} = decode_utf8($opts->{playlist})
      if $opts->{playlist};
#    use Data::Dumper; $Data::Dumper::Indent=1;warn(Dumper($all));
    $all->{playlist}->{name} ||= "<NoName>";
    $self->{_backend}->new($opts)->process( $all, $opts );
}

1;
