#!/usr/bin/perl

# Read and convert iRealPro data

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Mon Aug  1 16:02:03 2016
# Update Count    : 39
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../CPAN";
use lib "$FindBin::Bin/../lib";
use Data::iRealPro;

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( irealcvt 0.05 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Process command line options.
my $options = app_options();

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

main($options);

################ Subroutines ################

sub main {
    my ($options) = @_;
    die("Only one input allowed with --output\n")
      if $options->{output} && @ARGV > 1;
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');
    foreach my $file ( @ARGV ) {
	my $s;
	if ( $options->{output} =~ /\.jso?n$/i ) {
	    require Data::iRealPro::JSON;
	    $s = Data::iRealPro::JSON->new( $options );
	}
	else {
	    require Data::iRealPro::Imager;
	    $s = Data::iRealPro::Imager->new( $options );
	}
	$s->parsefile( $file, $options );
    }
}

exit 0;

################ Subroutines ################

sub app_options {

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    my $o = { output   => "__new__.pdf",
	      trace    => 0,
	      debug    => 0,
	      test     => 0,
	      verbose  => 0,
	      ident    => 0,
	    };

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions( $o,
		    'ident',
		    'output=s',
		    'transpose=i',
		    'toc',
		    'verbose',
		    'trace',
		    'help|?',
		    'man',
		    'debug',
		  ) or $pod2usage->(2);
    }
    if ( $o->{ident} or $o->{help} or $o->{man} ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $o->{man} or $o->{help} ) {
	$pod2usage->(1) if $o->{help};
	$pod2usage->(VERBOSE => 2) if $o->{man};
    }

    # Post-processing.
    $o->{trace} |= ( $o->{debug} || $o->{test} );

    return $o;
}

__END__

################ Documentation ################

=head1 NAME

irealcvt - convert iRealPro data files

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   --output=XXX		output file and type
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information

=head1 OPTIONS

=over 8

=item B<--output=>I<FILE.EXT>

Designates the output file. The filename extension determines the type
of the output.

Currently recognized: C<pdf>, C<png> and C<json>.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.

=item I<file>

The input file(s) to process, if any.

=back

=head1 DESCRIPTION

B<irealcvt> will process given input file(s) and produce a nice PDF, PNG or JSON document.

For more information, see L<Data::iRealPro>.

=cut
