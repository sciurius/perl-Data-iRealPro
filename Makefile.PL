#! perl

# Ease the life of the CPAN testers.
exit 0 if $ENV{AUTOMATED_TESTING} && $] < 5.010000;

use ExtUtils::MakeMaker;

my $master = 'lib/Data/iRealPro.pm';
my $version = MM->parse_version($master);

WriteMakefile
(
 NAME		=> 'Data::iRealPro',
 ABSTRACT_FROM  => $master,
 VERSION_FROM	=> $master,
 AUTHOR	        => 'Johan Vromans <jvromans@squirrel.nl>',

 INSTALLDIRS	=> 'site',
 EXE_FILES	=> [ 'script/irealcvt', 'script/splitlist' ],
 PL_FILES	=> {
		    'script/pp.PL' => [ 'script/irealcvt' ],
		    'script/pp.PL' => [ 'script/splitlist' ]
		   },

 PREREQ_PM      => {
		    'PDF::API2'    => 2.020,
		    'Font::TTF'    => 1.04,
		    'Imager'	   => 0,
		    'Data::Struct' => 0,
		    'Text_CSV::XS' => 0,
		    'JSON::PP'	   => 0,
		   },
 TEST_REQUIRES  => {
		    'Test::More'  => 0,
		   },

 META_MERGE => {
     license          => "perl_5",
     resources        => {
	 repository   => {
	     type => 'git',
	     url  => 'git://github.com/sciurius/perl-Data-iRealPro',
	     web  => 'https://github.com/sciurius/perl-Data-iRealPro',
         },
     },
 },

);

1;
