#!perl -T

use Test::More tests => 7;

BEGIN {
	use_ok( 'Data::iRealPro' );
	use_ok( 'Data::iRealPro::SongData' );
	use_ok( 'Data::iRealPro::Tokenizer' );
	use_ok( 'Data::iRealPro::Playlist' );
	use_ok( 'Data::iRealPro::URI' );
	use_ok( 'Data::iRealPro::Parser' );
	use_ok( 'Data::iRealPro::Imager' );
}

diag( "Testing Data::iRealPro $Data::iRealPro::VERSION, Perl $], $^X" );
