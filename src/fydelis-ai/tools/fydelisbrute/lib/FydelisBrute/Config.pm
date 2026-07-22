package FydelisBrute::Config;
use v5.20;
use strict;
use warnings;
use Moo;
use Types::Standard qw(Str Int Enum ArrayRef Maybe Bool);

# ── Atributos validados ──────────────────────────────────
has host => (
    is       => 'ro',
    isa      => Str,
    required => 1,
    predicate => 1,
);

has port => (
    is       => 'ro',
    isa      => Int->where(sub { $_ > 0 && $_ < 65536 }),
    required => 1,
);

has protocol => (
    is       => 'ro',
    isa      => Enum[qw/ftp ftps ssh telnet smtp pop3 imap http https mysql mssql postgres/],
    required => 1,
);

has usernames => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

has passwords => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

has threads => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 50 }),
    default => 5,
);

has timeout => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 120 }),
    default => 10,
);

has stop_on_first => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
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

has output_file => (
    is       => 'ro',
    isa      => Maybe[Str],
    predicate => 1,
);

has max_retries => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 0 && $_ <= 10 }),
    default => 2,
);

has delay_between => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 0 && $_ <= 60_000 }),
    default => 0,  # milissegundos
);

sub total_combinations {
    my $self = shift;
    return scalar($self->usernames->@*) * scalar($self->passwords->@*);
}

sub protocol_handler_name {
    my $self = shift;
    return "_handle_" . $self->protocol;
}

1;