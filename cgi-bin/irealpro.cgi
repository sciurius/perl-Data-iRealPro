#!/usr/bin/perl -wT

# Author          : Johan Vromans
# Created On      : Tue Mar  3 11:09:45 2015
# Last Modified By: Johan Vromans
# Last Modified On: Tue Mar  3 15:54:41 2015
# Update Count    : 108
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use utf8;
use CGI qw(-utf8 :standard);
use CGI::Carp qw(fatalsToBrowser);

my $my_package = "Sciurix";
my ($my_name, $my_version) = qw( iRealPro 0.01 );

################ Program parameters ################

my $uri = param("uri");

################ Presets ################

################ The Process ################

binmode STDOUT => ':utf-8';

unless ( $uri ) {
    print_form();
    exit;
}

################ Main ################

$uri =~ s/\n$//;

my $variant = "irealpro";
if ( $uri =~ m;^irealb(ook)?://(.*); ) {
    $variant = "irealbook" if defined $1;
    $uri = $2;
}

# Assume uri-encoded.
$uri =~ s/%([0-9a-f]{2})/sprintf("%c",hex($1))/gie;

my $v = $variant;
$v =~ s/^(.)(....)(.*)/$1.ucfirst($2).ucfirst($3)/e;

my $irp_site = "http://www.irealpro.com";
my $irp_icon = "$irp_site/wp-content/uploads/2013/10/irealpro-icon.png";

print( header( -charset => 'utf-8' ),
       start_html( -title => "$v Data Analyzer" ), "\n",
       h1(
	  a({ href => $irp_site },
	    img( { src => $irp_icon, width => 72, height => 72,
		 }) ),
	  "$v Data Analyzer" ),
       "\n",
       "<p><strong>Original URI:</strong></p>\n",
       start_form( -name => "irform" ),
       "\n",
       textarea( -name => 'uri',
		 -rows => 5, -cols => 100,
		 -default => param("uri"),
	       ), "\n",
       "\n",
       br,
       submit( -name => "clear", -value => "Clear",
	       -onClick => 'document.irform.uri.value="";return false' ),
       "\n",
       submit( -name => "submit", -value => "Analyze" ),
       "\n",
       end_form,
       "\n",
     );


# Split the playlist into songs.
my @a = split( '===', $uri );

my $playlist;
if ( @a > 1 ) {		# song===song===song===ThePlaylist
    $playlist = pop(@a);
    print("<p><strong>Playlist: $playlist</strong></p>\n");
}

# Process the song(s).
my $song = 0;
foreach my $str ( @a ) {
    $song++;
    my @a = split( '=', $str );
    unless ( @a == ( $variant eq "irealpro" ? 10 : 6 ) ) {
	die( "Incorrect ", $variant, " format 1 " . scalar(@a) );
    }

    my $res = {};
    my $tokstring;

    if ( $variant eq "irealpro" ) {
	$res->{title} = shift(@a);
	$res->{composer} = shift(@a);
	shift(@a); # ??
	$res->{style} = shift(@a);
	$res->{key} = shift(@a);
	shift(@a); # ??
	$res->{raw} = shift(@a);
	$res->{actual_style} = shift(@a);
	$res->{actual_tempo} = shift(@a);
	$res->{actual_repeats} = shift(@a);
    }
    elsif ( $variant eq "irealbook" ) {
	$res->{title} = shift(@a);
	$res->{composer} = shift(@a);
	$res->{style} = shift(@a);
	$res->{n} = shift(@a); # ??
	$res->{key} = shift(@a);
	$res->{raw} = shift(@a);
	$res->{key} = $res->{n} if $res->{key} eq "n"; # ??
    }
    my $tokstring = $res->{raw};

    # iRealPro format must start with "1r34LbKcu7" magic.
    unless ( !!($variant eq "irealpro")
	     ==
	     !!($tokstring =~ /^1r34LbKcu7/) ) {
	die( "Incorrect ", $variant,
	     " format 2 " . substr($tokstring,0,20) );
    }

    # If iRealPro, deobfuscate. This will also get rid of the magic.
    if ( $variant eq "irealpro" ) {
	$tokstring = deobfuscate($tokstring);
    }

    # FROM HERE we have a pure data string, independent of the
    # original data format.

    print(
	  "<p><strong>",
	  ( $song > 1 || $playlist ) ? "Song $song: " : "Song: ",
	  $res->{title},
	  " (", $res->{composer},  ")</strong>\n",
	  "<br>Style: ", $res->{style},
	  $res->{actual_style}
	  ? ( " (", $res->{actual_style}, ")" ) : (),
	  $res->{key} ? ( "; key: ", $res->{key} ) : (),
	  $res->{actual_tempo}
	  ? ( "; tempo: ", $res->{actual_tempo} ) : (),
	  $res->{actual_repeats} && $res->{actual_repeats} > 1
	  ? ( "; repeat: ", $res->{actual_repeats} ) : (),
	  "</p>\n",
	  start_form( -name => "form" ),
	  "\n",
	  textarea( -name => 'irealbook',
		    -rows => 5, -cols => 100,
		    -style => "font-family:mono",
		    -default => $tokstring ), "\n",
	  "\n",
	  br,
	  submit( -name => "ws", -value => "Show spaces",
		  -onClick => 'document.form.irealbook.value=document.form.irealbook.value.replace(/ /g,"\\u2423");return false' ),
	  "\n",
	  submit( -name => "hs", -value => "Hide spaces",
		  -onClick => 'document.form.irealbook.value=document.form.irealbook.value.replace(/\\u2423/g," ");return false' ),
	  "\n",
	  end_form,
	  "\n",
	  hr,
	  "\n",
	 );
}

print ( end_html );

exit (0);

################ Subroutines ################

sub print_form {
    my $url = "http://" . $ENV{SERVER_NAME} . ":" . $ENV{SERVER_PORT} .
      $ENV{SCRIPT_NAME} . "?uri=%s";
    print <<EOD;
Content-type: text/html

<!DOCTYPE html>
<html>
<head>
  <title>Register iRealPro Protocol Handlers</title>
  <script type="text/javascript">
    navigator.registerProtocolHandler("irealb", "$url", "iRealPro handler");
    navigator.registerProtocolHandler("irealbook", "$url", "iRealPro handler");
  </script>
</head>
<body>
  <h1>Register iRealPro Protocol Handlers</h1>
  <p>The web protocol handlers for
<code>irealb:</code> and <code>irealbook:</code> protocols will be installed.</p>
</body>
</html>
EOD
}

# Obfuscate...
# IN:  [T44C   |G   |C   |G   Z
# OUT: 1r34LbKcu7[T44CXyQ|GXyQ|CXyQ|GXyQZ
sub obfuscate {
    my ( $t ) = @_;
    for ( $t ) {
	s/   /XyQ/g;		# obfuscating substitution
	s/ \|/LZ/g;		# obfuscating substitution
	s/\| x/Kcl/g;		# obfuscating substitution
	$_ = hussle($_);	# hussle
	s/^/1r34LbKcu7/;	# add magix prefix
    }
    $t;
}

# Deobfuscate...
# IN:  1r34LbKcu7[T44CXyQ|GXyQ|CXyQ|GXyQZ
# OUT: [T44C   |G   |C   |G   Z
sub deobfuscate {
    my ( $t ) = @_;
    for ( $t ) {
	s/^1r34LbKcu7//;	# remove magix prefix
	$_ = hussle($_);	# hussle
	s/XyQ/   /g;		# obfuscating substitution
	s/LZ/ |/g;		# obfuscating substitution
	s/Kcl/| x/g;		# obfuscating substitution
    }
    $t;
}

# Symmetric husseling.
sub hussle {
    my ( $string ) = @_;
    my $result = '';

    while ( length($string) > 50 ) {

	# Treat 50-byte segments.
	my $segment = substr( $string, 0, 50, '' );
	if ( length($string) < 2 ) {
	    $result .= $segment;
	    next;
	}

	# Obfuscate a 50-byte segment.
	$result .= reverse( substr( $segment, 45,  5 ) ) .
		   substr( $segment,  5, 5 ) .
		   reverse( substr( $segment, 26, 14 ) ) .
		   substr( $segment, 24, 2 ) .
		   reverse( substr( $segment, 10, 14 ) ) .
		   substr( $segment, 40, 5 ) .
		   reverse( substr( $segment,  0,  5 ) );
    }

    return $result . $string;
}
