#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Music::iRealPro' );
}

diag( "Testing Music::iRealPro $Music::iRealPro::VERSION, Perl $], $^X" );
