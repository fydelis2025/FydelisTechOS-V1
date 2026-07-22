package FydelisDir;
use v5.20;
use strict;
use warnings;
use Moo;
use Try::Tiny;
use Time::HiRes qw(time);
use POSIX       qw(strftime);

use FydelisDir::Config;
use FydelisDir::Logger;

# ── Atributos ───────────────────────────────────────────
has config   => ( is => 'ro', required => 1 );
has logger   => ( is => 'ro', required => 1 );
has shutdown => ( is => 'ro', isa => \&_is_scalar_ref, default => sub { \my $x = 0 });

sub _is_scalar_ref { ref($_[0]) eq 'SCALAR' }

# ── Consumir o Scanner (que já inclui Fetcher + Filters) ─
with 'FydelisDir::Scanner';

# ── RUN ───────────────────────────────────────────────
sub run {
    my $self = shift;

    $self->_print_header();

    my $results = $self->scan();

    $self->_print_summary($results);
}

# ── Header ────────────────────────────────────────────
sub _print_header {
    my $self = shift;

    $self->logger->info("");
    $self->logger->info("╔══════════════════════════════════════════════════════════╗");
    $self->logger->info("║             FydelisDir  v2.0                              ║");
    $self->logger->info("║        HTTP/HTTPS Path Enumeration Framework              ║");
    $self->logger->info("║              FydelisTechos © 2026                        ║");
    $self->logger->info("╚══════════════════════════════════════════════════════════╝");
    $self->logger->info("");
    $self->logger->info("  Alvo:      %s", $self->config->base_url);
    $self->logger->info("  Porta:     %d", $self->config->port);
    $self->logger->info("  SSL:       %s", $self->config->ssl ? "SIM" : "NÃO");
    $self->logger->info("  Threads:   %d", $self->config->threads);
    $self->logger->info("  Timeout:   %ds", $self->config->request_timeout);
    $self->logger->info("  Recursão:  %d níveis", $self->config->recursion_depth);
    $self->logger->info("  Wordlist:  %d itens",  scalar $self->config->wordlist->@*);
    $self->logger->info("  Extensões: %s", join(', ', grep { $_ ne '' } $self->config->extensions->@*) || '(nenhuma)');
    $self->logger->info("  Status:    %s", join(', ', $self->config->valid_status_codes->@*));
    $self->logger->info("  Auth:      %s", $self->config->has_auth ? sprintf("%s:%s", $self->config->username, '****') : "nenhuma");
    $self->logger->info("  Delay:     %dms", $self->config->delay_ms);
    $self->logger->info("  Output:    %s", $self->config->output_file // "stdout only");
    $self->logger->info("");

    # Aviso de delay
    if ($self->config->delay_ms == 0 && $self->config->threads > 5) {
        $self->logger->warn("  ⚠️  Sem delay configurado — muitos requests podem sobrecarregar o alvo");
    }
}

# ── Sumário ───────────────────────────────────────────
sub _print_summary {
    my ($self, $results) = @_;

    my $stats = $self->_stats;

    $self->logger->done_progress();
    $self->logger->info("");
    $self->logger->info("=" x 70);
    $self->logger->info("  RESUMO DA ENUMERAÇÃO");
    $self->logger->info("-" x 70);
    $self->logger->info("  Total de requisições: %d",     $stats->{total});
    $self->logger->info("  Encontrados:         %d",     $stats->{found});
    $self->logger->info("  Filtrados:           %d",     $stats->{filtered});
    $self->logger->info("  Erros:               %d",     $stats->{errors});
    $self->logger->info("  Tempo decorrido:     %.1f segundos", time() - $stats->{start});
    $self->logger->info("");

    if (scalar($results->@*) > 0) {
        $self->logger->info("  RESULTADOS ENCONTRADOS:");
        $self->logger->info("");

        # Agrupar por status code
        my %by_code;
        for my $r ($results->@*) {
            push $by_code{$r->{code}}->@*, $r;
        }

        for my $code (sort { $a <=> $b } keys %by_code) {
            $self->logger->info("  ── Status %d (%d itens) ──", $code, scalar $by_code{$code}->@*);
            for my $r ($by_code{$code}->@*) {
                my $size = $r->{size};
                my $size_str = $size >= 1024
                    ? sprintf("%.1fKB", $size / 1024)
                    : sprintf("%dB", $size);
                my $note = $r->{location} ? " → $r->{location}" : '';
                $self->logger->info("    %s %s %s",
                    $size_str, $r->{path}, $note);
            }
            $self->logger->info("");
        }

        # Salvar lista final se configurado
        if ($self->config->output_file) {
            $self->logger->info("  Resultados salvos em: %s", $self->config->output_file);
        }
    } else {
        $self->logger->info("  Nenhum caminho válido encontrado.");
    }

    $self->logger->info("=" x 70);

    if (${$self->shutdown}) {
        $self->logger->warn("  ⚠️  Processo interrompido pelo usuário — resultados parciais");
    }
}

1;