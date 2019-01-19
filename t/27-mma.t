#!perl -T

use strict;
use Test::More tests => 8;

BEGIN {
    use_ok( 'Data::iRealPro' );
    use_ok( 'Data::iRealPro::URI' );
    use_ok( 'Data::iRealPro::Output::MMA' );
}

my $u = Data::iRealPro::URI->new;
ok( $u, "Create URI object" );

my $be = Data::iRealPro::Output::MMA->new;
ok( $be, "Create MMA backend" );

my $data = <<EOD;
<a href="irealb://You're%20Still%20The%20One%3DTwain%20Shania%3D%3DRock%20Ballad%3DC%3D0%3D1r34LbKcu7L%23F/D4DLZD%7D%20AZLGZL%23F/DZLAD*%7B%0A%7D%20AZLGZL%23F/%0A%7CDLZ4Ti*%7BDZLAZLZSDLGZLDB*%7B%0A%5D%20AZLALZGZLDZLAZLAZLGZLZE-LAZLGZ%23F/DZALZN1%5D%20%3EadoC%20la%20.S.%3CD%20A2N%7CQyXQyX%7D%20G%0A%5BQDLZLGZLLZGLZfA%20Z%20%3D%3D155%3D0">You're Still The One</a>
EOD

$u->parse($data);
ok( $u->{playlist}, "Got playlist" );
my $pl = $u->{playlist};
is( scalar(@{$pl->{songs}}), 1, "Got one song" );

my $res;
$be->process( $u, { output => \$res } );
my $me = "Data::iRealPro $Data::iRealPro::VERSION";
my $exp = <<EOD;
// Title: You're Still The One
// Style: Rock Ballad
// Composer: Shania Twain
// Converted from iReal by $me

MIDIText You're Still The One
MIDIText MMA input generated by $me

KeySig C major
Time 4
TimeSig 4/4
Tempo 155

Set SongForms 3

Label Capo

// Section: Intro
Groove CountrySwing
Repeat
  1 D
  2 D/F#
  3 G
  4 A
RepeatEnd

Repeat         // song form

// Section: A
Groove CountrySwing
Repeat
  5 D
  6 D/F#
  7 G
  8 A
RepeatEnd
  9 D
 10 D/F#
 11 G
 12 A
Label Segno
 13 D
 14 G
 15 A
 16 A
 17 D
 18 G
 19 A
 20 A

// Section: B
Groove CountrySwing
Repeat
 21 D
 22 G
 23 Em
 24 A
 25 D
 26 G
 27 A
RepeatEnding
 28 G
RepeatEnd
 29 A   /* D.S. al Coda */

// Section: Coda
Label Coda
Groove CountrySwing
 30 D
 31 D/F#
 32 G
 33 /* fermata? */ A

RepeatEnd NoWarn \$SongForms
EOD

my @res = split(/\n/, $res);
my @exp = split(/\n/, $exp);

is_deeply( \@res, \@exp, "MMA song content" );

unless ( $res eq $exp ) {
    for ( my $ln = 0; $ln < @res; $ln++ ) {
	printf( "%2d  %-30.30s | %s\n", $ln, $exp[$ln], $res[$ln] );
    }
}
