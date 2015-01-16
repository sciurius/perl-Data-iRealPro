#! perl

package Music::iRealBook::Song;

use strict;
use warnings;

=head1 NAME

Music::iRealBook::Song - Generate iRealB songs.

=head1 SYNOPSIS

    use Music::iRealBook::Song;
    song "All Of Me";
    composer "Gerard Marks";
    tempo 105;
    style "Medium Swing";

    section "All Of Me 1";

    C 4; C; E7; E7; A7; A7; Dm7; Dm7;
    E7; E7; Am7; Am7; D7; D7; Dm7; G7;

    section "All Of Me 2";

    C 4; C; E7; E7; A7; A7; Dm7; Dm7;
    Dm7; Ebdim7; Em7; A9; Dm7b5; G13;
    C 2; Ebdim7; Dm7; G7;

=head1 DESCRIPTION

Music::iRealBook::Song exports a number of subroutines that can be
used to construct an iRealb song. Upon program termination, the song
is written out to standard output in text format, suitable for import
into the iRealB app.

=cut

our $VERSION = 0.01;

use Music::iRealBook::Opus;
use Music::ChordBot::Opus::Section;

our @EXPORT = qw( song chord composer section timesig tempo Coda
		  style key output irealbook irealb );
use base 'Exporter';

my $song;
my $section;

=head1 SUBROUTINES

=head2 song I<title>

Starts a new song with the given title.

=cut

sub song($) {
    _export() if $song;
    $song = Music::iRealBook::Opus->new( name => shift );
    undef $section;
}

=head2 composer I<title>

Sets the composer name for the song.

=cut

sub composer($) {
    $song->composer(@_);
}

=head2 tempo I<bpm>

Sets the tempo in beats per minute.

=cut

sub tempo($) {
    $song->tempo(@_);
}

=head2 key I<key>

Sets the key for the song.

=cut

sub key($) {
    $song->key(@_);
}

=head2 style I<preset>

Associate the given style to the current song.

=cut

sub style($) {
    $song->set_style(@_);
}

=head2 section I<name>

Starts a song section. A section groups a number of bars with chords.

=cut

sub section($) {
    $section = Music::ChordBot::Opus::Section->new( name => shift );
    $song->add_section( $section );
}

=head2 chord I<key>, I<type>, I<duration>

Append a chord with given key, type and duration. Note that duration
is measured in number of beats. The three arguments may also be
specified in a single string argument, space separated.

You can specify a bass note for the chord by separating the key and
bass with a slash. E.g., C<"C/B"> denotes a C chord with B bass.
C<"Bm/A"> must be entered as C<"B/A Min"> or C<"B Min/A">.

=cut

sub chord($) {
    $section->add_chord( @_ );
}

sub timesig($$) {
    if ( @{ $section->chords } ) {
	$section->add_timesig( @_ );
    }
    else {
	$section->{data}->{style}->{beats} = shift() // 4;
	$section->{data}->{style}->{divider} = shift() // 4;
    }
}

sub Coda {
    $section->add_coda;
}

# Automatically export the song at the end of the program.
sub END {
    _export() if $song;
}

=head2 output [ html | text | plain ]

Selects the type of output to be generated.

B<html> (default): Generates a simple HTML page that provides the song.
This is the way songs are imported into iReal-B.

B<text>: Generates the text of the song only. For convenience, the
text is url-escaped so it can be pasted into the web editor.

B<plain>: Plain, readable text. This is mainly for developemen and
debugging.

=cut

my $output;

sub output {
    if ( $_[0] =~ /^(text|plain)$/i ) {
	$output = lc($1);
    }
    else {
	$output = "html";
    }
}

sub irealbook {
    $song->irealbook( type => $output );
}

sub irealb {
    $song->irealb( type => $output );
}

sub _export {
    my ( $s ) = @_;
    $s //= irealbook;
    binmode( STDOUT, ':utf8');
    print STDOUT $s, "\n";
    undef $song;
}

=head1 QUICK ACCESS CHORDS

For convenience, subroutines are exported for quick access to chords.
So instead of

  chord "C", "Maj", 4;

you can also write:

  C 4;

If you omit the duration it will use the duration of the previous
 chord:

  C 4; C; F; G;		# same as C 4; C 4; F 4; G 4;

The subroutine name is the key of the chord, optionally followed by a
chord modifier. So C<C> is C major, C<Cm> is C minor, and so on.

Chord keys are A B C D E F G Ab Bb Db Eb Gb Ais Cis Dis Fis Gis.

Modifiers are m 7 m7 maj7 9 11 13 aug 7b5 m7b5 dim dim7.

=cut

my $_key = "C";
my $_mod = "Maj";
my $_dur = 4;

sub _chord {
    my ( $key, $mod, $dur ) = @_;
    $_dur = $dur if $dur;
    $section->add_chord( $key, $mod, $_dur  );
}

for my $key ( qw( A B C D E F G
		  Ab Bb Db Eb Gb
		  Ais Cis Dis Fis Gis
	    ) ) {
    my $k2 = $key =~ /^(.)is$/ ? "$1#" : $key;

    my %m = (
       ""      => "Maj",
       "m"     => "Min",
       "7"     => "7",
       "m7"    => "Min7",
       "maj7"  => "Maj7",
       "9"     => "9",
       "11"    => "11",
       "13"    => "13",
       "aug"   => "Aug",
       "7b5"   => "7(b5)",
       "m7b5"  => "Min7(b5)",
       "dim"   => "Dim",
       "dim7"  => "Dim7",
    );

    no strict 'refs';
    while ( my ($k, $t) = each( %m ) ) {
	*{ __PACKAGE__ . '::' . $key.$k } =
	  sub { &_chord( $k2, $t, $_[0] ) };
	push( @EXPORT, $key.$k );
    }
}

# Rest 'chord'.
sub NC { &_chord( "A", "Silence", $_[0] ) }
*S = \&NC;
push( @EXPORT, "S", "NC" );

=head1 DISCLAIMER

There is currently NO VALIDATION of argument values. Illegal values
will result in program crashes and songs that cannot be imported, or
played, by iRealB.

=head1 AUTHOR, COPYRIGHT & LICENSE

See L<Music::iRealBook>.

=cut

1;
