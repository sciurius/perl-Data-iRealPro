#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Music::iRealBook' );
}

diag( "Testing Music::iRealBook $Music::iRealBook::VERSION, Perl $], $^X" );
