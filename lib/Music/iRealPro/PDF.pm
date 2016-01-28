#! perl

# iReal2pdf -- print iRealPro songs

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jan 28 15:26:49 2016
# Update Count    : 934
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
use constant PAGE_WIDTH  => 595;
use constant PAGE_HEIGHT => 842;

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

    # Create fonts.
    $self->initfonts;

    my $textfont  = $self->{textfont};
    my $chordfont = $self->{chordfont};
    my $chrdfont  = $self->{chrdfont};
    my $musicfont = $self->{musicfont};
    my $muscfont  = $self->{muscfont};
    my $markfont  = $self->{markfont};

    my $musicsize = $self->{musicsize};
    my $chordsize = $self->{chordsize};

    my $musicglyphs = $self->{musicglyphs};

    my $lm = 40;
    my $rm = PAGE_WIDTH - $lm;
    my $bm = PAGE_HEIGHT - 50;
    my $tm = 172 - 50;

    my $dx = ( $rm - $lm ) / $numcols;
    my $dy = ( $bm - $tm ) / $numrows;
    if ( $dy < 1.6*$musicsize ) {
	$dy = 1.6*$musicsize;
    }

    $self->{pages} = 0;

    # Draw headings for a new page.
    my $newpage = sub {
	$self->newpage;

	my $titlesize = $self->{titlesize};
	my $titlefont = $self->{titlefont};
	my $ddx = 0.15*$musicsize;

	$self->textc( ($lm+$rm)/2-$ddx, $tm-80, $song->{title},
		      $titlesize, $titlefont );
	$self->textl( $lm-$ddx, $tm-50, $song->{composer},
		      0.85*$titlesize, $textfont )
	  if $song->{composer};
	$self->textr( $rm+$ddx, $tm-50, "(".$song->{style}.")",
		      0.85*$titlesize, $textfont )
	  if $song->{style};
    };

    my $low;			# water mark to crop image

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

	# Adjust vertical position.
	for ( $cell->vs ) {
	    next unless $_;
	    $y += $_*0.3*$dy;
	}

	# Adjust low water mark.
	if ( $y + 40 > $low ) {
	    $low = $y + 40;
	}

	#### Cell contents ################

	for ( $cell->lbar ) {
	    next unless $_;
	    my $col = /^repeat(?:Right)?Left$/ ? $red : $black;
	    $self->glyphc( $x, $y, $_, undef, $col );
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
	    $self->glyphc( $x+$dx, $y, $_, undef, $col );
	    next;
	}

	for ( $cell->time ) {
	    next unless $_;
	    my ( $t1, $t2 ) = @$_;
	    my $w = $self->aw( $musicfont, 0.7*$musicsize,
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

	    $self->textc( $x, $y-0.55*$musicsize, $t1,
			  0.7*$musicsize, $musicfont, $red );
	    $self->textc( $x, $y-0.15*$musicsize, $t2,
			  0.7*$musicsize, $musicfont, $red );
	    next;
	}

	for ( $cell->sign ) {	# coda, segno, ...
	    next unless $_;
	    $self->glyphl( $x+0.15*$musicsize, $y-1.05*$musicsize,
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

		# Center between the barlines.
		$x -= ( $i-$pb ) * $dx;
		$x += ( $nb-$pb+1 ) * $dx/2;
		$self->textc( $x, ($y-0.3*$musicsize),
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

		# Overprint next barline.
		$x += ( $nb-$i+1 ) * $dx;
		$self->textc( $x, ($y-0.3*$musicsize),
			      $musicglyphs->{$c}, $chordsize, $musicfont );
		next;
	    }

	    if ( $c =~ /^repeat(Slash)$/ ) {
		$self->textl( $x+0.4*$musicsize, $y, "/", $chordsize, $chordfont );
		next;
	    }

	    $self->chord( $x+0.15*$musicsize, $y, $c, $musicsize, $font );
	    next;
	}

	for ( $cell->subchord ) {
	    next unless $_;
	    $self->chord( $x+0.15*$musicsize, $y+$musicsize,
			  $_, 0.7*$chordsize );
	    next;
	}

	for ( $cell->alt ) {	# N1, N2, ... alternatives
	    next unless $_;
	    my $n = $_;
	    $self->textl( $x+0.15*$musicsize, $y-$musicsize, $n . ".",
			  0.6*$musicsize, $textfont, $red );
	    $self->line( $x+0.1*$musicsize,
			 $y-$musicsize,
			 $x+0.1*$musicsize,
			 $y-1.5*$musicsize, $red );
	    $self->line( $x+0.1*$musicsize,
			 $y-1.5*$musicsize,
			 $x+2*$dx,
			 $y-1.5*$musicsize, $red );
	    next;
	}

	for ( $cell->mark ) {
	    next unless $_;
	    my $t = $_;
	    $t = "Intro" if $t eq 'i';
	    $t = "Verse" if $t eq 'v';
	    $self->textl( $x-0.3*$musicsize, $y-0.9*$musicsize, $t,
			  0.6*$musicsize, $markfont, $red );
	    next;
	}

	for ( $cell->text ) {
	    next unless $_;
	    my ( $disp, $t ) = @$_;
	    $self->textl( $x+0.15*$musicsize,
			  $y+0.55*$musicsize-($disp/(40/$musicsize)),
			  $t, 0.5*$musicsize, $textfont, $red );
	    next;
	}

	next;

    }

    # Crop excess bottom space.
    if ( $self->{im} && $self->{crop} && $low ) {
	$self->{im} = $self->{im}->crop( top => 0, height => scale($low) );
    }

    # Return number of pages actually produced.
    # This will always be 1 unless generating PDF.
    $song->{pages} = $self->{pages};

    # }}}
}

################ Low level graphics ################

# String width.
sub aw {
    my ( $self, $font, $size, $t ) = @_;
    if ( $self->{im} ) {
	my @w = $font->bounding_box( size => $size, string => $t );
	# ($neg_width,
	#  $global_descent,
	#  $pos_width,
	#  $global_ascent,
	#  $descent,
	#  $ascent,
	#  $advance_width,
	#  $right_bearing)
	return $w[6];
    }
    if ( $self->{pdf} ) {
	$self->{text}->font( $font, $size );
	return $self->{text}->advancewidth($t);
    }
}

# Draw text, left aligned.
sub textl {
    my ( $self, $x, $y, $t, $size, $font, $col, $lcr ) = @_;
    $size ||= $self->{musicsize};
    $font ||= $self->{textfont};
    $col ||= $black;
    $lcr ||= 'l';

    my $w = $self->aw( $font, $size, $t );
    $x -= $w/2 if $lcr eq 'c';
    $x -= $w if $lcr eq 'r';

    if ( $self->{im} ) {
	$_ = scale($_) for $x, $y, $size;
	$self->{im}->string( font => $font, size => $size, aa => 1,
			     color => $col, x => $x, y => $y, text => $t );
    }
    if ( $self->{pdf} ) {
	for ( $self->{text} ) {
	    $_->translate( $x, PAGE_HEIGHT-$y );
	    $_->fillcolor($col) if $col ne $black;
	    $_->text($t);
	    $_->fillcolor($black) if $col ne $black;
	}
    }
    $w;
};

# Draw text, centered.
sub textc {
    my ( $self, $x, $y, $t, $size, $font, $col, $lcr ) = @_;
    $lcr ||= 'c';
    $self->textl( $x, $y, $t, $size, $font, $col, $lcr );
};

# Draw text, right aligned.
sub textr {
    my ( $self, $x, $y, $t, $size, $font, $col, $lcr ) = @_;
    $lcr ||= 'r';
    $self->textl( $x, $y, $t, $size, $font, $col, $lcr );
};

# Draw music glyph, centered.
sub glyphc {
    my ( $self, $x, $y, $smc, $size, $col ) = @_;
    $size ||= $self->{musicsize};
    die("Unknown glyph: $smc") unless exists $self->{musicglyphs}->{$smc};
    $self->textc( $x, $y+0.15*$self->{musicsize},
		  $self->{musicglyphs}->{$smc}, $size,
		  $self->{musicfont}, $col );
};

# Draw music glyph, left aligned.
sub glyphl {
    my ( $self, $x, $y, $smc, $size, $col ) = @_;
    $size ||= $self->{musicsize};
    die("Unknown glyph: $smc") unless exists $self->{musicglyphs}->{$smc};
    $self->textl( $x, $y+0.15*$self->{musicsize},
		  $self->{musicglyphs}->{$smc}, $size,
		  $self->{musicfont}, $col );
};

# Draw a chord, with potentially a bass note.
sub chord {
    my ( $self, $x, $y, $c, $size, $font ) = @_;
    $font ||= $self->{chordfont};
    $size ||= $self->{chordsize};
    $c =~ s/\*(.*?)\*/$1/;
    $c =~ s/-/m/;
    $c =~ s/^W/ /;
    my $bass;
    if ( $c =~ m;(.*?)/(.*); ) {
	$bass = $2;
	$c = $1;
    }

    my $one = 0.05*$size;
    $y += $one;

    my @c = split ( //, $c );
    $x += $self->textl( $x, $y, shift(@c), 1.2*$size, $font );

    if ( @c ) {
	if ( $c[0] eq "b" ) {
	    shift(@c);
	    $self->textl( $x+$one, $y-0.6*$size,
			  $self->{musicglyphs}->{flat},
			  $size, $self->{musicfont} );
	}
	elsif ( $c[0] eq "#" ) {
	    shift(@c);
	    $self->textl( $x+$one, $y-0.7*$size,
			  $self->{musicglyphs}->{sharp},
			  1*$size, $self->{musicfont} );
	}
    }

    while ( @c ) {
	my $c = shift(@c);
	if ( $c eq "b" ) {
	    $x += $self->glyphl( $x+$one, $y-0.15*$size, "flat", 0.8*$size );
	}
	elsif ( $c eq "#" ) {
	    $x += $self->glyphl( $x, $y-0.15*$size, "sharp", 0.6*$size );
	}
	elsif ( $c =~ /\d/ ) {
	    $x += $self->textl( $x, $y+0.1*$size, $c, 0.7*$size, $font );
	}
	elsif ( $c eq "^" ) {
	    $x += $self->textl( $x, $y,
			    $self->{musicglyphs}->{csymMajorSeventh},
			    0.8*$size, $self->{muscfont} );
	}
	elsif ( $c eq "o" ) {
	    $x += $self->textl( $x, $y,
				    $self->{musicglyphs}->{csymDiminished},
				    0.8*$size, $self->{muscfont} );
	}
	elsif ( $c eq "h" ) {
	    $x += $self->textl( $x, $y,
				    $self->{musicglyphs}->{csymHalfDiminished},
				    0.8*$size, $self->{muscfont} );
	}
	else {
	    $x += $self->textl( $x, $y+$one+$one, $c,
				    0.7*$size, $self->{chrdfont} );
	}
    }
    return unless $bass;
    my $w = $self->aw( $font, 0.9*$size, "/");
    $x -= $w/3;
    $y += 0.3*$size;
    $self->textl( $x, $y, "/", 0.9*$size, $font );
    $x += $w;
    $y += 0.2*$size;
    $self->chord( $x-$one, $y, $bass, 0.6*$size, $font );
}

# Draw a line.
sub line {
    my ( $self, $x1, $y1, $x2, $y2, $col ) = @_;
    $col ||= $black;

    if ( $self->{im} ) {
	$_ = scale($_) for $x1, $x2, $y1, $y2;
	$self->{im}->line( x1 => $x1, y1 => $y1,
			   x2 => $x2, y2 => $y2,
			   color => $col );
    }
    if ( $self->{pdf} ) {
	my $gfx = $self->{page}->gfx;
	$gfx->save;
	$gfx->strokecolor($col);
	$gfx->move( $x1, PAGE_HEIGHT-$y1 );
	$gfx->linewidth(1);
	$gfx->line( $x2, PAGE_HEIGHT-$y2 );
	$gfx->stroke;
	$gfx->restore;
    }
}

# New page.
sub newpage {
    my ( $self ) = @_;
    $self->{pages}++;

    if ( $self->{im} ) {
	# Start with a white page.
	$self->{im}->box( filled => 1 );
    }

    if ( $self->{pdf} ) {
	$self->{page} = $self->{pdf}->page;
	$self->{text} = $self->{page}->text;
    }
};

sub initfonts {
    my ( $self, $size ) = @_;
    $size ||= 20;

    # Make font objects.
    for ( qw( titlefont textfont chordfont chrdfont
	      musicfont muscfont markfont ) ) {
	if ( $self->{im} ) {
	    $self->{$_} = Imager::Font->new( file => $self->{fontdir} . $fonts->{$_} )
	      or die( "$_: ", Imager->errstr );
	}
	if ( $self->{pdf} ) {
	    $self->{$_} = $self->{pdf}->ttfont( $self->{fontdir} . $fonts->{$_} );
	}
    }

    $self->{musicsize} = $size;
    $self->{chordsize} = $self->{musicsize};
    $self->{titlesize} = $self->{musicsize};
    $self->{musicglyphs} = \%smufl;

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
