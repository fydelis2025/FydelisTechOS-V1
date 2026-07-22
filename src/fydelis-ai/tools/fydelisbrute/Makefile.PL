use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'FydelisBrute',
    VERSION          => '2.0.0',
    AUTHOR           => 'Adiel Santos Fontes',
    ABSTRACT         => 'Credential Testing Framework for Authorized Security Assessments',
    PREREQ_PM        => {
        'Moo'                  => '2.0',
        'MooX::HandlesVia'     => '0.001',
        'Types::Standard'      => '1.0',
        'Try::Tiny'            => '0.30',
        'Time::HiRes'          => '1.97',
        'Term::ANSIColor'      => '4.0',
        'IO::Select'           => '1.20',
        'POSIX'                => '1.30',
        'Scalar::Util'         => '1.40',
    },
    BUILD_REQUIRES    => {},
    EXE_FILES         => ['fydelisbrute.pl'],
    clean             => { FILES => 'FydelisBrute-*' },
);