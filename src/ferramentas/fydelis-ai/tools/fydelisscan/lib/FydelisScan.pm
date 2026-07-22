package FydelisScan;
use v5.20;
use strict;
use warnings;
use Moo;
use Try::Tiny;
use Time::HiRes qw(time usleep);
use POSIX       qw(strftime);

use FydelisScan::Config;
use FydelisScan::Logger;

# ── Atributos ───────────────────────────────────────────
has config   => ( is => 'ro', required => 1 );
has logger   => ( is => 'ro', required => 1 );
has shutdown => ( is => 'ro', isa => \&_is_scalar_ref, default => sub { \my $x = 0 });

has _start_time  => ( is => 'rw', default => 0 );
has _open_ports  => ( is => 'rw', default => sub { [] } );
has _results     => ( is => 'rw', default => sub { [] } );

sub _is_scalar_ref { ref($_[0]) eq 'SCALAR' }

# ── Consumir Roles ─────────────────────────────────────
with 'FydelisScan::Scanner';
with 'FydelisScan::BruteFork';

# ============================================================
# RUN
# ============================================================
sub run {
    my $self = shift;
    $self->_start_time(time());

    $self->_print_header();

    # ── FASE 1: Scan de portas ─────────────────────────
    my $open_ports = $self->scan_ports($self->config->ports);
    $self->_open_ports($open_ports);

    return $self->_finish() unless $open_ports->@*;

    # ── FASE 2: Teste de credenciais ───────────────────
    my $has_creds = $self->config->usernames->@* && $self->config->passwords->@*;

    if ($has_creds) {
        $self->_brute_all_ports($open_ports);
    } else {
        $self->logger->info("Nenhuma credencial fornecida — apenas scan realizado.");
    }

    $self->_finish();
}

# ============================================================
# FASE 2: Brute Force
# ============================================================
sub _brute_all_ports {
    my ($self, $open_ports) = @_;

    $self->logger->info("");
    $self->logger->info("═" x 60);
    $self->logger->info("  FASE 2: Teste de Credenciais");
    $self->logger->info("  %d porta(s) aberta(s) | %d usuário(s) | %d senha(s) | %d combinações",
        scalar $open_ports->@*,
        scalar $self->config->usernames->@*,
        scalar $self->config->passwords->@*,
        $self->config->total_combinations,
    );
    $self->logger->info("═" x 60);

    my $total_attempts = scalar $open_ports->@* * $self->config->total_combinations;
    my $attempt_count  = 0;
    my $found_count    = 0;

    PORT:
    for my $port_info ($open_ports->@*) {
        last PORT if ${$self->shutdown};

        $self->logger->info("");
        $self->logger->info("── Testando porta %d (%s) ──",
            $port_info->{port}, $port_info->{service});

        USER:
        for my $user ($self->config->usernames->@*) {
            last USER if ${$self->shutdown};

            PASS:
            for my $pass ($self->config->passwords->@*) {
                last PASS if ${$self->shutdown};
                $attempt_count++;

                $self->logger->progress(
                    sprintf("  [%d/%d] Tentando %s:%s na porta %d...",
                        $attempt_count, $total_attempts, $user, $pass, $port_info->{port})
                );

                my $success = try {
                    $self->try_credentials($port_info, $user, $pass);
                } catch {
                    $self->logger->debug("Erro: %s", $_);
                    0;
                };

                if ($success) {
                    $found_count++;
                    $self->logger->done_progress();
                    $self->logger->info("");

                    $self->logger->info("  ✅ CREDENCIAL VÁLIDA!");
                    $self->logger->info("     PORTA:    %d (%s)", $port_info->{port}, $port_info->{service});
                    $self->logger->info("     USUÁRIO:  %s", $user);
                    $self->logger->info("     SENHA:    %s", $pass);

                    $self->_save_result($port_info, $user, $pass);
                }
            }
        }
    }

    $self->logger->done_progress();
    $self->logger->info("");
    $self->logger->info("Fase 2 concluída: %d credencial(is) encontrada(s)", $found_count);
}

# ============================================================
# HELPERS
# ============================================================

sub _print_header {
    my $self = shift;

    $self->logger->info("");
    $self->logger->info("╔══════════════════════════════════════════════════════════╗");
    $self->logger->info("║              FydelisScan  v2.0                           ║");
    $self->logger->info("║      Service Scanner + Credential Testing Framework      ║");
    $self->logger->info("║              FydelisTechos © 2026                        ║");
    $self->logger->info("╚══════════════════════════════════════════════════════════╝");
    $self->logger->info("");
    $self->logger->info("  Alvo:      %s",        $self->config->host);
    $self->logger->info("  Portas:    %d",        scalar $self->config->ports->@*);
    $self->logger->info("  Usuários:  %d",        scalar $self->config->usernames->@*);
    $self->logger->info("  Senhas:    %d",        scalar $self->config->passwords->@*);
    $self->logger->info("  Threads:   %d (pool)", $self->config->threads);
    $self->logger->info("  Scan tout: %ds",       $self->config->scan_timeout);
    $self->logger->info("  Brute tout:%ds",       $self->config->brute_timeout);
    $self->logger->info("  Log:       %s",        $self->config->logfile // "stdout only");
    $self->logger->info("  Output:    %s",        $self->config->output_file // "none");
    $self->logger->info("");
}

sub _save_result {
    my ($self, $port_info, $user, $pass) = @_;
    return unless $self->config->output_file;

    my $file = $self->config->output_file;

    try {
        open my $fh, '>>', $file or die "Cannot open $file: $!";
        $fh->autoflush(1);

        printf $fh "[%s] VÁLIDO | %s:%d | %s | %s : %s\n",
            strftime('%Y-%m-%d %H:%M:%S', localtime),
            $self->config->host,
            $port_info->{port},
            $port_info->{service},
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

    my $elapsed  = time() - $self->_start_time;
    my $elapsed_str;
    {
        my $h = int($elapsed / 3600);
        my $m = int(($elapsed % 3600) / 60);
        my $s = int($elapsed % 60);
        $elapsed_str = sprintf("%02d:%02d:%02d", $h, $m, $s);
    }

    $self->logger->info("");
    $self->logger->info("=" x 60);
    $self->logger->info("  RESUMO FINAL");
    $self->logger->info("-" x 60);
    $self->logger->info("  Host:          %s",         $self->config->host);
    $self->logger->info("  Portas scaneadas: %d",      scalar $self->config->ports->@*);
    $self->logger->info("  Portas abertas:   %d",      scalar $self->_open_ports->@*);
    $self->logger->info("  Credenciais encontradas: %d", scalar $self->_results->@*);
    $self->logger->info("  Tempo:         %s",         $elapsed_str);

    if ($self->_open_ports->@*) {
        $self->logger->info("-" x 60);
        $self->logger->info("  PORTAS ABERTAS:");
        for my $p ($self->_open_ports->@*) {
            $self->logger->info("    %-5d %s", $p->{port}, $p->{service});
        }
    }

    if ($self->_results->@*) {
        $self->logger->info("-" x 60);
        $self->logger->info("  CREDENCIAIS:");
        for my $r ($self->_results->@*) {
            $self->logger->info("    %s:%s em porta %d (%s)",
                $r->{usuario}, $r->{senha}, $r->{port}, $r->{service});
        }
    }

    $self->logger->info("=" x 60);
    $self->logger->info("");

    if (${$self->shutdown}) {
        $self->logger->warn("  ⚠️  Processo interrompido pelo usuário");
    }

    return scalar $self->_results->@*;
}

1;