#! perl

use strict;
use warnings;
use Test::More tests => 2;
use utf8;

BEGIN { use_ok( 'Music::iRealPro::Song' ) }

song "You're Still The One";
composer "Shania Twain";
key "D";
tempo 120;
# Capo 1

# Set a default style.
style "Rock Ballad";

section "Intro";

repeat { D 4; chord "D", "Maj/F#", 4; G; A; };

section "A";

repeat { D 4; chord "D", "Maj/F#", 4; G; A; };

section "B";

D 4; chord "D", "Maj/F#", 4; G; A; 
repeat { D 4; G; A; A; };

section "C";

Segno;

repeat { D 4; G; Em; A; D 4; G; A; ending { G } 1; space 12; ending { A } };

section "D";

repeat { D 4; G; A; A; };

DS_al_Coda;

section "Coda";

D 4; chord "D", "Maj/F#", 4; G; A; 

output "plain";
is( Music::iRealPro::Song::irealbook . "\n", <<EOD, "resulting song" );
irealbook://You're Still The One=Shania Twain=Rock Ballad=D==[T44*i{D   |D/F#   |G   |A   }[*A{D   |D/F#   |G   |A   }[*B,D   |D/F#   |G   |A   {|D   |G   |A   |A   }[*C,S{D   |G   |E-   |A   |D   |G   |A   |N1,G   }            |N2,A   ][*D{D   |G   |A   |A   }<D.S. al Coda>][Q,D   |D/F#   |G   |A   Z 
EOD
