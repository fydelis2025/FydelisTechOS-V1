package FydelisHash::Config;
use v5.20;
use strict;
use warnings;
use Moo;
use Types::Standard qw(Str Int ArrayRef Maybe Bool HashRef);

# ── Hash alvo ────────────────────────────────────────
has target_hash => (
    is       => 'ro',
    isa      => Str,
    predicate => 1,
);

has target_hashes => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

has hash_type => (
    is      => 'ro',
    isa     => Str,
    default => 'auto',  # auto = detectar pelo formato
);

# ── Wordlist ──────────────────────────────────────────
has wordlist => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

# ── Regras de mutação ────────────────────────────────
has rules => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },  # regras inline
);

has rules_file => (
    is       => 'ro',
    isa      => Maybe[Str],
    predicate => 1,
);

# ── Performance ───────────────────────────────────────
has threads => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 64 }),
    default => 4,
);

# ── Comportamento ─────────────────────────────────────
has stop_on_first => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has case_permutations => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has append_numbers => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has number_range => (
    is      => 'ro',
    isa     => Str,
    default => '0-9999',
);

has min_length => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 }),
    default => 1,
);

has max_length => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 256 }),
    default => 128,
);

# ── Salt ──────────────────────────────────────────────
has salt => (
    is       => 'ro',
    isa      => Maybe[Str],
    predicate => 1,
);

# ── Saída ─────────────────────────────────────────────
has output_file => (
    is       => 'ro',
    isa      => Maybe[Str],
    predicate => 1,
);

has logfile => (
    is       => 'ro',
    isa      => Maybe[Str],
    predicate => 1,
);

has verbose => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has quiet => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

# ── Hash types suportados ────────────────────────────
my %HASH_PATTERNS = (
    md5        => qr/^[a-f0-9]{32}$/i,
    sha1       => qr/^[a-f0-9]{40}$/i,
    sha256     => qr/^[a-f0-9]{64}$/i,
    sha512     => qr/^[a-f0-9]{128}$/i,
    sha224     => qr/^[a-f0-9]{56}$/i,
    sha384     => qr/^[a-f0-9]{96}$/i,
    ntlm       => qr/^[a-f0-9]{32}$/i,  # mesmo tamanho MD5, mas diferenciamos por uppercase geralmente
    lm         => qr/^[a-f0-9]{32}$/i,
    md4        => qr/^[a-f0-9]{32}$/i,
    sha512_256 => qr/^[a-f0-9]{64}$/i,
    blake2b    => qr/^[a-f0-9]{128}$/i,
    gost       => qr/^[a-f0-9]{64}$/i,
    whirlpool  => qr/^[a-f0-9]{128}$/i,
    sha3_256   => qr/^[a-f0-9]{64}$/i,
    sha3_512   => qr/^[a-f0-9]{128}$/i,
);

# Formatos com $ (Unix crypt-style)
my @CRYPT_HASHES = qw(bcrypt sha512_crypt sha256_crypt md5_crypt);

sub detect_hash_type {
    my ($self, $hash) = @_;

    return 'bcrypt'        if $hash =~ /^\$2[ayb]\$\d{2}\$/;
    return 'sha512_crypt'  if $hash =~ /^\$6\$/;
    return 'sha256_crypt'  if $hash =~ /^\$5\$/;
    return 'md5_crypt'     if $hash =~ /^\$1\$/;

    # Remover possíveis separadores (username:hash)
    my $clean = $hash;
    $clean =~ s/^.*?://;  # remove user: prefix if present
    $clean = lc($clean);

    # Try to match by length
    my $len = length($clean);
    
    return 'md5'       if $len == 32 && $clean =~ /^[a-f0-9]{32}$/;
    return 'sha1'      if $len == 40 && $clean =~ /^[a-f0-9]{40}$/;
    return 'sha256'    if $len == 64 && $clean =~ /^[a-f0-9]{64}$/;
    return 'sha512'    if $len == 128 && $clean =~ /^[a-f0-9]{128}$/;
    return 'sha224'    if $len == 56 && $clean =~ /^[a-f0-9]{56}$/;
    return 'sha384'    if $len == 96 && $clean =~ /^[a-f0-9]{96}$/;

    return 'unknown';
}

sub available_hash_types {
    return [keys %HASH_PATTERNS, @CRYPT_HASHES];
}

sub is_valid_hash_type {
    my ($self, $type) = @_;
    my @all = ($self->available_hash_types->@*, 'auto');
    return grep { $_ eq lc($type) } @all;
}

1;