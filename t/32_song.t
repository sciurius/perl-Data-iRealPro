#! perl

use strict;
use warnings;
use Test::More tests => 2;
use utf8;

BEGIN { use_ok( 'Music::iRealBook::Song' ) }

song "All Of Me";
composer "Marks Gerald";
key "C";
tempo 105;
style "Medium Swing";

section "All Of Me 1";

C 4; C; E7; E7;
A7; A7; Dm7; Dm7;
E7; E7; Am7; Am7;
D7; D7; Dm7; G7;

section "All Of Me 2";

C 4; C; E7; E7;
A7; A7; Dm7; Dm7;
Dm7; Ebdim7; Em7; A9;
Ddim7; G13;
C 2; Ebdim7; Dm7; G7;

is( Music::iRealBook::Song::irealbook(1)."\n", <<EOD, "resulting song" );
EOD
