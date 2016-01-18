#! perl

# iReal2pdf -- print iRealPro songs

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jan 18 23:21:57 2016
# Update Count    : 424
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Music::iRealPro::PDF;

our $VERSION = "0.01";

use Music::iRealPro::URI;
use Music::iRealPro::Tokenizer;
use Data::Dumper;
use PDF::API2::Tweaks;
use Text::CSV;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant debug ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    # Add font dirs.
    my $fontdir = $ENV{FONTDIR};
    if ( !$fontdir && $ENV{HOME} && -d $ENV{HOME} . "/.fonts" ) {
       $fontdir = $ENV{HOME} . "/.fonts";
    }
    if ( $fontdir && -d $fontdir ) {
	PDF::API2::addFontDirs($fontdir);
    }
    else {
	undef $fontdir;
    }

    return $self;
}

sub parsefile {
    my ( $self, $file, $options ) = @_;

    open( my $fd, '<', $file ) or die("$file: $!\n");

    my $data = do { local $/; <$fd> };
    # Extract URL.
    $data =~ s;^.*(irealb(?:ook)?://.*?)(?:$|\").*;$1;s;
    $data = "irealbook://" . $data
      unless $data =~ m;^(irealb(?:ook)?://.*?);;

    my $u = Music::iRealPro::URI->new( data => $data,
				       debug => $self->{debug} );
    my $plname = $u->{playlist}->{name};
    if ( $plname ) {
	if ( $self->{output} && $self->{output} !~ /\.pdf$/i ) {
	    die("Can only generate PDF for playlist\n");
	}
	warn( "PLAYLIST: $plname, ",
	      scalar(@{ $u->{playlist}->{songs} }), " songs\n" )
	  if $options->{verbose};
	( my $t = $plname ) =~ s/[ \/:"]/_/g;
	$self->{output} ||= "$t.pdf";
    }
    $self->{output} ||= "__new__.pdf";

    $self->{songbook} = [];
    $self->{pdf} = PDF::API2->new;
    my $pageno = 1;

    my $csv;
    my $csv_fd;
    my $csv_name;
    if ( $self->{output} =~ /\.pdf$/i ) {
	my $csv_name = $self->{output};
	$csv_name =~ s/\.pdf$/.csv/i;
	open( $csv_fd, ">:encoding(utf8)", $csv_name );
	$csv = Text::CSV->new( { binary => 1,
				 quote_space => 0,
				 sep_char => ";" } );
	$csv->print( $csv_fd,
		     [ qw( title pages keys composers
			   collections ), "source types" ] );
	$csv_fd->print("\n");
    }

    # Process the song(s).
    foreach my $song ( @{ $u->{playlist}->{songs} } ) {
	my $res = $self->decode_song($song->{data});
	my $m = $self->make_cells( $song, $res );
	if ( $self->{output} =~ /\.png$/i ) {
	    $self->make_png( $song, $m );
	    next;
	}
	my $numpages = $self->make_pdf( $song, $m );
	my $pages = $pageno;
	if ( $numpages > 1 ) {
	    $pages .= "-" . ( $pageno + $numpages - 1 );
	    $pageno += $numpages;
	}
	else {
	    $pageno++;
	}
	my $key = $song->{key};
	$key =~ s/-$/m/;
	my $composer = $song->{composer};
	$composer = "$2 $1" if $composer =~ /^(.+?) +([^ ]+)$/;
	$csv->print( $csv_fd,
		     [ $song->{title},
		       $pages,
		       $key,
		       $composer,
		       $plname,
		       "Sheet Music",
		     ] );
	$csv_fd->print("\n");
    }
    if ( $self->{output} =~ /\.pdf$/i ) {
	$self->{pdf}->saveas($self->{output});
	warn("Wrote: ", $self->{output}, "\n") if $self->{verbose};
	$csv_fd->close;
	warn("Wrote: $csv_name\n") if $self->{verbose};
    }
}

sub decode_song {
    my ( $self, $str ) = @_;

    # Build the tokens array. This reflects as precisely as possible
    # the contents of the pure data string.
    my $tokens = Music::iRealPro::Tokenizer->new
      ( debug   => $self->{debug},
	variant => $self->{variant},
      )->tokenize($str);

    return $tokens;
}

use Data::Struct;

my @fields = qw( vs sz chord subchord text mark sign time lbar rbar alt );

sub make_cells {
    my ( $self, $song, $tokens ) = @_;

    if ( $self->{debug} ) {
	warn(Dumper($song));
	warn(Dumper($tokens));
    }

    struct Cell => @fields;
    my $cells = [];
    my $cell;
    my $chordsize = 0;		# normal
    my $vspace = 0;		# normal

    my $new_cell = sub {
	$cell = struct "Cell";
	$cell->sz = $chordsize if $chordsize;
	$cell->vs = $vspace if $vspace;
	push( @$cells, $cell );
    };

    my $new_measure = sub {
	$cells->[-2]->rbar ||= "barlineSingle";
	$cells->[-1]->lbar ||= "barlineSingle";
    };

    $new_cell->();		# TODO section? measure?

    foreach my $t ( @$tokens ) {

	if ( $t eq "start section" ) {
	    $cell->lbar = "barlineDouble";
	    next;
	}

	if ( $t eq "start repeat" ) {
	    $cell->lbar = "repeatLeft";
	    next;
	}

	if ( $t eq "end repeat" ) {
	    $cells->[-2]->rbar = "repeatRight";
	    # TODO $new_cell->() if $x >= $rm;
	    next;
	}

	if ( $t =~ /time (\d+)\/(\d+)/ ) {
	    $cell->time = [ $1, $2 ];
	    next;
	}

	if ( $t =~ /^hspace\s+(\d+)$/ ) {
	    $new_cell->() for 1..$1;
	    next;
	}

	if ( $t eq "end" ) {
	    $cells->[-2]->rbar = "barlineFinal";
	    pop(@$cells);
	    last;
	}

	if ( $t eq "end section" ) {
	    $cells->[-2]->rbar = "barlineDouble";
	    next;
	}

	if ( $t eq "bar" ) {
	    $new_measure->();
	    next;
	}

	if ( $t =~ /^(segno|coda|fermata)$/ ) {
	    $cell->sign = $1;
	    next;
	}

	if ( $t =~ /^chord\s+(.*)$/ ) {
	    my $c = $1;

	    if ( $c =~ s/\((.+)\)// ) {
		if ( $c ) {
		    $cell->subchord = $1;
		}
		else {
		    $cells->[-2]->subchord = $1;
		    next;
		}
	    }

	    $cell->chord = $c;
	    $new_cell->();
	    next;
	}

	if ( $t =~ /^alternative\s+(\d)$/ ) {
	    $cell->alt = $1;
	}

	if ( $t eq "small" ) {
	    $cell->sz = $chordsize = 1;
	    next;
	}

	if ( $t eq "large" ) {
	    $cell->sz = $chordsize = 0;
	    next;
	}

	if ( $t =~ /^mark (.)/ ) {
	    $cell->mark = $1;
	    next;
	}

	if ( $t =~ /^text\s+(\d+)\s(.*)/ ) {
	    $cell->text =  [ $1, $2 ];
	    next;
	}

	if ( $t =~ /^advance\s+(\d+)$/ ) {
	    $new_cell->() for 1..$1;
	    next;
	}

	if ( $t =~ /^measure repeat (single|double)$/ ) {
	    my $c = $1 eq "single" ? "repeat1Bar" : "repeat2Bars";
	    $cell->chord = $c;
	    $new_cell->();
	    next;
	}

	if ( $t =~ /^slash repeat$/ ) {
	    $cell->chord = "repeatSlash";
	    $new_cell->();
	    next;
	}

	next;

    }
    warn Dumper($cells);
    warn('$DATA = "', $song->{data}, "\";\n");
    return $cells;
}

my %smufl =
  ( brace		=> "\x{e000}",
    reversedBrace	=> "\x{e001}",
    barlineSingle	=> "\x{e030}",
    barlineDouble	=> "\x{e031}",
    barlineFinal	=> "\x{e032}",
    repeatLeft		=> "\x{e000}\x{e043}",
#    repeatLeft		=> "\x{e040}",
#    repeatRight		=> "\x{e041}",
    repeatRight		=> "\x{e043}\x{e001}",
    repeatDots		=> "\x{e043}",
    dalSegno		=> "\x{e045}",
    daCapo		=> "\x{e046}",
    segno		=> "\x{e047}",
    coda		=> "\x{e048}",
    timeSig0		=> "\x{e080}", # timeSig1, ...etc...
    fermata		=> "\x{e4c0}",
    repeat1Bar		=> "\x{e500}",
    repeat2Bars		=> "\x{e501}",
    repeat4Bars		=> "\x{e502}",
    csymDiminished	=> "\x{e870}",
    csymHalfDiminished	=> "\x{e871}",
    csymAugmented	=> "\x{e872}",
    csymMajorSeventh	=> "\x{e873}",
    csymMinor		=> "\x{e874}",
  );

my $numrows = 16;
my $numcols = 16;

sub make_pdf {
    my ( $self, $song, $cells ) = @_;

    my $pdf = $self->{pdf};
    my $page;
    my $text;
    my $titlefont = $pdf->corefont("Helvetica-Bold");
#    my $textfont = $pdf->corefont("TimesRoman");
    my $textfont = $pdf->corefont("Helvetica");
#    my $chordfont = $pdf->corefont("Helvetica-Bold");
    my $chordfont = $pdf->ttfont("Myriad-CnSemibold.ttf");
    my $markfont = $pdf->corefont("Helvetica-Bold");
    my $musicfont = $pdf->ttfont("Bravura.otf");
    my $musicsize = 20;
    my $musicglyphs = \%smufl;
    my $tm = 720;
    my $lm = 40;
    my $bm = 50;
    my $rm = 560;
    my $dx = ( $rm - $lm ) / $numcols;
    my $dy = ( $tm - $bm ) / $numrows;
    my $x = $lm;
    my $y = $tm;

    my $pages;

    my $newpage = sub {
	$pages++;
	$page = $pdf->page;
	$page->mediabox('A4');	# 595 x 842
	$text = $page->text;
	$text->font( $titlefont, 20);
	$text->textcline( ($lm+$rm)/2-3, $tm+80, $song->{title} );
	$text->font( $textfont, 17);
	$text->textline( $lm-3, $tm+50, $song->{composer} );
	$text->textrline( $rm+3, $tm+50, "(".$song->{style}.")" )
	  if $song->{style};
    };

    our $glyph = sub {
	my ( $x, $y, $smc, $size ) = @_;
	$text->font( $musicfont, $size || $musicsize );
	Carp::confess("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	$text->textcline( $x, $y-3, $musicglyphs->{$smc} );
    };

    my $glyphl = sub {
	my ( $x, $y, $smc, $size ) = @_;
	$text->font( $musicfont, $size || $musicsize );
	die("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	$text->textline( $x, $y-3, $musicglyphs->{$smc} );
    };

    my $glyphx = sub {
	$text->fillcolor("#ff0000");
	$glyph->(@_);
	$text->fillcolor("#000000");
    };

    for ( my $i = 0; $i < @$cells; $i++ ) {

	my $onpage = $i % ( $numrows * $numcols );
	if ( !$onpage ) {
	    $newpage->();
	}

	my $cell = $cells->[$i];

	$x = $lm + ( $onpage % $numcols ) * $dx;
	$y = $tm - int( $onpage / $numcols ) * $dy;

	for ( $cell->lbar ) {
	    next unless $_;
	    if ( /repeatLeft/ ) {
		$glyphx->( $x, $y, "repeatLeft" );
	    }
	    else {
		$glyph->( $x, $y, $_ );
	    }
	    next;
	}

	for ( $cell->rbar ) {
	    next unless $_;
	    if ( /repeatRight/ ) {
		$glyphx->( $x+$dx, $y, "repeatRight" );
	    }
	    else {
		$glyph->( $x+$dx, $y, $_ );
	    }
	    next;
	}

	for ( $cell->time ) {
	    next unless $_;
	    my ( $t1, $t2 ) = @$_;
	    $text->font( $musicfont, 14 );
	    $text->fillcolor("#ff0000");
	    my $w = $text->advancewidth( $musicglyphs->{timeSig0} ) / 2;
	    my $x = $x - $w - 3;
	    $x -= $w if $t1 > 10 || $t2 > 10;
	    $w = ord( $musicglyphs->{timeSig0} ) - ord("0");
	    $t1 =~ s/(\d)/sprintf( "%c",$w+ord($1) )/ge;
	    $t2 =~ s/(\d)/sprintf( "%c",$w+ord($1) )/ge;
	    $text->textcline( $x, $y+11, $t1 );
	    $text->textcline( $x, $y+3, $t2 );
	    $text->fillcolor("#000000");
	    next;
	}

	for ( $cell->sign ) {
	    next unless $_;
	    local $glyph = $glyphl;
	    $glyphx->( $x+3, $y+$musicsize+4, $_, $musicsize*0.7 );
	    next;
	}

	for ( $cell->chord ) {
	    next unless $_;
	    my $c = $_;

	    my $chordsize = $cell->sz ? 14 : 20;
	    if ( $c =~ /^repeat(1Bar|2Bars)$/ ) {
		$text->font( $musicfont, $chordsize );
		$text->textline( $x+3, $y+5, $musicglyphs->{$c} );
		next;
	    }
	    if ( $c =~ /^repeat(Slash)$/ ) {
		$text->font( $chordfont, $chordsize );
		$text->textline( $x+8, $y, "/" );
		next;
	    }

	    $c =~ s/(?:\*m\*|-)/m/;
	    $text->font( $chordfont, $chordsize );
	    $text->translate( $x+3, $y );
	    $text->text($c);
	    next;
	}

	for ( $cell->subchord ) {
	    next unless $_;
	    my $a = $_;
	    $a =~ s/(?:\*m\*|-)/m/;
	    $text->font( $chordfont, 14 );
	    $text->translate( $x+3, $y+20 );
	    $text->text($a);
	    next;
	}

	for ( $cell->alt ) {
	    next unless $_;
	    my $n = $_;
	    $text->font( $textfont, 12 );
	    $text->fillcolor("#ff0000");
	    $text->textline( $x+3, $y+20, $n . "." );
	    $text->fillcolor("#000000");
	    my $gfx = $page->gfx;
	    $gfx->save;
	    $gfx->strokecolor("#ff0000");
	    $gfx->move( $x+2, $y+20 );
	    $gfx->linewidth(1);
	    $gfx->line( $x+2, $y+30 );
	    $gfx->line( $x+2*$dx, $y+30 );
	    $gfx->stroke;
	    $gfx->restore;
	    next;
	}

	for ( $cell->mark ) {
	    next unless $_;
	    my $t = $_;
	    $text->font( $markfont, 12 );
	    $t = "Intro" if $t eq 'i';
	    $t = "Verse" if $t eq 'v';
	    $text->fillcolor("#ff0000");
	    $text->textline( $x-6, $y+22, $t);
	    $text->fillcolor("#000000");
	    next;
	}

	for ( $cell->text ) {
	    next unless $_;
	    my ( $disp, $t ) = @$_;
	    $text->font( $textfont, 10);
	    $text->fillcolor("#ff0000");
	    $text->textline( $x, $y+($disp/3), $t );
	    $text->fillcolor("#000000");
	    next;
	}

	next;

    }

    $song->{pages} = $pages;
}

sub scale($) { 2*$_[0] }

sub make_png {
    my ( $self, $song, $cells ) = @_;

    require GD;
    require GD::Image;

    # Create a new image
    my $scale = 2;
    my $im = new GD::Image( scale(595), scale(842) );

    # Allocate some colors
    my $white = $im->colorAllocate(255,255,255);
    my $black = $im->colorAllocate(0,0,0);
    my $red = $im->colorAllocate(255,0,0);

    my $titlefont = $ENV{HOME}."/.fonts/FreeSansBold.ttf";
    my $textfont  = $ENV{HOME}."/.fonts/FreeSans.ttf";
    my $chordfont = $ENV{HOME}."/.fonts/Myriad-CnSemibold.ttf";
    my $musicfont = $ENV{HOME}."/.fonts/Bravura.otf";
    my $markfont  = $titlefont;
    my $musicsize = 20;
    my $musicglyphs = \%smufl;
    my ( $tm, $lm, $bm, $rm) = ( 122,  40, 792, 560 );
    my $dx = ( $rm - $lm ) / $numcols;
    my $dy = ( $bm - $tm ) / $numrows;
    my $x = $lm;
    my $y = $tm;

    $im->setThickness( scale(1) );

    my $pages;

    my $text = sub {
	my ( $x, $y, $font, $size, $t, $col ) = @_;
	$col ||= $black;
	$size ||= $musicsize;
	$size *= 0.72;
	$_ = scale($_) for $x, $y, $size;
	$im->stringFT( $col, $font, $size, 0, $x, $y, $t );
    };

    my $textc = sub {
	my ( $x, $y, $font, $size, $t, $col ) = @_;
	$col ||= $black;
	$size ||= $musicsize;
	$size *= 0.72;
	$_ = scale($_) for $x, $y, $size;
	my @b = GD::Image->stringFT( $col, $font, $size, 0, $x, $y, $t );
	$x -= ($b[2] - $b[0]) / 2;
	$im->stringFT( $col, $font, $size, 0, $x, $y, $t );
    };

    my $textr = sub {
	my ( $x, $y, $font, $size, $t, $col ) = @_;
	$col ||= $black;
	$size ||= $musicsize;
	$size *= 0.72;
	$_ = scale($_) for $x, $y, $size;
	my @b = GD::Image->stringFT( $col, $font, $size, 0, $x, $y, $t );
	$x -= $b[2] - $b[0];
	$im->stringFT( $col, $font, $size, 0, $x, $y, $t );
    };

    my $newpage = sub {
	$pages++;
	$textc->( ($lm+$rm)/2-3, $tm-80, $titlefont, 20, $song->{title} );
	$text->( $lm-3, $tm-50, $textfont, 17, $song->{composer} );
	$textr->( $rm+3, $tm-50, $textfont, 17, "(".$song->{style}.")" )
	  if $song->{style};
    };

    my $glyphc = sub {
	my ( $x, $y, $smc, $size, $col ) = @_;
	Carp::confess("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	#### WHY $x+2????
	$textc->( $x, $y+3, $musicfont, $size || $musicsize, $musicglyphs->{$smc}, $col );
    };
    our $glyph = $glyphc;

    my $glyphl = sub {
	my ( $x, $y, $smc, $size, $col ) = @_;
	Carp::confess("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	$text->( $x, $y+3, $musicfont, $size || $musicsize, $musicglyphs->{$smc}, $col );
    };

    my $glyphx = sub {
	my ( $x, $y, $smc, $size ) = @_;
	$glyph->( $x, $y, $smc, $size, $red );
    };

    for ( my $i = 0; $i < @$cells; $i++ ) {

	my $onpage = $i % ( $numrows * $numcols );
	if ( !$onpage ) {
	    $newpage->();
	}

	my $cell = $cells->[$i];

	$x = $lm + ( $onpage % $numcols ) * $dx;
	$y = $tm + int( $onpage / $numcols ) * $dy;

	for ( $cell->lbar ) {
	    next unless $_;
	    if ( /repeatLeft/ ) {
		$glyphx->( $x, $y, "repeatLeft" );
	    }
	    else {
		$glyph->( $x, $y, $_ );
	    }
	    next;
	}

	for ( $cell->rbar ) {
	    next unless $_;
	    if ( /repeatRight/ ) {
		$glyphx->( $x+$dx, $y, "repeatRight" );
	    }
	    else {
		$glyph->( $x+$dx, $y, $_ );
	    }
	    next;
	}

	for ( $cell->time ) {
	    next unless $_;
	    my ( $t1, $t2 ) = @$_;
	    my @b = GD::Image->stringFT( $red, $musicfont, 14, 0,
					 $x, $y, $musicglyphs->{timeSig0} );
	    my $w = ( $b[2] - $b[0] ) / 2;
	    my $x = $x - $w;
	    $x -= $w - 3 if $t1 > 10 || $t2 > 10;
	    $w = ord( $musicglyphs->{timeSig0} ) - ord("0");
	    $t1 =~ s/(\d)/sprintf( "%c",$w+ord($1) )/ge;
	    $t2 =~ s/(\d)/sprintf( "%c",$w+ord($1) )/ge;
	    $textc->( $x, $y-11, $musicfont, 14, "$t1", $red );
	    $textc->( $x, $y-3,  $musicfont, 14, "$t2", $red );
	    next;
	}

	for ( $cell->sign ) {
	    next unless $_;
	    local $glyph = $glyphl;
	    $glyphx->( $x+3, $y-($musicsize+4), $_, $musicsize*0.7 );
	    next;
	}

	for ( $cell->chord ) {
	    next unless $_;
	    my $c = $_;

	    my $chordsize = $cell->sz ? 14 : 20;
	    if ( $c =~ /^repeat(1Bar|2Bars)$/ ) {
		$text->( $x+3, $y-5, $musicfont, $chordsize, $musicglyphs->{$c} );
		next;
	    }
	    if ( $c =~ /^repeat(Slash)$/ ) {
		$text->( $x+8, $y, $chordfont, $chordsize, "/" );
		next;
	    }

	    $c =~ s/(?:\*m\*|-)/m/;
	    $text->( $x+3, $y, $chordfont, $chordsize, $c );
	    next;
	}

	for ( $cell->subchord ) {
	    next unless $_;
	    my $a = $_;
	    $a =~ s/(?:\*m\*|-)/m/;
	    $text->( $x+3, $y-20, $chordfont, 14, $a );
	    next;
	}

	for ( $cell->alt ) {
	    next unless $_;
	    my $n = $_;
	    $text->( $x+3, $y-20, $textfont, 12, $n . ".", $red );
	    $im->line( ( map { scale($_) } $x+2, $y-20, $x+2, $y-30), $red );
	    $im->line( ( map { scale($_) }  $x+2, $y-30, $x+2*$dx, $y-30), $red );
	    next;
	}

	for ( $cell->mark ) {
	    next unless $_;
	    my $t = $_;
	    $t = "Intro" if $t eq 'i';
	    $t = "Verse" if $t eq 'v';
	    $text->( $x-6, $y-22, $markfont, 12, $t, $red );
	    next;
	}

	for ( $cell->text ) {
	    next unless $_;
	    my ( $disp, $t ) = @$_;
	    $text->( $x, $y-($disp/3), $textfont, 10, $t, $red );
	    next;
	}

	next;

    }

    open( my $fd, '>:raw', $self->{output} );
    $fd->print( $im->png );
    $fd->close;
    warn("Wrote: ", $self->{output}, "\n") if $self->{verbose};
    $song->{pages} = $pages;
}

1;
