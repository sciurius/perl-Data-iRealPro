#! perl

# iReal2pdf -- print iRealPro songs

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Wed Jan 20 22:34:03 2016
# Update Count    : 598
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use utf8;

package Music::iRealPro::PDF;

our $VERSION = "0.03";

use Music::iRealPro::URI;
use Music::iRealPro::Tokenizer;
use Data::Dumper;
use Text::CSV;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { variant => "irealpro" }, $pkg );

    for ( qw( trace debug verbose output variant debug ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    $self->{fontdir} ||= $ENV{FONTDIR} || ".";
    $self->{fontdir} .= "/";
    $self->{fontdir} =~ s;/+$;/;;

    return $self;
}

# A4 image format.
use constant PAGE_WIDTH  => 595;
use constant PAGE_HEIGHT => 842;

# Scaling for bitmap graphics to get finer images.
sub scale($) { 2*$_[0] };

# Fonts.
my $fonts =
  { titlefont => "FreeSansBold.ttf",
    textfont  => "FreeSans.ttf",
    chordfont => "Myriad-CnSemibold.ttf",
    chrdfont  => "Myriad-CnSemibold.ttf",
    musicfont => "Bravura.otf",
    markfont  => "FreeSansBold.ttf",
  };

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

    ( my $outtype = lc($self->{output}) ) =~ s/^.*\.(.+)$/$1/;

    if ( $outtype eq "pdf" ) {
	require PDF::API2::Tweaks;
	$self->{pdf} = PDF::API2->new;
    }
    elsif ( $outtype =~ /^png|jpg$/ ) {
	require Imager;
	$self->{im} = Imager->new( xsize => scale(PAGE_WIDTH),
				   ysize => scale(PAGE_HEIGHT),
				   model => 'rgb',
				 ) or die( Imager->errstr );

    }
    else {
	die( "Unsupported output type for ", $self->{output}, "\n" );
    }

    my $pageno = 1;

    my $csv;
    my $csv_fd;
    my $csv_name;
    if ( $outtype eq "pdf" ) {
	$csv_name = $self->{output};
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
	my $mx = $self->make_cells( $song, $res );

	if ( $outtype =~ /^png|jpg$/ ) {
	    $self->make_png( $song, $mx );
	    next;
	}

	my $numpages = $self->make_pdf( $song, $mx );
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
	# $composer = "$2 $1" if $composer =~ /^(.+?) +([^ ]+)$/;
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

    if ( $outtype eq "pdf" ) {
	$self->{pdf}->saveas($self->{output});
	warn( "Wrote: ", $self->{output}, "\n" ) if $self->{verbose};
	$csv_fd->close;
	warn( "Wrote: $csv_name\n" ) if $self->{verbose};
    }
    elsif ( $outtype =~ /^png|jpg$/ ) {
	$self->{im}->write( file => $self->{output}, type => $outtype );
	warn( "Wrote: ", $self->{output}, "\n" ) if $self->{verbose};
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
# repeatLeft and Right are too wide. Use a substitute.
#   repeatLeft		=> "\x{e040}",
#   repeatRight		=> "\x{e041}",
#   repeatRightLeft	=> "\x{e042}",
    repeatLeft		=> "\x{e000}\x{e043}", # {:
    repeatRight		=> "\x{e043}\x{e001}", # :}
    repeatRightLeft	=> "\x{e043}\x{e001}\x{e000}\x{e043}", # :}{:
    repeatDots		=> "\x{e043}",
    dalSegno		=> "\x{e045}",
    daCapo		=> "\x{e046}",
    segno		=> "\x{e047}",
    coda		=> "\x{e048}",
    timeSig0		=> "\x{e080}", # timeSig1, ...etc...
    flat		=> "\x{e260}",
    sharp		=> "\x{e262}",
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

    # Create fonts.
    my $titlefont = $fonts->{titlefont};
    my $textfont  = $fonts->{textfont};
    my $chordfont = $fonts->{chordfont};
    my $chrdfont  = $fonts->{chrdfont};
    my $musicfont = $fonts->{musicfont};
    my $markfont  = $fonts->{markfont};

    # Make font objects.
    for ( $titlefont, $textfont, $chordfont, $chrdfont, $musicfont, $markfont ) {
	$_ = $pdf->ttfont( $self->{fontdir} . $_ );
    }

    my $musicsize = 20;
    my $chordsize = $musicsize;

    my $musicglyphs = \%smufl;

    my $tm = PAGE_HEIGHT - 172;
    my $lm = 40;
    my $bm = 50;
    my $rm = PAGE_WIDTH - $lm;
    my $dx = ( $rm - $lm ) / $numcols;
    my $dy = ( $tm - $bm ) / $numrows;

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

    my $glyphc = sub {
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

    our $glyph = $glyphc;

    my $glyphx = sub {
	$text->fillcolor("#ff0000");
	$glyph->(@_);
	$text->fillcolor("#000000");
    };

    my $chord; $chord = sub {
	my ( $x, $y, $c, $size ) = @_;
	$size ||= $chordsize;
	$c =~ s/(?:\*m\*|-)/m/;
	my $bass;
	if ( $c =~ m;(.*?)/(.*); ) {
	    $bass = $2;
	    $c = $1;
	}

	my @c = split ( /([miaugdb#^oh\d])/, $c );
	my $one = 0.05*$size;
	my $first = 1;
	while ( @c ) {
	    my $c = shift(@c);
	    if ( $c eq "b" ) {
		$c = $musicglyphs->{flat};
		$text->font( $musicfont, $size );
		$text->translate( $x+$one, $y );
		$text->text($c);
		$x += $text->advancewidth($c) + 0.1*$size;
	    }
	    elsif ( $c eq "#" ) {
		$c = $musicglyphs->{sharp};
		$text->font( $musicfont, $size );
		$text->translate( $x+$one, $y+0.3*$size );
		$text->text($c);
		$x += $text->advancewidth($c) + $one+$one;
	    }
	    elsif ( $c =~ /\d/ ) {
		$text->font( $chordfont, 0.9*$size );
		$text->translate( $x, $y-0.1*$size );
		$text->text($c);
		$x += $text->advancewidth($c);
	    }
	    elsif ( $c eq "^" ) {
		$c = $musicglyphs->{csymMajorSeventh};
		$text->font( $musicfont, $size );
		$text->translate( $x+$one, $y );
		$text->text($c);
		$x += $text->advancewidth($c) + $one;
	    }
	    elsif ( $c eq "o" ) {
		$c = $musicglyphs->{csymDiminished};
		$text->font( $musicfont, $size );
		$text->translate( $x+$one, $y );
		$text->text($c);
		$x += $text->advancewidth($c) + $one;
	    }
	    elsif ( $c eq "h" ) {
		$c = $musicglyphs->{csymHalfDiminished};
		$text->font( $musicfont, $size );
		$text->translate( $x+$one, $y );
		$text->text($c);
		$x += $text->advancewidth($c) + $one;
	    }
	    else {
		$text->font( $chordfont,
			     $first ? $size : 0.8*$size );
		$text->translate( $x, $y );
		$text->text($c);
		$x += $text->advancewidth($c);
	    }
	    $first = 0;
	}
	return unless $bass;
	$text->font( $chordfont, 0.9*$size );
	my $w = $text->advancewidth("/");
	$x -= $w/3;
	$y -= 0.3*$size;
	$text->translate( $x, $y );
	$text->text("/");
	$x += $w;
	$y -= 0.2*$size;
	$chord->( $x, $y, $bass, 0.9*$size );
    };

    for ( my $i = 0; $i < @$cells; $i++ ) {

	my $onpage = $i % ( $numrows * $numcols );
	if ( !$onpage ) {
	    $newpage->();
	}

	my $cell = $cells->[$i];

	my $x = $lm + ( $onpage % $numcols ) * $dx;
	my $y = $tm - int( $onpage / $numcols ) * $dy;

	for ( $cell->lbar ) {
	    next unless $_;
	    my $g = /^repeat(?:Right)?Left$/ ? $glyphx : $glyph;
	    $g->( $x, $y, $_ );
	    next;
	}

	for ( $cell->rbar ) {
	    next unless $_;
	    my $g = $glyph;
	    if ( /^repeatRight$/ ) {
		$g = $glyphx;
		if ( ($i+1) % $numcols
		     && $i < @$cells
		     && $cells->[$i+1]->lbar
		     && $cells->[$i+1]->lbar eq "repeatLeft" ) {
		    $cells->[$i+1]->lbar = "repeatRightLeft";
		    next;
		}
	    }
	    $g->( $x+$dx, $y, $_ );
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

	    $chord->( $x+3, $y, $_ );
	    next;
	}

	for ( $cell->subchord ) {
	    next unless $_;
	    $chord->( $x+3, $y+$chordsize, $_, 0.7*$chordsize );
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
	    $text->textline( $x, $y-0.55*$musicsize+($disp/2), $t );
	    $text->fillcolor("#000000");
	    next;
	}

	next;

    }

    $song->{pages} = $pages;
}

sub make_png {
    my ( $self, $song, $cells ) = @_;

    my $im = $self->{im};

    require Imager::Matrix2d;

    # Colors.
    my $black = "#000000";
    my $red   = "#ff0000";

    # Start with a white page.
    $im->box( filled => 1 );

    # Create fonts.
    my $titlefont = $fonts->{titlefont};
    my $textfont  = $fonts->{textfont};
    my $chordfont = $fonts->{chordfont};
    my $chrdfont  = $fonts->{chrdfont};
    my $musicfont = $fonts->{musicfont};
    my $markfont  = $fonts->{markfont};

    # Make font objects.
    for ( $titlefont, $textfont, $chordfont, $chrdfont, $musicfont, $markfont ) {
	$_ = Imager::Font->new( file => $self->{fontdir} . $_ )
	  or die( Imager->errstr );
    }

    # Condensed font for 'small' mode.
    $chrdfont->transform
      ( matrix => Imager::Matrix2d->scale( x => 0.7, y => 1 ) );

    my $chordsize = 20;
    my $musicsize = $chordsize;

    my $musicglyphs = \%smufl;

    my $lm = 40;
    my $rm = PAGE_WIDTH - $lm;
    my $bm = PAGE_HEIGHT - 50;
    my $tm = 172 - 50;

    my $dx = ( $rm - $lm ) / $numcols;
    my $dy = ( $bm - $tm ) / $numrows;
    if ( $dy < 1.6*$musicsize ) {
	$dy = 1.6*$musicsize;
    }

    # TODO $im->setThickness( scale(1) );

    my $pages;

    # Draw text, left aligned.
    my $textl = sub {
	my ( $x, $y, $t, $size, $font, $col ) = @_;
	$size ||= $musicsize;
	$font ||= $textfont;
	$col  ||= $black;
	my $w = ($font->bounding_box( size => $size, string => $t ))[6];
;
	$_ = scale($_) for $x, $y, $size;
	$im->string( font => $font, size => $size, aa => 1, color => $col,
		     x => $x, y => $y, text => $t );
	$w;
    };

    # Draw text, centered.
    my $textc = sub {
	my ( $x, $y, $t, $size, $font, $col ) = @_;
	$size ||= $musicsize;
	$font ||= $textfont;
	$col  ||= $black;
	$_ = scale($_) for $x, $y, $size;
	my @b = $font->bounding_box( size => $size, string => $t );
	$x -= $b[6] / 2;
	$im->string( font => $font, size => $size, aa => 1, color => $col,
		     x => $x, y => $y, text => $t );
	$b[6];
    };

    # Draw text, right aligned.
    my $textr = sub {
	my ( $x, $y, $t, $size, $font, $col ) = @_;
	$size ||= $musicsize;
	$font ||= $textfont;
	$col  ||= $black;
	$_ = scale($_) for $x, $y, $size;
	my @b = $font->bounding_box( size => $size, string => $t );
	$x -= $b[6];
	$im->string( font => $font, size => $size, aa => 1, color => $col,
		     x => $x, y => $y, text => $t );
	$b[6];
    };

    # Default text drawing mode.
    our $text = $textl;

    # Draw music glyph, centered.
    my $glyphc = sub {
	my ( $x, $y, $smc, $size, $col ) = @_;
	Carp::confess("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	$textc->( $x, $y+0.15*$musicsize, $musicglyphs->{$smc},
		  $size || $musicsize, $musicfont, $col );
    };

    # Draw music glyph, left aligned.
    my $glyphl = sub {
	my ( $x, $y, $smc, $size, $col ) = @_;
	Carp::confess("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	$textl->( $x, $y+0.15*$musicsize, $musicglyphs->{$smc},
		  $size || $musicsize, $musicfont, $col );
    };

    # Default glyph drawing mode.
    our $glyph = $glyphc;

    # Draw music glyph, red, using default glyph mode.
    my $glyphx = sub {
	my ( $x, $y, $smc, $size ) = @_;
	$glyph->( $x, $y, $smc, $size, $red );
    };

    # Draw a chord, with potentially a bass note.
    my $chord; $chord = sub {
	my ( $x, $y, $c, $size, $font ) = @_;
	$font ||= $chordfont;
	$size ||= $chordsize;
	$c =~ s/(?:\*m\*|-)/m/;
	my $bass;
	if ( $c =~ m;(.*?)/(.*); ) {
	    $bass = $2;
	    $c = $1;
	}

	my @c = split ( /([miaugdb#^oh\d])/, $c );
	my $one = 0.05*$size;
	my $first = 1;
	while ( @c ) {
	    my $c = shift(@c);
	    if ( $c eq "b" ) {
		$x += $glyphl->( $x+$one, $y, "flat" ) + $one+$one;
	    }
	    elsif ( $c eq "#" ) {
		$x += $glyphl->( $x+$one, $y-0.3*$size, "sharp" ) + $one+$one;
	    }
	    elsif ( $c =~ /\d/ ) {
		$x += $textl->( $x, $y+0.1*$size, $c, 0.9*$size, $font );
	    }
	    elsif ( $c eq "^" ) {
		$x += $glyphl->( $x+$one, $y, "csymMajorSeventh" ) + $one;
	    }
	    elsif ( $c eq "o" ) {
		$x += $glyphl->( $x+$one, $y, "csymDiminished" ) + $one;
	    }
	    elsif ( $c eq "h" ) {
		$x += $glyphl->( $x+$one, $y, "csymHalfDiminished" ) + $one;
	    }
	    else {
		$x += $textl->( $x, $y, $c,
				$first ? $size : 0.8*$size, $font );
	    }
	    $first = 0;
	}
	return unless $bass;
	my $w = ($font->bounding_box( size => 0.9*$size, string => "/" ))[6];
	$x -= $w/3;
	$y += 0.3*$size;
	$textl->( $x, $y, "/", 0.9*$size, $font );
	$x += $w;
	$y += 0.2*$size;
	$chord->( $x, $y, $bass, 0.9*$size, $font );
    };

    # Draw headings for a new page.
    my $newpage = sub {
	$pages++;
	my $ddx = 0.15*$musicsize;
	$textc->( ($lm+$rm)/2-$ddx, $tm-80, $song->{title}, 20, $titlefont );
	$textl->( $lm-$ddx, $tm-50, $song->{composer}, 17, $textfont )
	  if $song->{composer};
	$textr->( $rm+$ddx, $tm-50, "(".$song->{style}.")", 17, $textfont )
	  if $song->{style};
    };

    # Process the cells.
    for ( my $i = 0; $i < @$cells; $i++ ) {

	# onpage is the cell index relative to the current page.
	# Note that we do not yet support multi-page songs.
	my $onpage = $i % ( $numrows * $numcols );
	if ( !$onpage ) {
	    # First cell on this page, draw headings and such.
	    $newpage->();
	}

	# The current cell.
	my $cell = $cells->[$i];

	# Cell position on the drawing.
	my $x = $lm +    ( $onpage % $numcols ) * $dx;
	my $y = $tm + int( $onpage / $numcols ) * $dy;

	for ( $cell->lbar ) {
	    next unless $_;
	    my $g = /repeat(?:Right)?Left/ ? $glyphx : $glyph;
	    $g->( $x, $y, $_ );
	    next;
	}

	for ( $cell->rbar ) {
	    next unless $_;
	    my $g = $glyph;
	    if ( /^repeatRight$/ ) {
		$g = $glyphx;
		if ( ($i+1) % $numcols
		     && $i < @$cells
		     && $cells->[$i+1]->lbar
		     && $cells->[$i+1]->lbar eq "repeatLeft" ) {
		    $cells->[$i+1]->lbar = "repeatRightLeft";
		    next;
		}
	    }
	    $g->( $x+$dx, $y, $_ );
	    next;
	}

	for ( $cell->time ) {
	    next unless $_;
	    my ( $t1, $t2 ) = @$_;
	    my @b = $musicfont->bounding_box( size => 14,
					      string => $musicglyphs->{timeSig0} );
	    my $w = $b[6];	# advance width
	    # Move left half $w for centering, and half $w to get
	    # out of the way.
	    my $x = $x - $w - 0.05*$musicsize;
	    # An additinal half $w when double digits are involved.
	    $x -= $w/2 if $t1 > 10 || $t2 > 10;

	    # Transform ordinary digits into music glyphs.
	    $w = ord( $musicglyphs->{timeSig0} ) - ord("0");
	    $t1 =~ s/(\d)/sprintf( "%c",$w+ord($1) )/ge;
	    $t2 =~ s/(\d)/sprintf( "%c",$w+ord($1) )/ge;

	    $textc->( $x, $y-0.55*$musicsize, $t1,
		      0.7*$musicsize, $musicfont, $red );
	    $textc->( $x, $y-0.15*$musicsize, $t2,
		      0.7*$musicsize, $musicfont, $red );
	    next;
	}

	for ( $cell->sign ) {	# coda, segno, ...
	    next unless $_;
	    local $glyph = $glyphl;
	    $glyphx->( $x+0.15*$musicsize, $y-1.05*$musicsize,
		       $_, 0.7*$musicsize );
	    next;
	}

	for ( $cell->chord ) {	# chords and chordrepeats.
	    next unless $_;
	    my $c = $_;

	    my $font = $cell->sz ? $chrdfont : $chordfont;
	    if ( $c =~ /^repeat(1Bar|2Bars)$/ ) {
		$glyphl->( $x+0.15*$musicsize, $y-0.4*$musicsize, $c );
		next;
	    }
	    if ( $c =~ /^repeat(Slash)$/ ) {
		$textl->( $x+0.4*$musicsize, $y, "/", $chordsize, $font );
		next;
	    }

	    $chord->( $x+0.15*$musicsize, $y, $c, $chordsize, $font );
	    next;
	}

	for ( $cell->subchord ) {
	    next unless $_;
	    $chord->( $x+0.15*$musicsize, $y+$musicsize,
		      $_, 0.7*$chordsize );
	    next;
	}

	for ( $cell->alt ) {
	    next unless $_;
	    my $n = $_;
	    $textl->( $x+0.15*$musicsize, $y-$musicsize, $n . ".",
		      0.6*$musicsize, $textfont, $red );
	    $im->line( color => $red,
		       x1 => scale($x+0.1*$musicsize),
		       y1 => scale($y-$musicsize),
		       x2 => scale($x+0.1*$musicsize),
		       y2 => scale($y-1.5*$musicsize) );
	    $im->line( color => $red,
		       x1 => scale($x+0.1*$musicsize),
		       y1 => scale($y-1.5*$musicsize),
		       x2 => scale($x+2*$dx),
		       y2 => scale($y-1.5*$musicsize) );
	    next;
	}

	for ( $cell->mark ) {
	    next unless $_;
	    my $t = $_;
	    $t = "Intro" if $t eq 'i';
	    $t = "Verse" if $t eq 'v';
	    $textl->( $x-0.3*$musicsize, $y-0.9*$musicsize, $t,
		      0.6*$musicsize, $markfont, $red );
	    next;
	}

	for ( $cell->text ) {
	    next unless $_;
	    my ( $disp, $t ) = @$_;
	    $textl->( $x+0.15*$musicsize,
		      $y+0.55*$musicsize-($disp/(40/$musicsize)),
		      $t, 0.5*$musicsize, $textfont, , $red );
	    next;
	}

	next;
    }

    $song->{pages} = $pages;
}

1;
