package FydelisAI::Tools;
use v5.20;
use strict;
use warnings;
use Moo;
use IPC::Open3;
use Symbol qw(gensym);
use POSIX qw(strftime);

has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );

sub is_command_allowed {
    my ($self, $cmd) = @_;

    return 0 unless defined $cmd;

    my ($base) = $cmd =~ /^(\S+)/;
    $base =~ s/^.*\///;

    my $allowed = $self->config->allowed_commands;
    return 0 unless grep { $_ eq $base } $allowed->@*;

    my $blocked = $self->config->blocked_patterns;
    for my $pat ($blocked->@*) {
        return 0 if $cmd =~ /\Q$pat\E/i;
    }

    return 0 if length($cmd) > $self->config->max_command_length;

    return 1;
}

sub execute {
    my ($self, $cmd, $timeout) = @_;

    $timeout //= 60;

    my $clean_cmd = $self->sanitize($cmd);
    return { success => 0, error => "Comando vazio após sanitização" } unless $clean_cmd;

    unless ($self->is_command_allowed($clean_cmd)) {
        $self->logger->warn("Comando não permitido: %s", $clean_cmd);
        return { success => 0, error => "Comando não está na lista de permitidos" };
    }

    if ($self->config->confirm_before_exec) {
        print "\n⚠️  Comando a ser executado:\n";
        print "  $clean_cmd\n\n";
        print "Executar? [S/n]: ";
        my $answer = <STDIN>;
        chomp $answer;
        return { success => 0, error => "Cancelado pelo usuário" }
            if $answer =~ /^n/i;
    }

    $self->logger->info("Executando: %s", $clean_cmd);
    $self->logger->debug("Timeout: %ds", $timeout);

    my $result = {
        success  => 0,
        stdout   => '',
        stderr   => '',
        exitcode => -1,
        elapsed  => 0,
    };

    my $start = time();

    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm $timeout;

        my ($in, $out, $err);
        $err = gensym;

        # Adiciona o interpretador no Windows mantendo a execução direta no Linux
        my $exec_cmd = $^O eq 'MSWin32' ? "cmd.exe /c $clean_cmd" : $clean_cmd;
        my $pid = open3($in, $out, $err, $exec_cmd);

        waitpid($pid, 0);
        alarm 0;

        $result->{exitcode} = $? >> 8;
        $result->{stdout}   = do { local $/; <$out> // '' };
        $result->{stderr}   = do { local $/; <$err> // '' };
        $result->{success}  = $result->{exitcode} == 0;

        close $in;
        close $out;
        close $err;
    };
    if ($@) {
        alarm 0;
        if ($@ eq "TIMEOUT\n") {
            $result->{error} = "Timeout após ${timeout}s";
            $result->{stdout} .= "\n[PROCESSO ENCERRADO POR TIMEOUT]";
        } else {
            $result->{error} = $@;
        }
    };

    $result->{elapsed} = time() - $start;

    $self->_save_output($clean_cmd, $result);

    if ($result->{success}) {
        $self->logger->info("  ✅ Comando concluído em %.1fs (exit: %d)",
            $result->{elapsed}, $result->{exitcode});
    } else {
        $self->logger->warn("  ⚠️  Comando falhou (exit: %d): %s",
            $result->{exitcode}, $result->{error} // '');
    }

    if ($self->config->verbose && $result->{stdout}) {
        $self->logger->output("  STDOUT:\n%s", $result->{stdout});
    }

    return $result;
}

sub sanitize {
    my ($self, $cmd) = @_;
    return undef unless defined $cmd;

    $cmd =~ s/^\s+|\s+$//g;
    $cmd =~ s/[\r\n]+/ /g;
    $cmd =~ s/\s+/ /g;

    $cmd =~ s/[|;&`\$]//g;

    $cmd = substr($cmd, 0, $self->config->max_command_length);

    return $cmd;
}

sub _save_output {
    my ($self, $cmd, $result) = @_;

    my $dir = $self->config->output_dir;
    mkdir $dir unless -d $dir;

    my $timestamp = strftime('%Y%m%d_%H%M%S', localtime);
    my ($base) = $cmd =~ /^(\S+)/;
    $base =~ s/^.*\///;
    $base =~ s/[^a-zA-Z0-9_-]/_/g;

    my $file = "$dir/${timestamp}_${base}.txt";
    my $idx = 1;
    while (-f $file) {
        $file = "$dir/${timestamp}_${base}_$idx.txt";
        $idx++;
    }

    eval {
        open my $fh, '>', $file or return;
        print $fh "Comando: $cmd\n";
        print $fh "Executado em: " . strftime('%Y-%m-%d %H:%M:%S', localtime) . "\n";
        print $fh "Exit code: $result->{exitcode}\n";
        print $fh "Duração: ${\($result->{elapsed})}s\n";
        print $fh "-" x 70 . "\n";
        print $fh $result->{stdout} if $result->{stdout};
        print $fh "\n" . "-" x 70 . "\n";
        print $fh "STDERR:\n$result->{stderr}" if $result->{stderr};
        close $fh;
    };
    if ($@) {
        $self->logger->warn("Falha ao salvar output: %s", $@);
    }
}

1;