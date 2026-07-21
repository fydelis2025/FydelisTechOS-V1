package FydelisScan::Config;
use v5.20;
use strict;
use warnings;
use Moo;
use Types::Standard qw(Str Int ArrayRef Maybe Bool);

has host => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has ports => (
    is      => 'ro',
    isa     => ArrayRef[Int->where(sub { $_ > 0 && $_ < 65536 })],
    default => sub { [] },
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
    default => 10,
);

has scan_timeout => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 60 }),
    default => 3,
);

has brute_timeout => (
    is      => 'ro',
    isa     => Int->where(sub { $_ >= 1 && $_ <= 120 }),
    default => 8,
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
    default => 1,
);

has only_open_ports => (
    is      => 'ro',
    isa     => Bool,
    default => 1,   # Só testa credenciais em portas abertas
);

has identify_service => (
    is      => 'ro',
    isa     => Bool,
    default => 1,   # Tenta identificar o serviço via banner
);

sub total_combinations {
    my $self = shift;
    return scalar($self->usernames->@*) * scalar($self->passwords->@*);
}

1;