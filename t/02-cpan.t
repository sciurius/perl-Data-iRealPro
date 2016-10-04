#!perl -T

use Test::More tests => 1;

SKIP: {
    eval { require Imager };
    skip "No Imager, we cannot generate pixel images", 1 if $@;
    my $im = Imager->new;
    isa_ok( $im, 'Imager' );
    diag( "Good. We can generate pixel images." );
}
