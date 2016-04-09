#! perl

use strict;
use warnings;
use Module::Build;
use 5.010;

my $build = Module::Build->new
  (
   module_name          => 'Data::iRealPro',
   dist_version_from    => 'lib/Data/iRealPro.pm',
   configure_requires   =>
   {
    'Module::Build'   => 0.42,
   },
   build_requires       =>
   {
    'Test::More'      => 0,
   },
   requires             =>
   {
    'PDF::API2'	      => 0,
    'Font::TTF'	      => 0,
    'Imager'	      => 0,
    'Config::Tiny'    => 0,
    'Data::Struct'    => 0,
    'Text::CSV_XS'    => 0,
    'Template::Tiny'  => 0,
    'Imager'	      => 0,
   },
  );

$build->create_build_script;

1;
