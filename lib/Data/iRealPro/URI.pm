#! perl

use strict;
use warnings;
use Carp;

package Data::iRealPro::URI;

our $VERSION = "1.02";

use Data::iRealPro;
use Data::iRealPro::Playlist;
use Encode qw(decode_utf8 encode_utf8);
use HTML::Entities;

sub new {
    my ( $pkg, %args ) = @_;
    my $self = bless { %args }, $pkg;
    $self->{transpose} //= 0;
    $self->parse( $args{data} ) if $args{data};
    $self->{playlist} = $args{playlist} if $args{playlist};
    return $self;
}

sub parse {
    my ( $self, $data ) = @_;

    # Un-URI-escape and decode.
    $data =~ s/[\r\n]*//g;
    $data =~ s;^.+(irealb(?:ook)?://.*?)(?:$|\").*;$1;s;
    $data =~ s/%([0-9a-f]{2})/sprintf("%c",hex($1))/gie;
    $data = decode_utf8($data);

    $self->{data} = $data if $self->{debug};

    if ( $data =~ m;^irealb(ook)?://; ) {
	$self->{variant} = $1 ? "irealbook" : "irealpro";
    }
    else {
	Carp::croak("Invalid input: ", substr($data, 0, 40) );
    }

    $self->{playlist} =
      Data::iRealPro::Playlist->new( variant => $self->{variant},
				      data    => $data,
				     debug   => $self->{debug},
				     transpose => $self->{transpose},
				    );

    return $self;
}

sub as_string {
    my ( $self, $uriesc ) = @_;

    my $s = $self->{playlist}->as_string;
    if ( $uriesc ) {
	$s = esc($s);
    }
#    warn("irealb://" . $s);
    "irealb://" . $s;
}

sub export {
    my ( $self, %args ) = @_;
    carp(__PACKAGE__."::export is deprecated, please use 'as_string' instead");
    my $v = $args{variant} || $self->{variant} || "irealpro";
    $args{uriencode} //= !$args{plain};

    my $uri = $self->as_string(%args);
    return $uri unless $args{html};

    my $title;
    my $pl;

    if ( $args{playlist}) {
	$pl = $self->{playlist};
	$title = encode_entities($pl->{name});
    }
    else {
	$title = encode_entities($self->{playlist}->{songs}->[0]->{title});
    }

    my $html = <<EOD;
<!DOCTYPE html>
<html>
  <head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <title>$title</title>
  <style type="text/css">
  body {
    color: rgb(230, 227, 218);
    background-color: rgb(27, 39, 48);
    font-family: Helvetica,Arial,sans-serif;
  }
  a         { text-decoration: none }
  a:active  { color: #b2e0ff }
  a:link    { color: #94d5ff }
  a:visited { color: #b2e0ff }
  .info {
    font-size: small;
    color: #999999;
  }
  </style>
</head>
<body>
  <h1>$title</h1>
EOD

    if ( $args{playlist}) {
	$html .= "  <p><a href=\"$uri\">(All songs)</a></p>\n  <ol>\n";
	foreach my $s ( @{ $pl->{songs} } ) {
	    my @c = split(' ', $s->{composer});
	    my $c = @c == 2 ? "$c[1] $c[0]" : $s->{composer};
	    $html .= "    <li><a href=\"irealb://" .
	      $s->export( variant => "irealpro", uriencode => 1 ) .
		"\">" .
		  encode_entities($s->{title}) .
		    "</a> - " .
		      encode_entities($c) .
			( $s->{ts} ? " <span class=\"info\">(@{[$s->{ts}]})</span>" : "" ) .
			  "</a></li>\n";
	}

	$html .= "  </ol>\n";
    }
    else {
	$html .= qq{  <p><a href="$uri">$title</a></p>\n};
    }

    $html .= <<EOD;
    <p class="info">Generated by <a href="https://metacpan.org/pod/Data::iRealPro" target="_blank">Data::iRealPro</a> version $Data::iRealPro::VERSION.</p>
</body>
</html>
EOD
}

sub esc {
    # We must encode first before the uri-escape.
    my $t = encode_utf8($_[0]);
    $t =~ s/([^-_.A-Z0-9a-z*\/\'])/sprintf("%%%02X", ord($1))/ge;
    return $t;
}

1;
