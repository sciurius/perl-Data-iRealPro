#! perl

# iReal2pdf -- print iRealPro songs

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jan 16 23:59:08 2016
# Update Count    : 225
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

package Music::iRealPro::PDF;

use parent qw(Music::iRealPro::Parser);
use Data::Dumper;
use PDF::API2::Tweaks;

my $output;

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( Music::iRealPro::Parser->new( debug => $options->{debug} ), $pkg );

    for ( qw( trace debug verbose output ) ) {
	$self->{$_} = $options->{$_};
    }
    $self->{songbook} = [];
    $self->{pdf} = PDF::API2->new;

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

sub close {
    my ( $self ) = @_;
    return unless $self->{pdf};
    $self->{pdf}->saveas($self->{output});
    delete $self->{pdf};
}

sub parsefile {
    my ( $self, $file, $options ) = @_;
    if ( open( my $fd, '<', $file ) ) {
	my $data = do { local $/; <$fd> };
	# Extract URL.
	$data =~ s;^.*(irealb(?:ook)?://.*?)(?:$|\").*;$1;s;
	$self->decode_playlist($data);
	return;
    }
    die("$file: $!\n");
}

my %smufl =
  ( barlineSingle	=> "\x{e030}",
    barlineDouble	=> "\x{e031}",
    barlineFinal	=> "\x{e032}",
    repeatLeft		=> "\x{e040}",
    repeatRight		=> "\x{e041}",
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

sub interpret {
    my ( $self, $song, $tokens ) = @_;
warn(Dumper($song));
warn(Dumper($tokens));
    my $pdf = $self->{pdf};
    my $page = $pdf->page;
    $page->mediabox('A4');
    my $text = $page->text;
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
    my $dx = ( $rm - $lm ) / 16;
    my $dy = ( $tm - $bm ) / 16;
    my $x = $lm;
    my $y = $tm;

    $text->font( $titlefont, 20);
    $text->textcline( ($lm+$rm)/2-3, $y+80, $song->{title} );
    $text->font( $textfont, 17);
    $text->textline( $x-3, $y+50, $song->{composer} );
    $text->textrline( $rm+3, $y+50, "(".$song->{style}.")" );

    my $prev = [];
    my $new_cell = sub {
	$prev = [ $x, $y ];
	$x += $dx;
	if ( $x > $rm ) {
	    $x = $lm;
	    $y -= $dy;
	}
    };

    our $glyph = sub {
	my ( $x, $y, $smc, $size ) = @_;
	$text->font( $musicfont, $size || $musicsize );
	die("Unknown glyph: $smc") unless exists $musicglyphs->{$smc};
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

    my $measure;		# current measure
    my $new_measure = sub {
	my $last = shift;
	$glyph->( $x, $y, "barlineSingle" );
	if ( !$last && $x >= $rm ) {
	    $new_cell->();
	    $glyph->( $x, $y, "barlineSingle" );
	}
    };

    my $section;		# current section
    my $new_section = sub {
	$section = { type    => "section",
		     content => [],
		     tokens  => [ @_ > 0 ? @_ : () ],
		   };
	$new_measure->();
    };

    #$new_section->();
    my $res;
    my $i = 0;
    my $barskip = 0;
    my $chordsize = 20;

    foreach my $t ( @$tokens ) {
	$i++;

	my $done = 0;

	if ( $t eq "start section" ) {
	    $glyph->( $x, $y, "barlineDouble" );
	    next;
	}

	if ( $t eq "start repeat" ) {
	    $glyphx->( $x, $y, "repeatLeft" );
	    next;
	}

	if ( $t eq "end repeat" ) {
	    $glyphx->( $x, $y, "repeatRight" );
	    $new_cell->() if $x >= $rm;
	    next;
	}

	if ( $t =~ /time (\d+)\/(\d+)/ ) {
	    my ( $t1, $t2 ) = ( $1, $2 );
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

	if ( $t =~ /^hspace\s+(\d+)$/ ) {
	    $x += $1 * $dx;
	    if ( $x >= $rm ) {
		$x = $lm;
		$y -= $dy;
	    }
	    next;
	}

	if ( $t eq "end" ) {
	    $glyph->( $x, $y, "barlineFinal" );
	    next;
	}

	if ( $t eq "end section" ) {
	    $glyph->( $x, $y, "barlineDouble" );
	    $new_cell->();
	    next;
	}

	if ( $t eq "bar" ) {
	    $new_measure->();
	    next;
	}

	if ( $t eq "segno" || $t eq "coda" ) {
	    local $glyph = $glyphl;
	    $glyphx->( $x+3, $y+$musicsize+4, $t, $musicsize*0.7 );
	    next;
	}

	if ( $t eq "fermata" ) {
	    local $glyph = $glyphl;
	    $glyphx->( $x+3, $y+$musicsize+4, $t );
	    next;
	}

	if ( $t =~ /^chord\s+(.*)$/ ) {
	    my $c = $1;

	    if ( $c =~ s/\((.+)\)// ) {
		my $a = $1;
		$a =~ s/(?:\*m\*|-)/m/;
		my ( $x, $y ) = $c ? ( $x, $y ) : @$prev;
		$text->font( $chordfont, 14 );
		$text->translate( $x+3, $y+20 );
		$text->text($a);
		next unless $c;
	    }


	    $c =~ s/(?:\*m\*|-)/m/;
	    $text->font( $chordfont, $chordsize );
	    $text->translate( $x+3, $y );
	    $text->text($c);
	    $new_cell->();
	    next;
	}

	if ( $t =~ /^alternative\s+(\d)$/ ) {
	    my $n = $1;
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

	if ( $t eq "small" ) {
	    #### TODO: Not smaller, but narrower!
	    $chordsize = 14;
	    next;
	}

	if ( $t eq "large" ) {
	    $chordsize = 20;
	    next;
	}

	if ( $t =~ /^mark (.)/ ) {
	    $t = $1;
	    $text->font( $markfont, 12 );
	    $t = "Intro" if $t eq 'i';
	    $t = "Verse" if $t eq 'v';
	    $text->fillcolor("#ff0000");
	    $text->textline( $x-6, $y+22, $t);
	    $text->fillcolor("#000000");
	    next;
	}

	if ( $t =~ /^text\s+(\d+)\s(.*)/ ) {
	    $text->font( $textfont, 10);
	    $text->fillcolor("#ff0000");
	    $text->textline( $x, $y+($1/3), $2 );
	    $text->fillcolor("#000000");
	    next;
	}

	if ( $t =~ /^advance\s+(\d+)$/ ) {
	    $new_cell->() for 1..$1;
	    next;
	}

	if ( $t =~ /^measure repeat (single|double)$/ ) {
	    $text->font( $musicfont, $chordsize );
	    my $c = $1 eq "single" ? "repeat1Bar" : "repeat2Bars";
	    $text->textline( $x+3, $y+5, $musicglyphs->{$c} );
	    $new_cell->();
	    next;
	}

	if ( $t =~ /^slash repeat$/ ) {
	    $text->font( $chordfont, $chordsize );
	    $text->textline( $x+8, $y, "/" );
	    $new_cell->();
	    next;
	}

	next;

    }
}

1;
