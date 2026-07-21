use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'FydelisDir',
    VERSION      => '2.0.0',
    AUTHOR       => 'Adiel Santos Fontes',
    ABSTRACT     => 'HTTP/HTTPS Path Enumeration Framework',
    PREREQ_PM    => {
        'Moo'                => '2.0',
        'Types::Standard'    => '1.0',
        'Try::Tiny'          => '0.30',
        'Time::HiRes'        => '1.97',
        'Term::ANSIColor'    => '4.0',
        'LWP::UserAgent'     => '6.0',
        'HTTP::Request'      => '6.0',
        'HTTP::Response'     => '6.0',
        'HTTP::Cookies'      => '6.0',
        'IO::Socket::SSL'    => '2.0',
        'POSIX'              => '1.30',
    },
    EXE_FILES    => ['fydelisdir.pl'],
);