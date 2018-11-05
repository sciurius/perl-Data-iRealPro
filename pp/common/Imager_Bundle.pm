#! perl

# Dummy for the packager, to get output backends and other
# conditionally required modules included.

use Imager;
use Imager::Expr::Assem;
use Imager::Preprocess;
use Imager::Transform;
use Imager::Matrix2d;
use Imager::Font;
use Imager::Fill;
use Imager::File::SGI;
use Imager::File::JPEG;
use Imager::File::GIF;
use Imager::File::ICO;
use Imager::File::CUR;
use Imager::File::PNG;
use Imager::File::TIFF;
use Imager::Filter::Mandelbrot;
use Imager::Filter::DynTest;
use Imager::Filter::Flines;
use Imager::Regops;
use Imager::Color;
use Imager::CountColor;
use Imager::ExtUtils;
use Imager::Expr;
use Imager::Font::T1;
use Imager::Font::Wrap;
use Imager::Font::FreeType2;
use Imager::Font::Type1;
use Imager::Font::Truetype;
use Imager::Font::Image;
use Imager::Font::FT2;
use Imager::Font::Test;
use Imager::Font::BBox;
use Imager::Color::Float;
use Imager::Color::Table;
use Imager::Probe;
use Imager::Fountain;

1;
