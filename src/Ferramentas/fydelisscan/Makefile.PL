use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'FydelisScan',
    VERSION      => '2.0.0',
    AUTHOR       => 'Adiel Santos Fontes',
    ABSTRACT     => 'Service Scanner + Credential Testing Framework',
    PREREQ_PM    => {
        'Moo'                => '2.0',
        'Types::Standard'    => '1.0',
        'Try::Tiny'          => '0.30',
        'Time::HiRes'        => '1.97',
        'Term::ANSIColor'    => '4.0',
        'IO::Socket::INET'   => '1.30',
        'IO::Select'         => '1.20',
        'MIME::Base64'       => '3.00',
        'POSIX'              => '1.30',
    },
    EXE_FILES    => ['fydelisscan.pl'],
);