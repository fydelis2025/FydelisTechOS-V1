package FydelisWordlist;
use v5.20;
use strict;
use warnings;
use Moo;
use Try::Tiny;

use FydelisWordlist::Config;
use FydelisWordlist::Logger;

# ── Atributos ───────────────────────────────────────────
has config   => ( is => 'ro', required => 1 );
has logger   => ( is => 'ro', required => 1 );
has shutdown => ( is => 'ro', isa => \&_is_scalar_ref, default => sub { \my $x = 0 });

sub _is_scalar_ref { ref($_[0]) eq 'SCALAR' }

# ── Consumir Roles ─────────────────────────────────────
with 'FydelisWordlist::Generator';

# ── RUN ───────────────────────────────────────────────
sub run {
    my $self = shift;

    $self->_print_header();

    unless ($self->config->has_base_data) {
        $self->logger->error("Nenhum dado base fornecido. Use --help.");
        return;
    }

    $self->logger->info("Aplicando regras:");
    $self->logger->info("  Números:      %s", $self->config->include_numbers   ? "SIM" : "NÃO");
    $self->logger->info("  Símbolos:     %s", $self->config->include_symbols   ? "SIM" : "NÃO");
    $self->logger->info("  Leet:         %s", $self->config->include_leet      ? "SIM" : "NÃO");
    $self->logger->info("  Caps:         %s", $self->config->include_caps      ? "SIM" : "NÃO");
    $self->logger->info("  Padrões:      %s", $self->config->include_common_patterns ? "SIM" : "NÃO");
    $self->logger->info("  Reverso:      %s", $self->config->include_reversed  ? "SIM" : "NÃO");
    $self->logger->info("  Duplicado:    %s", $self->config->include_doubled   ? "SIM" : "NÃO");
    $self->logger->info("  Truncado:     %s", $self->config->include_truncated ? "SIM" : "NÃO");
    $self->logger->info("  Max:          %s", $self->config->max_combinations  ? $self->config->max_combinations : "ilimitado");
    $self->logger->info("  Saída:        %s", $self->config->output_file);
    $self->logger->info("");

    my $count = $self->generate();

    $self->logger->info("✅ Wordlist gerada com sucesso: %d palavras em %s",
        $count, $self->config->output_file);
}

sub _print_header {
    my $self = shift;

    $self->logger->info("");
    $self->logger->info("╔══════════════════════════════════════════════════════════╗");
    $self->logger->info("║           FydelisWordlist  v2.0                          ║");
    $self->logger->info("║           Custom Wordlist Generator                      ║");
    $self->logger->info("║              FydelisTechos © 2026                        ║");
    $self->logger->info("╚══════════════════════════════════════════════════════════╝");
    $self->logger->info("");
}

1;