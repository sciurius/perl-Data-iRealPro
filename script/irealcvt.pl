#!/usr/bin/perl

# ireal2cvt -- convert iRealPro song data

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Fri Sep 30 20:45:48 2016
# Update Count    : 65
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../CPAN";
use lib "$FindBin::Bin/../lib";
use Data::iRealPro;
use Data::iRealPro::Output;

################ Setup  ################

# Process command line options, config files, and such.
my $options;
$options = app_setup("ireal2pdf", $Data::iRealPro::VERSION);

################ Presets ################

$options->{trace} = 1   if $options->{debug};
$options->{verbose} = 1 if $options->{trace};

################ Activate ################

main($options);

################ The Process ################

sub main {
    my ($options) = @_;
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');

    Data::iRealPro::Output->new($options)->processfiles(@ARGV);
}

################ Options and Configuration ################

use Getopt::Long 2.13 qw( :config no_ignorecase );
use File::Spec;
use Carp;

# Package name.
my $my_package;
# Program name and version.
my ($my_name, $my_version);
my %configs;

sub app_setup {
    my ($appname, $appversion, %args) = @_;
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Package name.
    $my_package = $args{package};
    # Program name and version.
    if ( defined $appname ) {
	($my_name, $my_version) = ($appname, $appversion);
    }
    else {
	($my_name, $my_version) = qw( MyProg 0.01 );
    }

    %configs =
      ( sysconfig  => File::Spec->catfile ("/", "etc", lc($my_name) . ".conf"),
	userconfig => File::Spec->catfile($ENV{HOME}, ".".lc($my_name), "conf"),
	config     => "." . lc($my_name) .".conf",
#	config     => lc($my_name) .".conf",
      );

    my $options =
      {
       verbose		=> 0,		# verbose processing

       ### ADD OPTIONS HERE ###

       output		=> undef,
       transpose	=> 0,
       toc		=> undef,

       # Development options (not shown with -help).
       debug		=> 0,		# debugging
       trace		=> 0,		# trace (show process)

       # Service.
       _package		=> $my_package,
       _name		=> $my_name,
       _version		=> $my_version,
       _stdin		=> \*STDIN,
       _stdout		=> \*STDOUT,
       _stderr		=> \*STDERR,
       _argv		=> [ @ARGV ],
      };

    # Colled command line options in a hash, for they will be needed
    # later.
    my $clo = {};

    # Sorry, layout is a bit ugly...
    if ( !GetOptions
	 ($clo,

	  ### ADD OPTIONS HERE ###

	  'output=s',
	  'select=i',
	  'npp=s',
	  'transpose|x=i',
	  'toc!',

	  # # Configuration handling.
	  # 'config=s',
	  # 'noconfig',
	  # 'sysconfig=s',
	  # 'nosysconfig',
	  # 'userconfig=s',
	  # 'nouserconfig',
	  # 'define|D=s%' => sub { $clo->{$_[1]} = $_[2] },

	  # Standard options.
	  'ident'		=> \$ident,
	  'help|h|?'		=> \$help,
	  'verbose',
	  'trace',
	  'debug',
	 ) )
    {
	# GNU convention: message to STDERR upon failure.
	app_usage(\*STDERR, 2);
    }
    # GNU convention: message to STDOUT upon request.
    app_usage(\*STDOUT, 0) if $help;
    app_ident(\*STDOUT) if $ident;

=begin later

    # If the user specified a config, it must exist.
    # Otherwise, set to a default.
    for my $config ( qw(sysconfig userconfig config) ) {
	for ( $clo->{$config} ) {
	    if ( defined($_) ) {
		croak("$_: $!\n") if ! -r $_;
		next;
	    }
	    $_ = $configs{$config};
	    undef($_) unless -r $_;
	}
	app_config($options, $clo, $config);
    }

=cut

    # Plug in command-line options.
    @{$options}{keys %$clo} = values %$clo;

    $options;
}

sub app_ident {
    my ($fh) = @_;
    print {$fh} ("This is ",
		 $my_package
		 ? "$my_package [$my_name $my_version]"
		 : "$my_name version $my_version",
		 "\n");
}

sub app_usage {
    my ($fh, $exit) = @_;
    app_ident($fh);
    print ${fh} <<EndOfUsage;
Usage: $0 [ options ] [ ... ]

    --output=XXX	Desired output file name.
			File name extension controls the output type.
			Supported types: json (raw data), txt (editable text),
			html, pdf and png.
    --select=NN		Select a single song from a playlist.
    --npp=XXX		Near pixel-perfect iRealPro output.
			Choose 'hand' or 'standard'.
			Add '-' for '-' instead of 'm' for minor.
    --transpose=[+-]NN  -x	Transpose up/down semitones.
    --[no]toc		Produces [suppresses] the table of contents.
			A ToC is automatically generated if a playlist
			contains more than one song. [PDF only]

Miscellaneous options:
    --help  -h		this message
    --ident		show identification
    --verbose		verbose information
EndOfUsage

=begin later

Configuration options:
    --config=CFG	project specific config file ($configs{config})
    --noconfig		don't use a project specific config file
    --userconfig=CFG	user specific config file ($configs{userconfig})
    --nouserconfig	don't use a user specific config file
    --sysconfig=CFG	system specific config file ($configs{sysconfig})
    --nosysconfig	don't use a system specific config file
    --define key=value  define or override a configuration option
Missing default configuration files are silently ignored.

=cut

    exit $exit if defined $exit;
}

=begin later

use Config::Tiny;

sub app_config {
    my ($options, $opts, $config) = @_;
    return if $opts->{"no$config"};
    my $cfg = $opts->{$config};
    return unless defined $cfg && -s $cfg;
    my $verbose = $opts->{verbose} || $opts->{trace} || $opts->{debug};
    warn("Loading $config: $cfg\n") if $verbose;

    my $c = Config::Tiny->read( $cfg, 'utf8' );

    # Process config data, filling $options ...

    foreach ( keys %$c ) {
	foreach ( keys %$_ ) {
	    s;^~/;$ENV{HOME}/;;
	}
    }

    my $store = sub {
	my ( $sect, $key, $opt ) = @_;
	eval {
	    $config->{$opt} = $c->{$sect}->{$key};
	};
    };

}

=cut

1;
