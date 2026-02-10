#! perl

use strict;
use warnings;
use utf8;

use Getopt::Long;

my $port = $ENV{PORT} || 5000;

GetOptions  ( 'port=i' => \$port,
	    );

# Start the server.
my $server = Server->new($port);
my $pid = $server->run();

package Server;

use HTTP::Server::Simple::CGI;

use parent qw(HTTP::Server::Simple::CGI);

my %dispatch;
BEGIN {
    %dispatch =
      ( '/hello' => \&resp_hello,
	'/quit'  => sub { exit },
	'/exit'  => sub { exit },
	'/'      => \&resp_cgi,
	# ...
      );
}

sub handle_request {
    my $self = shift;
    my $cgi  = shift;

    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};
    if ( ref($handler) eq "CODE" ) {
        print "HTTP/1.0 200 OK\r\n";
        return $handler->($cgi);
    }

    print "HTTP/1.0 404 Not found\r\n";
    print $cgi->header,
      $cgi->start_html('Not found'),
      $cgi->h1('Not found'),
      $cgi->end_html;
}


sub resp_hello {
    my $cgi  = shift;   # CGI.pm object
    return if !ref $cgi;

    require Data::iRealPro;
    print $cgi->header,
          $cgi->start_html("iRealPro Converter"),
          $cgi->h1("iRealPro Converter"),
	  "<p>Data::iRealPro $Data::iRealPro::VERSION</p>\n",
          $cgi->end_html;
}

sub resp_cgi {
    my $cgi  = shift;   # CGI.pm object
    return if !ref $cgi;

    local ( @ARGV ) = ( "uri=" . $cgi->param('uri') );
    eval { do "./irealpro.cgi" };
}

