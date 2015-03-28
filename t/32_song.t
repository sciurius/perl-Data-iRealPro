#! perl

use strict;
use warnings;
use Test::More tests => 3;
use utf8;

BEGIN { use_ok( 'Music::iRealPro::Song' ) }

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

output 'plain';
is( Music::iRealPro::Song::irealbook . "\n", <<EOD, "resulting song" );
irealbook://All Of Me=Marks Gerald=Rock Ballad=C==[T44<*72All Of Me 1>C   |C   |E7   |E7   |A7   |A7   |D-7   |D-7   |E7   |E7   |A-7   |A-7   |D7   |D7   |D-7   |G7   ][<*72All Of Me 2>C   |C   |E7   |E7   |A7   |A7   |D-7   |D-7   |D-7   |Ebo7   |E-7   |A9   |Do7   |G13   |C Ebo7 |D-7 G7 Z 
EOD

output 'text';
is( Music::iRealPro::Song::irealbook . "\n", <<EOD, "resulting song" );
irealbook://All%20Of%20Me%3DMarks%20Gerald%3DRock%20Ballad%3DC%3D%3D%5BT44%3C*72All%20Of%20Me%201%3EC%20%20%20%7CC%20%20%20%7CE7%20%20%20%7CE7%20%20%20%7CA7%20%20%20%7CA7%20%20%20%7CD-7%20%20%20%7CD-7%20%20%20%7CE7%20%20%20%7CE7%20%20%20%7CA-7%20%20%20%7CA-7%20%20%20%7CD7%20%20%20%7CD7%20%20%20%7CD-7%20%20%20%7CG7%20%20%20%5D%5B%3C*72All%20Of%20Me%202%3EC%20%20%20%7CC%20%20%20%7CE7%20%20%20%7CE7%20%20%20%7CA7%20%20%20%7CA7%20%20%20%7CD-7%20%20%20%7CD-7%20%20%20%7CD-7%20%20%20%7CEbo7%20%20%20%7CE-7%20%20%20%7CA9%20%20%20%7CDo7%20%20%20%7CG13%20%20%20%7CC%20Ebo7%20%7CD-7%20G7%20Z%20
EOD
