#! perl

package Music::iRealBook;

use warnings;
use strict;

=head1 NAME

Music::iRealBook - Programmatically build songs for iReal-B

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

Song API (simple):

  use Music::iRealBook::Song;

  # Define a song
  song "Funky Perl";
  tempo 120;
  style "Medium Swing";
  key "Dm";

  # Define a section (song part)
  section "Funky Section";

  # Add chords.
  Dm7 4; Am7; Dm7; Dm7;

Song API (explicit chords):

  # Add chords.
  chord "D Min7 4";
  chord "A Min7 4";
  chord "D Min7 4";
  chord "D Min7 4";

Opus API (powerful):

  use Music::iRealBook::Opus;
  use Music::iRealBook::Opus::Section;

  # The song.
  my $song = Music::iRealBook::Opus->new(
      name => "Funky Perl", composer = "Me", tempo => 120,
      style => "Medium Swing", key => "Dm" );

  # One section.
  my $section = Music::iRealBook::Opus::Section->new(
      name => "Funky Section" );

  $section->add_chord( "D Min7 4" );
  $section->add_chord( "A Min7 4" );
  $section->add_chord( "D Min7 4" );
  $section->add_chord( "D Min7 4" );

  # Add section to song.
  $song->add_section($section);

  # Print export data.
  print $song->irealbook, "\n";

  # Print HTML for a page accessing this data.
  # This is the way to import to iReal-B.
  print $song->html, "\n";

=head1 DESCRIPTION

iReal-B is a songwriting tool / electronic backup band for
iPhone/iPad, Mac OSX and Android that lets you experiment with
advanced chord progressions and arrangements quickly and easily. You
can use iReal-B for songwriting experiments, as accompaniment when
learning new songs or for making backing tracks for your guitar /
saxophone / theremin solos.

iReal-B can import songs in one of two textual format formats. The
'irealbook' format is easily readable and straightforward. The
official 'irealb' format is proprietary and uses some form of
scrambling to hide the contents. Music::iRealBook provides a set of
modules that can be used to programmatically build songs and produce
the in irealbook formatted data suitable for import into iReal-B.

iReal-B web site: L<http://www.irealb.com>.

Web editor: L<http://www.irealb.com/editor>.

Music::iRealBook is built on top op the Music::ChordBot toolkit.

=head1 AUTHOR

Johan Vromans, C<< <jv at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-music-irealbook at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Music-iRealBook>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Music::iRealBook
    perldoc Music::iRealBook::Song
    perldoc Music::iRealBook::Opus

=head1 ACKNOWLEDGEMENTS

Massimo Biolcati of Technimo LLC, for writing iReal-B.

The iReal-B community, for contributing many, many songs.

=head1 COPYRIGHT & LICENSE

Copyright 2013 Johan Vromans, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
