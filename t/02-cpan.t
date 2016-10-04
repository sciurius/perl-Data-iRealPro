#!perl -T

use Test::More tests => 2;

SKIP: {
    eval { require Imager };
    skip "No Imager, we cannot generate pixel images", 1 if $@;
    my $im = Imager->new;
    isa_ok( $im, 'Imager' );
    diag( "Good. We can generate pixel images." );
}

chdir("t") if -d "t";

SKIP: {
    skip "Sorry, no NPP pixel images", 1
      unless -s "../res/prefab/hand/root_c.png";
    ok( -s "../res/prefab/hand/coda.png", 'NPP prefab images' );
    diag( "Good. We can generate NPP pixel images." );
}
