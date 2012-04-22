#! /usr/bin/perl -w
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'viewgcov',
    AUTHOR              => q{Richard Kettlewell <rjk@greenend.org.uk>},
    VERSION_FROM        => 'bin/viewgcov',
    ABSTRACT            => "Graphical display of gcov output files",
    LICENSE             => 'gpl',
#    MAN1PODS => {
#        'bin/viewgcov' => 'blib/man1/viewgcov',
#    },
    EXE_FILES => [ 'bin/viewgcov' ],
    PREREQ_PM => {
        'Gtk2' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Greenend-ViewGCOV-Foo-*' },
);
