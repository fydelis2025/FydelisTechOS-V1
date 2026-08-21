use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'FydelisAI',
    VERSION      => '2.0.0',
    AUTHOR       => 'Adiel Santos Fontes',
    ABSTRACT     => 'AI-Powered Security Assessment Assistant',
    PREREQ_PM    => {
        'Moo'                => '2.0',
        'Types::Standard'    => '1.0',
        'Try::Tiny'          => '0.30',
        'Time::HiRes'        => '1.97',
        'Term::ANSIColor'    => '4.0',
        'JSON'               => '4.0',
        'HTTP::Tiny'         => '0.01',
        'IO::Handle'         => '1.30',
        'IO::Socket::INET'   => '1.30',
        'IPC::Open3'         => '1.20',
        'Symbol'             => '1.07',
        'Digest::SHA'        => '6.0',
        'File::Path'         => '2.10',
        'File::Spec'         => '3.70',
        'File::HomeDir'      => '1.0',
        'POSIX'              => '1.30',
    },
    BUILD_REQUIRES => {
        'YAML::XS'           => '0',
    },
    EXE_FILES    => ['fydelis-ai'],
    clean        => { FILES => 'FydelisAI-*' },
);