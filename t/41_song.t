#! perl

use strict;
use warnings;
use Test::More tests => 2;
use utf8;

BEGIN { use_ok( 'Music::iRealPro::Song' ) }

output "plain" if @ARGV;

song "A015: Venice - The Family Tree";
composer "Lennons";
key "D";
tempo 80;
style "Medium Swing";

section "Intro";

D 2; Fism; G; Fism; G; Fism; A; D;

section "A";			# Verse

D 2; Fism; G; D; G; D; E; A;
D 2; Fism; G; D; G; D; A; D;

timesig 2,4; D 2;

section "B";			# Chorus

Bm 2; A; G; D; G; D; E; A;
Bm 2; A; G; D; Em; A; Bm; A;
Em 2; A; Coda;

section "C";			# Intermezzo

D 2; Fism; G; Fism; G; Fism; A; D;

section "Coda";

D 4;
Em 2; A;
# Here we have a 2 beat B- followed by a B-/A + Fermata.
# Emulate with 6/4 time signature.
timesig 6,4; Bm 2; chord "B Min/A 4"; space;

timesig 4,4; Em; A;
D 2; Fism; G; Fism; G; Fism; A; D;

output "plain";
is( Music::iRealPro::Song::irealbook . "\n", <<EOD, "resulting song" );
irealbook://A015: Venice - The Family Tree=Lennons=Rock Ballad=D==[T44*i,D F#- |G F#- |G F#- |A D ][*A,D F#- |G D |G D |E A |D F#- |G D |G D |A D |T24,D ]              [*B,B- A |G D |G D |E A |B- A |G D |E- A |B- A |E- A,Q ]            [*C,D F#- |G F#- |G F#- |A D ][Q,D   |E- A |T64,B- B-/A     |T44,E- A |D F#- |G F#- |G F#- |A D Z 
EOD
