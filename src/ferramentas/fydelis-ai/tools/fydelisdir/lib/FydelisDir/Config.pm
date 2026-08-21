package FydelisDir::Config;
use v5.20;
use strict;
use warnings;
use Moo;
use Types::Standard qw(Str Int ArrayRef Maybe Bool);

# ── Alvo ──────────────────────────────────────────────
has host => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has port => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 65535 }),
    default => 80,
);

has ssl => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has base_path => (
    is      => 'ro',
    isa     => Str,
    default => '/',
);

# ── Wordlist ──────────────────────────────────────────
has wordlist => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

has extensions => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { ['' => 'php', 'html', 'htm', 'asp', 'aspx', 'jsp', 'txt', 'bak', 'old', 'inc'] },
);

# ── Performance ───────────────────────────────────────
has threads => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 50 }),
    default => 10,
);

has delay_ms => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 0 && $_ <= 10_000 }),
    default => 0,
);

has request_timeout => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 120 }),
    default => 10,
);

# ── Filtros ───────────────────────────────────────────
has valid_status_codes => (
    is      => 'ro',
    isa     => ArrayRef[Int],
    default => sub { [200, 201, 204, 301, 302, 307, 401, 403, 405, 500] },
);

has min_response_size => (
    is      => 'ro',
    isa     => Int,
    default => 0,     # 0 = sem filtro
);

has exclude_text => (
    is      => 'ro',
    isa     => Maybe[Str],
    default => undef, # texto que indica "not found" no body
);

# ── Autenticação ──────────────────────────────────────
has username => (
    is      => 'ro',
    isa     => Maybe[Str],
    default => undef,
);

has password => (
    is      => 'ro',
    isa     => Maybe[Str],
    default => undef,
);

# ── Comportamento ─────────────────────────────────────
has follow_redirects => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has max_redirects => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 0 && $_ <= 20 }),
    default => 5,
);

has recursion_depth => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 0 && $_ <= 5 }),
    default => 0,
);

has user_agent => (
    is      => 'ro',
    isa     => Str,
    default => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
);

has rotate_agents => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
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
    default => 0,   # só mostra resultados
);

# ── Helpers ───────────────────────────────────────────
sub protocol {
    my $self = shift;
    return $self->ssl ? 'https' : 'http';
}

sub base_url {
    my $self = shift;
    my $url = sprintf('%s://%s', $self->protocol, $self->host);
    $url .= ":$self->port" if ($self->port != 80 && !$self->ssl)
                           || ($self->port != 443 && $self->ssl);
    my $bp = $self->base_path;
    $bp =~ s{/$}{};
    $url .= $bp if $bp;
    return $url;
}

sub has_auth {
    my $self = shift;
    return defined $self->username && defined $self->password;
}

1;