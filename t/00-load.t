#!perl -T

my @modules;

BEGIN {
    @modules = 	( 'Data::iRealPro',
		  'Data::iRealPro::SongData',
		  'Data::iRealPro::Tokenizer',
		  'Data::iRealPro::Playlist',
		  'Data::iRealPro::URI',
		  'Data::iRealPro::Parser',
		  'Data::iRealPro::Imager',
		  'Data::iRealPro::JSON',
		);
}

use Test::More tests => scalar @modules;

BEGIN {
    use_ok($_) foreach @modules;
}

diag( "Testing Data::iRealPro $Data::iRealPro::VERSION, Perl $], $^X" );
