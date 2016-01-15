#! perl

# iReal2pdf -- print iRealPro songs

# Author          : Johan Vromans
# Created On      : Fri Jan 15 19:15:00 2016
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jan 16 00:02:33 2016
# Update Count    : 140
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

    my $new_cell = sub {
	$x += $dx;
	if ( $x > $rm ) {
	    $x = $lm;
	    $y -= $dy;
	}
    };


    my $draw_bar = sub {
	my $gfx = $page->gfx;
	$gfx->save;
	$gfx->linewidth(1);
	$gfx->strokecolor("#000000");
	$gfx->move( $x, $y-5 );
	$gfx->line( $x, $y+($dy-22) );
	$gfx->stroke;
	$gfx->restore;
    };
    my $draw_dbar = sub {
	my $gfx = $page->gfx;
	$gfx->save;
	$gfx->linewidth(1);
	$gfx->strokecolor("#000000");
	$gfx->move( $x-1.5, $y-5 );
	$gfx->line( $x-1.5, $y+($dy-22) );
	$gfx->stroke;
	$gfx->move( $x+1.5, $y-5 );
	$gfx->line( $x+1.5, $y+($dy-22) );
	$gfx->stroke;
	$gfx->restore;
    };
    my $draw_repeat = sub {
	my $open = shift;
	my $gfx = $page->gfx;
	$gfx->save;
	$gfx->linewidth(1);
	$gfx->strokecolor("#ff0000");
	$text->strokecolor("#ff0000");
	$text->fillcolor("#ff0000");
	my $x = $x + 1.5;
	$x -= 4 if $open;
	$gfx->move( $x, $y-5 );
	$gfx->line( $x, $y+($dy-22) );
	$gfx->stroke;
	$x += 4 if $open;
	$text->font( $textfont, 20 );
	$text->textline( $x-5, $y+2, ":" );
	$gfx->stroke;
	$gfx->restore;
	$text->strokecolor("#000000");
	$text->fillcolor("#000000");
    };
    my $draw_end = sub {
	my $gfx = $page->gfx;
	$gfx->save;
	$gfx->linewidth(1);
	$gfx->strokecolor("#000000");
	$gfx->move( $x-2, $y-5 );
	$gfx->line( $x-2, $y+($dy-22) );
	$gfx->stroke;
	$gfx->linewidth(2);
	$gfx->move( $x+1, $y-5 );
	$gfx->line( $x+1, $y+($dy-22) );
	$gfx->stroke;
	$gfx->restore;
    };
    my $draw_time = sub {
	my ( $t1, $t2 ) = @_;
	my $gfx = $page->gfx;
	$gfx->save;
	$gfx->linewidth(0.6);
	$text->font( $textfont, 12 );
	$gfx->strokecolor("#ff0000");
	$text->strokecolor("#ff0000");
	$text->fillcolor("#ff0000");
	my $x = $x - 6;
	my $y = $y + 9;
	$text->textcline( $x, $y, $t1);
	$y -= 12;
	$text->textcline( $x, $y, $t2);
	$gfx->move($x-3, $y+10.5);
	$gfx->line($x+3, $y+10.5);
	$gfx->stroke;
	$gfx->restore;
	$text->strokecolor("#000000");
	$text->fillcolor("#000000");
    };

    my $measure;		# current measure
    my $new_measure = sub {
	my $last = shift;
	$draw_bar->();
	if ( !$last && $x >= $rm ) {
	    $new_cell->();
	    $draw_bar->();
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
	    $draw_dbar->();
	    next;
	}

	if ( $t eq "start repeat" ) {
	    $draw_repeat->(1);
	    next;
	}

	if ( $t eq "end repeat" ) {
	    $draw_repeat->(0);
	    $new_cell->();
	    next;
	}

	if ( $t =~ /time (\d+)\/(\d+)/ ) {
	    $draw_time->($1, $2);
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
	    $draw_end->();
	    next;
	}

	if ( $t eq "end section" ) {
	    $draw_dbar->();
	    $new_cell->();
	    next;
	}

	if ( $t eq "bar" || $t eq "end repeat" ) {
	    $new_measure->();
	    next;
	}

	if ( $t =~ /^chord\s+(.*)$/ ) {
	    $text->font( $chordfont, $chordsize );
	    my $c = $1;
	    $c =~ s/(?:\*m\*|-)/m/;
	    $text->textline( $x+3, $y, $c );
	    $new_cell->();
	    next;
	}

	if ( $t eq "small" ) {
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
	    $text->strokecolor("#ff0000");
	    $text->fillcolor("#ff0000");
	    $text->textline( $x-4, $y+22, $t);
	    $text->strokecolor("#000000");
	    $text->fillcolor("#000000");
	    next;
	}

	if ( $t =~ /^text\s+(\d+)\s+(.*)/ ) {
	    $text->font( $textfont, 10);
	    $text->strokecolor("#ff0000");
	    $text->fillcolor("#ff0000");
	    $text->textline( $x, $y+($1/3), $2 );
	    $text->strokecolor("#000000");
	    $text->fillcolor("#000000");
	    next;
	}

	if ( $t =~ /^advance\s+(\d+)$/ ) {
	    $new_cell->() for 1..$1;
	    next;
	}

	if ( $t =~ /^measure repeat (single|double)$/ ) {
	    $text->font( $chordfont, $chordsize );
	    my $c = $1 eq "single" ? "%" : "%%";
	    $text->textline( $x+2, $y, $c );
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
