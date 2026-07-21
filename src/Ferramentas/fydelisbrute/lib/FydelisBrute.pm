package FydelisBrute;
use v5.20;
use strict;
use warnings;
use Moo;
use MooX::HandlesVia;
use Try::Tiny;
use Time::HiRes qw(time usleep);
use POSIX       qw(strftime);
use Scalar::Util qw(weaken);

use FydelisBrute::Config;
use FydelisBrute::Logger;

# ── Atributos ───────────────────────────────────────────
has config   => ( is => 'ro', required => 1 );
has logger   => ( is => 'ro', required => 1 );
has shutdown => ( is => 'ro', isa => \&_is_scalar_ref, default => sub { \my $x = 0 });

has _found       => ( is => 'rw', default => 0 );
has _total       => ( is => 'rw', default => 0 );
has _attempted   => ( is => 'rw', default => 0 );
has _start_time  => ( is => 'rw', default => 0 );
has _results     => ( is => 'rw', default => sub { [] } );

sub _is_scalar_ref {
    return ref($_[0]) eq 'SCALAR';
}

# ── Consumir a Role de Protocolos ──────────────────────
with 'FydelisBrute::Protocols';

# ============================================================
# RUN — Loop principal
# ============================================================
sub run {
    my $self = shift;

    $self->_start_time(time());
    $self->_total($self->config->total_combinations);

    $self->_print_header();

    my @usernames = $self->config->usernames->@*;
    my @passwords = $self->config->passwords->@*;

    my $handler = $self->config->protocol_handler_name;
    $self->logger->debug("Usando handler: %s", $handler);

    my $count = 0;

    USER:
    for my $user (@usernames) {
        last USER if $self->_should_stop();

        PASS:
        for my $pass (@passwords) {
            last PASS if $self->_should_stop();

            $count++;
            $self->_attempted($count);

            # ── Progresso na mesma linha ──────────────
            $self->_show_progress($count, $user, $pass);

            # ── Delay entre tentativas ────────────────
            usleep($self->config->delay_between * 1000) if $self->config->delay_between;

            # ── Executar teste do protocolo ───────────
            my $success = try {
                $self->$handler($user, $pass);
            } catch {
                $self->logger->debug("Erro no handler para %s:%s: %s",
                    $user, $pass, $_);
                0;
            };

            if ($success) {
                $self->_found(1);
                $self->_record_found($user, $pass);

                $self->logger->info("");
                $self->logger->info("=" x 60);
                $self->logger->info("  ✅ CREDENCIAL VÁLIDA ENCONTRADA!");
                $self->logger->info("     USUÁRIO: %s", $user);
                $self->logger->info("     SENHA:   %s", $pass);
                $self->logger->info("=" x 60);
                $self->logger->info("");

                $self->_save_result($user, $pass);

                last PASS if $self->config->stop_on_first;
                last USER if $self->config->stop_on_first;
            }
        }
    }

    $self->_finish();
}

# ============================================================
# HELPERS
# ============================================================

sub _should_stop {
    my $self = shift;
    return 1 if ${$self->shutdown};
    return 1 if $self->_found && $self->config->stop_on_first;
    return 0;
}

sub _print_header {
    my $self = shift;

    my $total = $self->config->total_combinations;

    $self->logger->info("");
    $self->logger->info("╔══════════════════════════════════════════════════════════╗");
    $self->logger->info("║              FydelisBrute  v2.0                          ║");
    $self->logger->info("║         Credential Testing Framework                     ║");
    $self->logger->info("║              FydelisTechos © 2026                        ║");
    $self->logger->info("╚══════════════════════════════════════════════════════════╝");
    $self->logger->info("");
    $self->logger->info("  Alvo:      %s:%s",      $self->config->host, $self->config->port);
    $self->logger->info("  Protocolo: %s",          uc($self->config->protocol));
    $self->logger->info("  Usuários:  %d",          scalar $self->config->usernames->@*);
    $self->logger->info("  Senhas:    %d",          scalar $self->config->passwords->@*);
    $self->logger->info("  Total:     %d combinações", $total);
    $self->logger->info("  Threads:   %d",          $self->config->threads);
    $self->logger->info("  Timeout:   %ds",         $self->config->timeout);
    $self->logger->info("  Parar no 1º: %s",       $self->config->stop_on_first ? "SIM" : "NÃO");
    $self->logger->info("  Retries:   %d",          $self->config->max_retries);
    $self->logger->info("  Delay:     %dms",        $self->config->delay_between);
    $self->logger->info("  Log:       %s",          $self->config->logfile // "stdout only");
    $self->logger->info("  Output:    %s",          $self->config->output_file // "none");
    $self->logger->info("");
    $self->logger->info("  Iniciando teste...");
    $self->logger->info("");
}

sub _show_progress {
    my ($self, $count, $user, $pass) = @_;

    my $total   = $self->_total;
    my $pct     = $total > 0 ? sprintf("%.1f", ($count / $total) * 100) : "0.0";
    my $elapsed = time() - $self->_start_time;
    my $rate    = $elapsed > 0 ? sprintf("%.1f", $count / $elapsed) : "?";
    my $eta_sec = $rate > 0 && $rate ne "?" ? sprintf("%.0f", ($total - $count) / $rate) : "?";

    my $eta_str;
    if ($eta_sec ne "?") {
        my $eta_m  = int($eta_sec / 60);
        my $eta_s  = int($eta_sec % 60);
        $eta_str   = sprintf("%02d:%02d", $eta_m, $eta_s);
    } else {
        $eta_str = "--:--";
    }

    my $elapsed_str;
    {
        my $em = int($elapsed / 60);
        my $es = int($elapsed % 60);
        $elapsed_str = sprintf("%02d:%02d", $em, $es);
    }

    if ($self->config->verbose) {
        $self->logger->debug("[%d/%d] %2.1f%% | %s:%s | %s/s | ETA %s",
            $count, $total, $pct, $user, $pass, $rate, $eta_str);
    } else {
        $self->logger->progress(
            sprintf("  [%d/%d] %5.1f%% | %s:%s | %s/s | decorrido: %s | ETA: %s",
                $count, $total, $pct, $user, $pass, $rate, $elapsed_str, $eta_str)
        );
    }
}

sub _record_found {
    my ($self, $user, $pass) = @_;
    push $self->_results->@*, {
        usuario   => $user,
        senha     => $pass,
        timestamp => strftime('%Y-%m-%d %H:%M:%S', localtime),
    };
}

sub _save_result {
    my ($self, $user, $pass) = @_;
    return unless $self->config->output_file;

    my $file = $self->config->output_file;

    try {
        open my $fh, '>>', $file or die "Cannot open $file: $!";
        $fh->autoflush(1);

        printf $fh "[%s] VÁLIDO | %s:%s | %s | USUÁRIO: %s | SENHA: %s\n",
            strftime('%Y-%m-%d %H:%M:%S', localtime),
            $self->config->host,
            $self->config->port,
            uc($self->config->protocol),
            $user,
            $pass;

        close $fh;
        $self->logger->info("  Resultado salvo em: %s", $file);
    } catch {
        $self->logger->error("Falha ao salvar resultado: %s", $_);
    };
}

sub _finish {
    my $self = shift;

    $self->logger->done_progress();

    my $elapsed  = time() - $self->_start_time;
    my $elapsed_str;
    {
        my $h = int($elapsed / 3600);
        my $m = int(($elapsed % 3600) / 60);
        my $s = int($elapsed % 60);
        $elapsed_str = sprintf("%02d:%02d:%02d", $h, $m, $s);
    }

    my $total    = $self->_total;
    my $attempts = $self->_attempted;
    my $found    = scalar $self->_results->@*;

    $self->logger->info("");
    $self->logger->info("=" x 60);
    $self->logger->info("  RESUMO FINAL");
    $self->logger->info("-" x 60);
    $self->logger->info("  Total planejado:   %d combinações",         $total);
    $self->logger->info("  Tentativas reais:  %d",                    $attempts);
    $self->logger->info("  Credenciais encontradas: %d",              $found);
    $self->logger->info("  Tempo decorrido:   %s",                    $elapsed_str);
    $self->logger->info("  Taxa média:        %.1f tentativas/s",     $elapsed > 0 ? $attempts / $elapsed : 0);

    if ($found > 0) {
        $self->logger->info("-" x 60);
        $self->logger->info("  CREDENCIAIS ENCONTRADAS:");
        for my $r ($self->_results->@*) {
            $self->logger->info("    [%s] %s : %s",
                $r->{timestamp}, $r->{usuario}, $r->{senha});
        }
    }

    $self->logger->info("=" x 60);
    $self->logger->info("");

    if (${$self->shutdown}) {
        $self->logger->warn("  ⚠️  Processo interrompido pelo usuário (SIGINT/SIGTERM)");
    }

    return $found;
}

1;