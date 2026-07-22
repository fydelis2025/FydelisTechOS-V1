package FydelisWordlist::Config;
use v5.20;
use strict;
use warnings;
use Moo;
use Types::Standard qw(Str Int ArrayRef Maybe Bool);

# ── Dados base ────────────────────────────────────────
has first_name => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has last_name => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has year => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has location => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has keyword => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has extra_words => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

# ── Opções de mutação ─────────────────────────────────
has min_length => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 }),
    default => 4,
);

has max_length => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 128 }),
    default => 32,
);

has include_numbers => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has include_symbols => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has include_leet => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has include_caps => (
    is      => 'ro',
    isa     => Bool,
    default => 1,   # gera lowercase, UPPERCASE, ucfirst, etc.
);

has include_common_patterns => (
    is      => 'ro',
    isa     => Bool,
    default => 1,   # 123, 2024, @, !, etc.
);

has include_reversed => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has include_doubled => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has include_truncated => (
    is      => 'ro',
    isa     => Bool,
    default => 0,   # primeiras X letras
);

has append_current_year => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has max_combinations => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 0 }),
    default => 10_000_000,  # 10M padrão, 0 = ilimitado
);

has output_file => (
    is      => 'ro',
    isa     => Str,
    default => 'wordlist.txt',
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

sub has_base_data {
    my $self = shift;
    return $self->first_name ne ''
        || $self->last_name  ne ''
        || $self->year       ne ''
        || $self->location   ne ''
        || $self->keyword    ne ''
        || scalar($self->extra_words->@*) > 0;
}

1;