#!perl -T

use Test::More tests => 6;

BEGIN {
	use_ok( 'Font::TTF' );
	use_ok( 'PDF::API2' );
	use_ok( 'Config::Tiny' );
	use_ok( 'Data::Struct' );
	use_ok( 'Text::CSV_XS' );
	use_ok( 'Imager' );
}

diag( "Good. We can generate PDF and pixel images." );
