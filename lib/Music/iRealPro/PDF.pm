#! perl

# iReal2pdf -- print iRealPro songs

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jan 28 10:18:28 2016
# Update Count    : 885
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

    for ( qw( trace debug verbose output variant debug crop ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    $self->{fontdir} ||= $ENV{FONTDIR} || ".";
    $self->{fontdir} .= "/";
    $self->{fontdir} =~ s;/+$;/;;

    # Scaling (bitmaps only).
    if ( $options->{scale} && $options->{scale} =~ /^[\d.]+$/ ) {
	no warnings 'redefine';
	eval( "sub scale(\$) { " . $options->{scale} . "*\$_[0] };" );
    }

    return $self;
}

# A4 image format.
use constant PAGE_WIDTH  => 595; #800; #595;
use constant PAGE_HEIGHT => 842; #1219; #842;

# Scaling for bitmap graphics to get finer images.
sub scale($) { 2*$_[0] };

# Fonts.
my $fonts =
  { titlefont => "FreeSansBold.ttf",
    textfont  => "FreeSans.ttf",
    markfont  => "FreeSansBold.ttf",
    # Normal and condensed versions
    chordfont => "Myriad-CnSemibold.ttf",
    chrdfont  => "Myriad-UcnSemibold.ttf",
    musicfont => "Bravura.ttf",
    muscfont  => "BravuraCn.ttf",
  };

# Colors.
my $black = "#000000";
my $red   = "#ff0000";

sub parsefile {
    my ( $self, $file, $options ) = @_;

    open( my $fd, '<', $file ) or die("$file: $!\n");
    my $data = do { local $/; <$fd> };
    $self->parsedata( $data, $options );
}

sub parsedata {
    my ( $self, $data, $options ) = @_;

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
	require PDF::API2;
	$self->{pdf} = PDF::API2->new;
	$self->{pdf}->mediabox( 0, PAGE_HEIGHT, PAGE_WIDTH, 0 );
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

	my $numpages = $self->make_image( $song, $mx );
	next unless $outtype eq "pdf";

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
    # {{{
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
	@$cells >= 2 and $cells->[-2]->rbar ||= "barlineSingle";
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

	# |Bh7 E7b9 ZY|QA- |
	if ( $t eq "vspace" ) {
	    $vspace++;
	    $cells->[-1]->vs = $vspace;
	    next;
	}

	if ( $t eq "end" ) {
	    $cells->[-2]->rbar = "barlineFinal";
	    next;
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
    # }}}
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

# Generalized formatter for PDF::API2 and Imager.
sub make_image {
    # {{{
    my ( $self, $song, $cells ) = @_;

    my $im = $self->{im};	# Imager

    my $pdf = $self->{pdf};	# PDF::API2
    my $page;			# PDF::API2
    my $text;			# PDF::API2

    if ( $im ) {
	# Start with a white page.
	$im->box( filled => 1 );
    }

    # Create fonts.
    my $titlefont = $fonts->{titlefont};
    my $textfont  = $fonts->{textfont};
    my $chordfont = $fonts->{chordfont};
    my $chrdfont  = $fonts->{chrdfont};
    my $musicfont = $fonts->{musicfont};
    my $muscfont  = $fonts->{muscfont};
    my $markfont  = $fonts->{markfont};

    # Make font objects.
    my $i = 0;
    for ( $titlefont, $textfont, $chordfont, $chrdfont,
	  $musicfont, $muscfont, $markfont ) {
	$i++;
	if ( $im ) {
	    $_ = Imager::Font->new( file => $self->{fontdir} . $_ )
	      or die( "$i: ", Imager->errstr );
	}
	if ( $pdf ) {
	    $_ = $pdf->ttfont( $self->{fontdir} . $_ );
	}
    }

    my $musicsize = 20;
    my $chordsize = $musicsize;
    my $titlesize = $musicsize;
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

    # String width.
    my $aw;
    $aw = sub {
	my ( $font, $size, $t ) = @_;
	($font->bounding_box( size => $size, string => $t ))[6];
    } if $im;
    $aw = sub {
	my ( $font, $size, $t ) = @_;
	$text->font( $font, $size );
	$text->advancewidth($t);
    } if $pdf;

    # Draw text, left aligned.
    my $textl = sub {
	my ( $x, $y, $t, $size, $font, $col, $lcr ) = @_;
	$size ||= $musicsize;
	$font ||= $textfont;
	$col  ||= $black;
	$lcr ||= 'l';

	my $w = $aw->( $font, $size, $t );
	$x -= $w/2 if $lcr eq 'c';
	$x -= $w if $lcr eq 'r';

	if ( $im ) {
	    $_ = scale($_) for $x, $y, $size;
	    $im->string( font => $font, size => $size, aa => 1, color => $col,
			 x => $x, y => $y, text => $t );
	}
	if ( $pdf ) {
	    $text->translate( $x, PAGE_HEIGHT-$y );
	    $text->fillcolor($col) unless $col eq $black;
	    $text->text($t);
	    $text->fillcolor($black) unless $col eq $black;
	}

	$w;
    };

    # Draw text, centered.
    my $textc = sub {
	my ( $x, $y, $t, $size, $font, $col, $lcr ) = @_;
	$lcr ||= 'c';
	$textl->( $x, $y, $t, $size, $font, $col, $lcr );
    };

    # Draw text, right aligned.
    my $textr = sub {
	my ( $x, $y, $t, $size, $font, $col, $lcr ) = @_;
	$lcr ||= 'r';
	$textl->( $x, $y, $t, $size, $font, $col, $lcr );
    };

    # Draw music glyph, centered.
    my $glyphc = sub {
	my ( $x, $y, $smc, $size, $col ) = @_;
	$size ||= $musicsize;
	die("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	$textc->( $x, $y+0.15*$musicsize,
		  $musicglyphs->{$smc}, $size, $musicfont, $col );
    };

    # Draw music glyph, left aligned.
    my $glyphl = sub {
	my ( $x, $y, $smc, $size, $col ) = @_;
	$size ||= $musicsize;
	die("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
	$textl->( $x, $y+0.15*$musicsize,
		  $musicglyphs->{$smc}, $size, $musicfont, $col );
    };

    # Draw a chord, with potentially a bass note.
    my $chord; $chord = sub {
	my ( $x, $y, $c, $size, $font ) = @_;
	$font ||= $chordfont;
	$size ||= $chordsize;
	$c =~ s/(?:\*m(\d)?\*|-)/m$1/;
	$c =~ s/^W/ /;
	my $bass;
	if ( $c =~ m;(.*?)/(.*); ) {
	    $bass = $2;
	    $c = $1;
	}

	my $one = 0.05*$size;
	$y += $one;

	my @c = split ( /([miaugdb#^oh\d])/, $c );
	$x += $textl->( $x, $y, shift(@c), 1.2*$size, $font );

	if ( @c ) {
	    if ( $c[0] eq "b" ) {
		shift(@c);
		$textl->( $x+$one, $y-0.6*$size, $musicglyphs->{flat},
			  $size, $musicfont );
	    }
	    elsif ( $c[0] eq "#" ) {
		shift(@c);
		$textl->( $x+$one, $y-0.7*$size, $musicglyphs->{sharp},
			   1*$size, $musicfont );
	    }
	}

	while ( @c ) {
	    my $c = shift(@c);
	    if ( $c eq "b" ) {
		$x += $glyphl->( $x, $y-0.15*$size, "flat", 0.8*$size );
	    }
	    elsif ( $c eq "#" ) {
		$x += $glyphl->( $x, $y-0.15*$size, "sharp", 0.6*$size );
	    }
	    elsif ( $c =~ /\d/ ) {
		$x += $textl->( $x, $y+0.1*$size, $c, 0.7*$size, $font );
	    }
	    elsif ( $c eq "^" ) {
		$x += $textl->( $x, $y,
				$musicglyphs->{csymMajorSeventh},
				0.8*$size, $muscfont );
	    }
	    elsif ( $c eq "o" ) {
		$x += $textl->( $x, $y,
				$musicglyphs->{csymDiminished},
				0.8*$size, $muscfont );
	    }
	    elsif ( $c eq "h" ) {
		$x += $textl->( $x, $y,
				$musicglyphs->{csymHalfDiminished},
				0.8*$size, $muscfont );
	    }
	    else {
		$x += $textl->( $x, $y+$one+$one, $c,
				0.7*$size, $chrdfont );
	    }
	}
	return unless $bass;
	my $w = $aw->( $font, 0.9*$size, "/");
	$x -= $w/3;
	$y += 0.3*$size;
	$textl->( $x, $y, "/", 0.9*$size, $font );
	$x += $w;
	$y += 0.2*$size;
	$chord->( $x-$one, $y, $bass, 0.6*$size, $font );
    };

    # Draw headings for a new page.
    my $newpage = sub {
	$pages++;

	if ( $pdf ) {
	    $page = $pdf->page;
	    $text = $page->text;
	}

	my $ddx = 0.15*$musicsize;
	$textc->( ($lm+$rm)/2-$ddx, $tm-80, $song->{title},
		  $titlesize, $titlefont );
	$textl->( $lm-$ddx, $tm-50, $song->{composer},
		  0.85*$titlesize, $textfont )
	  if $song->{composer};
	$textr->( $rm+$ddx, $tm-50, "(".$song->{style}.")",
		  0.85*$titlesize, $textfont )
	  if $song->{style};
    };

    my $low;			# watermark to crop image

    # Process the cells.
    for ( my $i = 0; $i < @$cells; $i++ ) {

	# onpage is the cell index relative to the current page.
	# Note that we do not yet support multi-page songs.
	my $onpage = $i % ( $numrows * $numcols );
	if ( !$onpage ) {
	    # First cell on this page, draw headings and such.
	    $newpage->();
	    $low = 0;
	}

	# The current cell.
	my $cell = $cells->[$i];

	# Cell position on the drawing.
	my $x = $lm +    ( $onpage % $numcols ) * $dx;
	my $y = $tm + int( $onpage / $numcols ) * $dy;

	for ( $cell->vs ) {
	    next unless $_;
	    $y += $_*0.3*$dy;
	}

	if ( $y + 40 > $low ) {
	    $low = $y + 40;
	}

	for ( $cell->lbar ) {
	    next unless $_;
	    my $col = /^repeat(?:Right)?Left$/ ? $red : $black;
	    $glyphc->( $x, $y, $_, undef, $col );
	    next;
	}

	for ( $cell->rbar ) {
	    next unless $_;
	    my $col = $black;
	    if ( /^repeatRight$/ ) {
		$col = $red;
		if ( ($i+1) % $numcols
		     && $i < @$cells
		     && $cells->[$i+1]->lbar
		     && $cells->[$i+1]->lbar eq "repeatLeft" ) {
		    $cells->[$i+1]->lbar = "repeatRightLeft";
		    next;
		}
	    }
	    $glyphc->( $x+$dx, $y, $_, undef, $col );
	    next;
	}

	for ( $cell->time ) {
	    next unless $_;
	    my ( $t1, $t2 ) = @$_;
	    my $w = $aw->( $musicfont, 0.7*$musicsize,
			   $musicglyphs->{timeSig0} ) / 2;
	    # Move left half $w for centering, and half $w to get
	    # out of the way.
	    my $x = $x - $w - 0.15*$musicsize;
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
	    $glyphl->( $x+0.15*$musicsize, $y-1.05*$musicsize,
		       $_, 0.7*$musicsize, $red );
	    next;
	}

	for ( $cell->chord ) {	# chords and chordrepeats.
	    next unless $_;
	    my $c = $_;
	    my $font = $cell->sz ? $chrdfont : $chordfont;

	    if ( $c =~ /^repeat1Bar$/ ) {

		# Find previous bar line.
		my $pb = $i;
		while ( $pb >= 0) {
		    last if $cells->[$pb]->lbar
		      || ( $pb > 1 && $cells->[$pb-1]->rbar );
		    $pb--;
		}
		# Find next bar line.
		my $nb = $i;
		while ( $nb < @$cells ) {
		    last if $cells->[$nb]->rbar
		      || ( $nb+1 < @$cells && $cells->[$nb+1]->lbar );
		    $nb++;
		}
		$x -= ( $i-$pb ) * $dx;
		$x += ( $nb-$pb+1 ) * $dx/2;

		$textc->( $x, ($y-0.3*$musicsize),
			  $musicglyphs->{$c}, $chordsize, $musicfont );
		next;
	    }

	    if ( $c =~ /^repeat2Bars$/ ) {

		# Find next bar line.
		my $nb = $i;
		while ( $nb < @$cells ) {
		    last if $cells->[$nb]->rbar
		      || ( $nb+1 < @$cells && $cells->[$nb+1]->lbar );
		    $nb++;
		}
		$x += ( $nb-$i+1 ) * $dx;
		$textc->( $x, ($y-0.3*$musicsize),
			  $musicglyphs->{$c}, $chordsize, $musicfont );
		next;
	    }

	    if ( $c =~ /^repeat(Slash)$/ ) {
		$textl->( $x+0.4*$musicsize, $y, "/", $chordsize, $chordfont );
		next;
	    }

	    $chord->( $x+0.15*$musicsize, $y, $_ );
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
	    if ( $im ) {
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
	    }
	    if ( $pdf ) {
		my $gfx = $page->gfx;
		$gfx->save;
		$gfx->strokecolor($red);
		$gfx->move( $x+0.1*$musicsize, PAGE_HEIGHT-($y-$musicsize) );
		$gfx->linewidth(1);
		$gfx->line( $x+0.1*$musicsize, PAGE_HEIGHT-($y-1.5*$musicsize) );
		$gfx->line( $x+2*$dx, PAGE_HEIGHT-($y-1.5*$musicsize) );
		$gfx->stroke;
		$gfx->restore;
	    }
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
		      $t, 0.5*$musicsize, $textfont, $red );
	    next;
	}

	next;

    }

    if ( $im && $self->{crop} && $low ) {
	$self->{im} = $im->crop( top => 0, height => scale($low) );
    }

    $song->{pages} = $pages;

    # }}}
}

1;

=begin experimental

for ( "mpdfx.pl", "mpng.pl" ) {
    open( my $fd, "<", $_ );
    my $data = do { local $/; <$fd> };
    eval $data or die($@);
}

=end experimental

=cut

1;
