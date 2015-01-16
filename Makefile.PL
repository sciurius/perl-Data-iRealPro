use strict;
use warnings;
use ExtUtils::MakeMaker;
use 5.010;

WriteMakefile(
    NAME                => 'Music::iRealBook',
    AUTHOR              => 'Johan Vromans <jv@cpan.org>',
    VERSION_FROM        => 'lib/Music/iRealBook.pm',
    ABSTRACT_FROM       => 'lib/Music/iRealBook.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
	'Music::ChordBot' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Music-iRealBook-*' },
);
