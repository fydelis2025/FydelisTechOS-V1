use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'FydelisHash',
    VERSION      => '2.0.0',
    AUTHOR       => 'Adiel Santos Fontes',
    ABSTRACT     => 'Hash Cracking Framework for Authorized Security Testing',
    PREREQ_PM    => {
        'Moo'                 => '2.0',
        'Types::Standard'     => '1.0',
        'Try::Tiny'           => '0.30',
        'Time::HiRes'         => '1.97',
        'Term::ANSIColor'     => '4.0',
        'Digest::MD5'         => '2.50',
        'Digest::SHA'         => '6.0',
        'Digest::MD4'         => '0',
        'MIME::Base64'        => '3.00',
        'Encode'              => '3.0',
        'List::Util'          => '1.50',
        'POSIX'               => '1.30',
    },
    EXE_FILES    => ['fydelishash.pl'],
);