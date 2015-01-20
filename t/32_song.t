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
irealbook://All Of Me=Marks Gerald=Rock Ballad=n=C=[T44<*72All Of Me 1>C   |C   |E7   |E7   |A7   |A7   |D-7   |D-7   |E7   |E7   |A-7   |A-7   |D7   |D7   |D-7   |G7   ][T44<*72All Of Me 2>C   |C   |E7   |E7   |A7   |A7   |D-7   |D-7   |D-7   |Ebo7   |E-7   |A9   |Do7   |G13   |C Ebo7 |D-7 G7 Z
EOD

output 'text';
is( Music::iRealPro::Song::irealbook . "\n", <<EOD, "resulting song" );
irealbook://All%20Of%20Me%3dMarks%20Gerald%3dRock%20Ballad%3dn%3dC%3d%5bT44%3c*72All%20Of%20Me%201%3eC%20%20%20%7cC%20%20%20%7cE7%20%20%20%7cE7%20%20%20%7cA7%20%20%20%7cA7%20%20%20%7cD-7%20%20%20%7cD-7%20%20%20%7cE7%20%20%20%7cE7%20%20%20%7cA-7%20%20%20%7cA-7%20%20%20%7cD7%20%20%20%7cD7%20%20%20%7cD-7%20%20%20%7cG7%20%20%20%5d%5bT44%3c*72All%20Of%20Me%202%3eC%20%20%20%7cC%20%20%20%7cE7%20%20%20%7cE7%20%20%20%7cA7%20%20%20%7cA7%20%20%20%7cD-7%20%20%20%7cD-7%20%20%20%7cD-7%20%20%20%7cEbo7%20%20%20%7cE-7%20%20%20%7cA9%20%20%20%7cDo7%20%20%20%7cG13%20%20%20%7cC%20Ebo7%20%7cD-7%20G7%20Z
EOD
