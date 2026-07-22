package FydelisWordlist::Generator;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use POSIX qw(strftime);
use Time::HiRes qw(time);

requires qw(config logger shutdown);

# ── Consumir Rules ────────────────────────────────────
with 'FydelisWordlist::Rules';

# ── Gerar lista principal ─────────────────────────────
sub generate {
    my $self = shift;

    $self->logger->info("Iniciando geração de wordlist...");

    my %seen;
    my $count   = 0;
    my $max     = $self->config->max_combinations;
    my $start   = time();

    # ── Coletar palavras base ─────────────────────────
    my @base_words;
    push @base_words, $self->config->first_name if $self->config->first_name;
    push @base_words, $self->config->last_name  if $self->config->last_name;
    push @base_words, $self->config->year       if $self->config->year;
    push @base_words, $self->config->location   if $self->config->location;
    push @base_words, $self->config->keyword    if $self->config->keyword;
    push @base_words, $self->config->extra_words->@*;

    # Remover duplicatas e normalizar
    my @clean;
    for my $w (@base_words) {
        next unless defined $w && length($w) > 0;
        $w =~ s/^\s+|\s+$//g;
        next unless length($w) > 0;
        push @clean, $w;
    }
    @base_words = @clean;

    $self->logger->info("  Palavras base: %s", join(', ', @base_words));

    # ── Abrir arquivo de saída ────────────────────────
    my $file = $self->config->output_file;
    open my $fh, '>', $file or die "Cannot open $file: $!";
    $fh->autoflush(1);

    # ── Gerar combinações ─────────────────────────────
    my $last_progress = 0;

    for my $word (@base_words) {
        last if ${$self->shutdown};
        last if $max > 0 && $count >= $max;

        # Variações de case
        my @case_variants = $self->apply_case_variations($word);

        for my $variant (@case_variants) {
            last if ${$self->shutdown};
            last if $max > 0 && $count >= $max;

            # Variações leet
            my @leet_variants = $self->apply_leet_variations($variant);

            for my $leet_form (@leet_variants) {
                last if ${$self->shutdown};
                last if $max > 0 && $count >= $max;

                # Variações reversas
                my @rev_forms = ($leet_form);
                if ($self->config->include_reversed) {
                    push @rev_forms, scalar reverse($leet_form);
                }

                for my $base_form (@rev_forms) {
                    last if ${$self->shutdown};
                    last if $max > 0 && $count >= $max;

                    # Variações duplicadas
                    my @dup_forms = ($base_form);
                    if ($self->config->include_doubled) {
                        push @dup_forms, $base_form x 2;
                    }

                    for my $final_form (@dup_forms) {
                        last if ${$self->shutdown};
                        last if $max > 0 && $count >= $max;

                        # Variações truncadas
                        my @trunc_forms = ($final_form);
                        if ($self->config->include_truncated) {
                            push @trunc_forms, $self->apply_truncated($final_form);
                        }

                        for my $word_form (@trunc_forms) {
                            last if ${$self->shutdown};
                            last if $max > 0 && $count >= $max;
                            next unless defined $word_form && length($word_form) > 0;
                            next unless $self->sanitize_length($word_form);

                            # Adicionar números?
                            my @num_sets = ('');

                            if ($self->config->include_numbers) {
                                my @nums;
                                push @nums, $self->common_numbers();
                                push @nums, $self->year_numbers();
                                # Adicionar 1..9999 limitado
                                for my $n (1..999) { push @nums, $n; last if $max > 0 && $count + scalar(@nums) > $max; }
                                @num_sets = ('', @nums);
                            }

                            for my $num (@num_sets) {
                                last if ${$self->shutdown};
                                last if $max > 0 && $count >= $max;

                                # Adicionar símbolos?
                                my @sym_sets = ('');
                                if ($self->config->include_symbols) {
                                    @sym_sets = ('', $self->common_symbols());
                                }

                                for my $sym (@sym_sets) {
                                    last if ${$self->shutdown};
                                    last if $max > 0 && $count >= $max;

                                    my $candidate = $word_form . $num . $sym;
                                    next unless $self->sanitize_length($candidate);
                                    next if $seen{$candidate}++;

                                    # Padrões comuns
                                    my @final_candidates = ($candidate);
                                    if ($self->config->include_common_patterns) {
                                        push @final_candidates, $self->_apply_common_patterns($candidate);
                                    }

                                    for my $final (@final_candidates) {
                                        last if ${$self->shutdown};
                                        last if $max > 0 && $count >= $max;
                                        next if $seen{$final}++;
                                        next unless $self->sanitize_length($final);

                                        print $fh "$final\n";
                                        $count++;

                                        # Progresso a cada 10k
                                        if ($count - $last_progress >= 10_000) {
                                            $last_progress = $count;
                                            $self->_progress($count, $max, $start);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    close $fh;

    my $elapsed = time() - $start;
    $self->logger->done_progress();

    $self->logger->info("");
    $self->logger->info("═" x 60);
    $self->logger->info("  GERAÇÃO CONCLUÍDA");
    $self->logger->info("  Palavras geradas: %d",  $count);
    $self->logger->info("  Arquivo:          %s",  $file);
    $self->logger->info("  Tempo:            %.1f segundos", $elapsed);
    $self->logger->info("  Taxa:             %.0f palavras/s", $elapsed > 0 ? $count / $elapsed : $count);

    if (${$self->shutdown}) {
        $self->logger->warn("  ⚠️  Interrompido pelo usuário — resultado parcial salvo");
    }

    $self->logger->info("═" x 60);
    $self->logger->info("");

    return $count;
}

# ── Padrões comuns ─────────────────────────────────────
sub _apply_common_patterns {
    my ($self, $word) = @_;

    my @patterns;
    # Adicionar "!" no final
    push @patterns, $word . '!';
    push @patterns, $word . '@';
    push @patterns, $word . '#';

    # Adicionar "123" no final
    push @patterns, $word . '123';
    push @patterns, $word . '123!';

    # Ano atual
    my $cy = (localtime)[5] + 1900;
    push @patterns, $word . $cy;
    push @patterns, $word . substr($cy, -2);

    return @patterns;
}

# ── Progresso ─────────────────────────────────────────
sub _progress {
    my ($self, $count, $max, $start) = @_;

    my $elapsed = time() - $start;
    my $rate    = $elapsed > 0 ? sprintf("%.0f", $count / $elapsed) : "?";
    my $pct     = $max > 0 ? sprintf("%.1f", ($count / $max) * 100) : "?";

    my $eta = "";
    if ($max > 0 && $rate ne "?" && $rate > 0) {
        my $remaining = $max - $count;
        my $eta_sec   = $remaining / $rate;
        $eta = sprintf("ETA %02d:%02d", int($eta_sec / 60), int($eta_sec % 60));
    }

    $self->logger->progress(
        sprintf("  Gerando: %d palavras | %s%% | %s/s | %s",
            $count, $pct, $rate, $eta)
    );
}

1;