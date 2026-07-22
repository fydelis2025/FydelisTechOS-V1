package FydelisAI::Config;
use v5.20;
use strict;
use warnings;
use Moo;
use Types::Standard qw(Str Int ArrayRef Maybe Bool HashRef Num);
use File::Spec;
use File::HomeDir;

# ── Ollama ──────────────────────────────────────────
has ollama_url => (
    is      => 'ro',
    isa     => Str,
    default => 'http://localhost:11434',
);

has ollama_model => (
    is      => 'ro',
    isa     => Str,
    default => 'gemma:latest',
);

has ollama_timeout => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 300 }),
    default => 120,
);

has ollama_stream => (
    is      => 'ro',
    isa     => Bool,
    default => 1,   # streaming ativado por padrão
);

has ollama_temperature => (
    is      => 'ro',
    isa     => Num->where(sub { $_ >= 0 && $_ <= 2 }),
    default => 0.7,
);

has ollama_max_tokens => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 }),
    default => 2048,
);

# ── Comportamento ──────────────────────────────────
has auto_execute => (
    is      => 'ro',
    isa     => Bool,
    default => 0,   # nunca executar sem confirmação
);

has confirm_before_exec => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has save_sessions => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has session_dir => (
    is      => 'ro',
    isa     => Str,
    default => sub {
        my $home = File::HomeDir->my_home || '.';
        return File::Spec->catdir($home, '.fydelis-ai', 'sessions');
    },
);

has cache_enabled => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has cache_ttl => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 0 }),
    default => 3600,  # 1 hora
);

# ── Segurança ───────────────────────────────────────
has allowed_commands => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [qw(nmap curl gobuster dirb hydra john hashcat sqlmap nikto wpscan)] },
);

has blocked_patterns => (
    is       => 'ro',
    isa      => ArrayRef[Str],
    default => sub { [qw(rm -rf dd if= :(){ :|:& };: mkfs format)] },
);

has max_command_length => (
    is      => 'ro',
    isa     => Int,
    default => 4096,
);

# ── Output ─────────────────────────────────────────
has output_dir => (
    is      => 'ro',
    isa     => Str,
    default => 'output',
);

has verbose => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has logfile => (
    is       => 'ro',
    isa      => Maybe[Str],
    predicate => 1,
);

# ── Factory ────────────────────────────────────────
sub from_file {
    my ($class, $file) = @_;

    my %args;

    if ($file && -f $file) {
        if ($file =~ /\.ya?ml$/i) {
            require YAML::XS;
            my $yaml = YAML::XS::LoadFile($file);
            %args = $class->_flatten_yaml($yaml);
        } elsif ($file =~ /\.json$/i) {
            require JSON;
            open my $fh, '<', $file or die "Cannot open $file: $!";
            local $/;
            my $json = <$fh>;
            close $fh;
            my $data = JSON::decode_json($json);
            %args = $class->_flatten_yaml($data);
        }
    }

    # Environment variables sobrescrevem
    $args{ollama_url}        //= $ENV{AI_OLLAMA_URL}        // 'http://localhost:11434';
    $args{ollama_model}      //= $ENV{AI_OLLAMA_MODEL}      // 'gemma:latest';
    $args{ollama_timeout}    //= $ENV{AI_OLLAMA_TIMEOUT}    // 60;
    $args{verbose}           //= $ENV{AI_VERBOSE}           // 0;

    return $class->new(%args);
}

sub _flatten_yaml {
    my ($class, $data) = @_;
    my %flat;
    for my $key (keys %$data) {
        my $value = $data->{$key};
        if (ref $value eq 'HASH') {
            for my $sub (keys %$value) {
                $flat{"${key}_${sub}"} = $value->{$sub};
            }
        } else {
            $flat{$key} = $value;
        }
    }
    return %flat;
}

1;