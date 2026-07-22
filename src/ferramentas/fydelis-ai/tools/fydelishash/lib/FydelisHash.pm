package FydelisHash;
use v5.20;
use strict;
use warnings;
use Moo;
use Try::Tiny;
use Time::HiRes qw(time);
use POSIX       qw(strftime);

use FydelisHash::Config;
use FydelisHash::Logger;

# ── Atributos ───────────────────────────────────────────
has config   => ( is => 'ro', required => 1 );
has logger   => ( is => 'ro', required => 1 );
has shutdown => ( is => 'ro', isa => \&_is_scalar_ref, default => sub { \my $x = 0 });

sub _is_scalar_ref { ref($_[0]) eq 'SCALAR' }

# ── Consumir Cracker (que já inclui Hasher + Rules) ──
with 'FydelisHash::Cracker';

# ── RUN ───────────────────────────────────────────────
sub run {
    my $self = shift;

    $self->_print_header();
    $self->_validate_environment();

    my $results = $self->crack();

    $self->_print_summary($results);
}

# ── Header ────────────────────────────────────────────
sub _print_header {
    my $self = shift;

    $self->logger->info("");
    $self->logger->info("╔══════════════════════════════════════════════════════════╗");
    $self->logger->info("║             FydelisHash  v2.0                             ║");
    $self->logger->info("║           Hash Cracking Framework                         ║");
    $self->logger->info("║              FydelisTechos © 2026                        ║");
    $self->logger->info("╚══════════════════════════════════════════════════════════╝");
    $self->logger->info("");
}

# ── Validar ambiente ─────────────────────────────────
sub _validate_environment {
    my $self = shift;

    my $hash_type = $self->config->hash_type;
    my $hashes    = $self->config->target_hashes;

    if ($hash_type eq 'auto' && @$hashes == 1) {
        $hash_type = $self->config->detect_hash_type($hashes->[0]);
    }

    if ($hash_type eq 'unknown') {
        $self->logger->warn("  ⚠️  Não foi possível detectar o tipo do hash");
        $self->logger->warn("     Especifique com -t (md5, sha1, sha256, sha512, ntlm, etc.)");
    }

    $self->logger->info("  Hashes:      %d", scalar $hashes->@*);
    $self->logger->info("  Tipo:        %s", $hash_type || "auto-detect");

    if ($hashes->@* > 1) {
        $self->logger->info("  Modo:        batch (%d hashes)", scalar $hashes->@*);
    }

    if ($hash_type eq 'ntlm' && !$HAVE_MD4) {
        $self->logger->warn("  ⚠️  Digest::MD4 não instalado. Instale com: cpanm Digest::MD4");
    }

    if ($hash_type eq 'bcrypt' && !$HAVE_BCRYPT) {
        $self->logger->warn("  ⚠️  Crypt::Eksblowfish::Bcrypt não instalado. Instale com: cpanm Crypt::Eksblowfish::Bcrypt");
    }
}

# ── Sumário ───────────────────────────────────────────
sub _print_summary {
    my ($self, $results) = @_;

    my $stats = $self->_stats;
    my $elapsed = time() - $stats->{start};
    my $rate    = $elapsed > 0 ? sprintf("%.0f", $stats->{tested} / $elapsed) : "?";

    $self->logger->done_progress();
    $self->logger->info("");
    $self->logger->info("=" x 70);
    $self->logger->info("  RESUMO DO CRACKING");
    $self->logger->info("-" x 70);
    $self->logger->info("  Total testados:    %d",  $stats->{tested});
    $self->logger->info("  Quebrados:         %d / %d", $stats->{cracked}, $stats->{hashes});
    $self->logger->info("  Tempo:             %ds",  $elapsed);
    $self->logger->info("  Taxa:              %s hashes/s", $rate);
    $self->logger->info("");

    if ($results->@* > 0) {
        $self->logger->info("  RESULTADOS:");
        for my $r ($results->@*) {
            $self->logger->info("    [%s] %s => %s", $r->{type}, $r->{hash}, $r->{password});
        }
        $self->logger->info("");

        if ($self->config->output_file) {
            $self->logger->info("  Resultados salvos em: %s", $self->config->output_file);
        }
    } else {
        $self->logger->info("  Nenhum hash foi quebrado.");
    }

    $self->logger->info("=" x 70);

    if (${$self->shutdown}) {
        $self->logger->warn("  ⚠️  Processo interrompido pelo usuário");
    }
}

1;