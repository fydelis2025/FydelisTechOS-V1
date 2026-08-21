package FydelisAI::Logger;
use v5.20;
use strict;
use warnings;
use Moo;
use Types::Standard qw(Maybe Str);
use POSIX qw(strftime);
use Term::ANSIColor qw(color colored);

use constant {
    DEBUG    => 0,
    INFO     => 1,
    WARN     => 2,
    ERROR    => 3,
    CRITICAL => 4,
    OUTPUT   => 5,  # saída do LLM ou comandos
};

has level => (
    is      => 'ro',
    default => INFO,
);

has logfile => (
    is       => 'ro',
    isa      => Maybe[Str],
    predicate => 1,
);

has _fh => (
    is      => 'lazy',
    clearer => 1,
);

sub _build__fh {
    my $self = shift;
    return undef unless $self->has_logfile;
    open my $fh, '>>', $self->logfile
        or die "Cannot open logfile '${\$self->logfile}': $!";
    $fh->autoflush(1);
    return $fh;
}

my %LEVEL_NAMES = (
    DEBUG    => 'DEBUG',
    INFO     => ' INFO',
    WARN     => ' WARN',
    ERROR    => 'ERROR',
    CRITICAL => 'CRIT ',
    OUTPUT   => 'OUT  ',
);

my %LEVEL_COLORS = (
    DEBUG    => 'bright_black',
    INFO     => 'green',
    WARN     => 'yellow',
    ERROR    => 'red',
    CRITICAL => 'bold red',
    OUTPUT   => 'cyan',
);

sub _log {
    my ($self, $level_num, $level_name, $message, @args) = @_;
    return if $level_num < $self->level;

    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $formatted = sprintf "[%s] [%s] %s",
        $timestamp, $level_name, sprintf($message, @args);

    # STDOUT colorido
    say colored($formatted, $LEVEL_COLORS{$level_name});

    # Arquivo
    if (my $fh = $self->_fh) {
        say $fh $formatted;
    }
}

sub debug    { shift->_log(DEBUG,    'DEBUG',    @_); }
sub info     { shift->_log(INFO,     ' INFO',    @_); }
sub warn     { shift->_log(WARN,     ' WARN',    @_); }
sub error    { shift->_log(ERROR,    'ERROR',    @_); }
sub critical { shift->_log(CRITICAL, 'CRIT ',    @_); }
sub output   { shift->_log(OUTPUT,   'OUT  ',    @_); }

sub progress {
    my ($self, $message) = @_;
    return if DEBUG > $self->level;
    print "\r\033[K$message";
}

sub done_progress {
    print "\r\033[K";
}

sub DESTROY {
    my $self = shift;
    if (my $fh = $self->_fh) {
        close $fh;
    }
}

1;