package FydelisHash::Cracker;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use Try::Tiny;
use Time::HiRes qw(time usleep);
use threads;
use threads::shared;

requires qw(config logger shutdown);

# ── Consumir Hasher + Rules ──────────────────────────
with 'FydelisHash::Hasher';
with 'FydelisHash::Rules';

# ── Resultados compartilhados ────────────────────────
has _found_passwords => (
    is      => 'rw',
    default => sub { share([]) },
);

has _stats => (
    is      => 'rw',
    default => sub {
        return {
            tested    => 0,
            cracked   => 0,
            start     => 0,
            hashes    => 0,
        };
    },
);

# ============================================================
# CRACK
# ============================================================
sub crack {
    my $self = shift;

    my $stats = $self->_stats;
    $stats->{start} = time();
    $stats->{hashes} = scalar $self->config->target_hashes->@*;

    my @hashes  = $self->config->target_hashes->@*;
    my @wordlist = $self->config->wordlist->@*;

    # Detectar tipo de hash
    my $hash_type = $self->config->hash_type;
    if ($hash_type eq 'auto' && @hashes == 1) {
        $hash_type = $self->config->detect_hash_type($hashes[0]);
        $self->logger->info("  Tipo detectado: %s", $hash_type);
    }

    # Se bcrypt, precisamos dos settings a partir do hash
    my %hash_settings;
    if ($hash_type eq 'bcrypt') {
        for my $h (@hashes) {
            $hash_settings{$h} = $h;  # bcrypt hash contém os settings
        }
    }

    # ── Preparar regras ────────────────────────────────
    my @rules;
    if (scalar($self->config->rules->@*) > 0 || $self->config->has_rules_file) {
        @rules = $self->_load_rules();
        $self->logger->info("  Regras carregadas: %d", scalar @rules);
    }

    # Também adicionar regras comuns
    my @common_rules;
    if ($self->config->case_permutations || $self->config->append_numbers) {
        @common_rules = $self->generate_common_rules();
    }

    @rules = (@common_rules, @rules);

    my $total_words = scalar(@wordlist) * (scalar(@rules) + 1);
    $self->logger->info("  Wordlist:      %d palavras",   scalar @wordlist);
    $self->logger->info("  Regras:        %d",            scalar @rules);
    $self->logger->info("  Combinações:   %d (aproximado)", $total_words);
    $self->logger->info("  Threads:       %d",            $self->config->threads);
    $self->logger->info("  Tipo:          %s",            $hash_type);
    $self->logger->info("  Hashes:        %d",            scalar @hashes);
    $self->logger->info("");

    # ── Pool de threads ────────────────────────────────
    my @worker_threads;
    my $words_per_thread = int(@wordlist / $self->config->threads) || 1;

    for my $t (0 .. $self->config->threads - 1) {
        last if ${$self->shutdown};

        my $start_idx = $t * $words_per_thread;
        my $end_idx   = ($t == $self->config->threads - 1)
            ? scalar(@wordlist) - 1
            : $start_idx + $words_per_thread - 1;

        last if $start_idx >= scalar(@wordlist);

        push @worker_threads, threads->create(sub {
            $self->_worker(
                $start_idx, $end_idx,
                \@wordlist,
                \@rules,
                \@hashes,
                $hash_type,
                \%hash_settings,
            );
            return;
        });
    }

    # ── Monitor de progresso ─────────────────────────
    my $last_progress = 0;
    while (scalar(threads->list(threads::running)) > 0) {
        last if ${$self->shutdown};

        my $tested = $stats->{tested};
        my $cracked = $stats->{cracked};
        my $elapsed = time() - $stats->{start};
        my $rate    = $elapsed > 0 ? sprintf("%.0f", $tested / $elapsed) : "?";

        my $pct = $total_words > 0
            ? sprintf("%.1f", ($tested / $total_words) * 100)
            : "?";

        if ($tested - $last_progress >= 5000) {
            $last_progress = $tested;
            $self->logger->progress(
                sprintf("  Testados: %d | %s%% | %s hashes/s | %d encontrados | decorrido: %ds",
                    $tested, $pct, $rate, $cracked, $elapsed)
            );
        }

        Time::HiRes::usleep(500_000);
    }

    # ── Aguardar threads ────────────────────────────
    $_->join() for @worker_threads;

    $self->logger->done_progress();
    return $self->_found_passwords;
}

# ── Worker thread ─────────────────────────────────────
sub _worker {
    my ($self, $start, $end, $wordlist_ref, $rules_ref, $hashes_ref, $hash_type, $hash_settings_ref) = @_;

    my $stats = $self->_stats;
    my @wordlist = $wordlist_ref->@[$start..$end];
    my @rules    = $rules_ref->@*;
    my @hashes   = $hashes_ref->@*;

    for my $word (@wordlist) {
        last if ${$self->shutdown};
        last if $self->config->stop_on_first && $stats->{cracked} >= scalar(@hashes);

        # Testar a palavra base
        $self->_test_word($word, \@hashes, $hash_type, $hash_settings_ref, $stats);

        # Aplicar regras
        for my $rule (@rules) {
            last if ${$self->shutdown};
            last if $self->config->stop_on_first && $stats->{cracked} >= scalar(@hashes);

            my @variants = $self->_apply_single_rule($word, $rule);
            for my $variant (@variants) {
                last if ${$self->shutdown};
                last if $self->config->stop_on_first && $stats->{cracked} >= scalar(@hashes);
                next unless defined $variant && length($variant) > 0;
                next if length($variant) < $self->config->min_length;
                next if length($variant) > $self->config->max_length;

                $self->_test_word($variant, \@hashes, $hash_type, $hash_settings_ref, $stats);
            }
        }
    }
}

# ── Testar uma palavra contra todos os hashes ─────────
sub _test_word {
    my ($self, $word, $hashes_ref, $hash_type, $hash_settings_ref, $stats) = @_;

    lock $stats;
    $stats->{tested}++;

    my $computed;

    # bcrypt precisa do settings do hash
    if ($hash_type eq 'bcrypt') {
        # Para bcrypt, testamos cada hash individualmente
        for my $target_hash ($hashes_ref->@*) {
            my $settings = $hash_settings_ref->{$target_hash} // $target_hash;
            try {
                require Crypt::Eksblowfish::Bcrypt;
                my $bc = Crypt::Eksblowfish::Bcrypt->new(
                    cost => 8,
                    salt => $settings,
                );
                my $test_hash = $bc->hash($word);
                if ($test_hash eq $target_hash) {
                    $stats->{cracked}++;
                    push $self->_found_passwords->@*, {
                        hash     => $target_hash,
                        password => $word,
                        type     => $hash_type,
                    };
                    $self->_save_found($target_hash, $word, $hash_type);
                }
            } catch {
                # bcrypt error, skip
            };
        }
        return;
    }

    # Para hashes normais, computar uma vez
    $computed = $self->compute_hash($word, $hash_type);
    return unless defined $computed;

    for my $target_hash ($hashes_ref->@*) {
        next if $self->_is_already_found($target_hash);

        if (lc($computed) eq lc($target_hash)) {
            $stats->{cracked}++;
            push $self->_found_passwords->@*, {
                hash     => $target_hash,
                password => $word,
                type     => $hash_type,
            };

            $self->logger->info("");
            $self->logger->info("  ✅ QUEBRADO! %s => %s", $target_hash, $word);

            $self->_save_found($target_hash, $word, $hash_type);
        }
    }
}

# ── Verificar se hash já foi encontrado ──────────────
sub _is_already_found {
    my ($self, $hash) = @_;

    for my $found ($self->_found_passwords->@*) {
        return 1 if $found->{hash} eq $hash;
    }
    return 0;
}

# ── Salvar resultado ─────────────────────────────────
sub _save_found {
    my ($self, $hash, $password, $type) = @_;
    return unless $self->config->output_file;

    try {
        open my $fh, '>>', $self->config->output_file or die $!;
        $fh->autoflush(1);

        printf $fh "[%s] TIPO: %s | HASH: %s | SENHA: %s\n",
            POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime),
            $type, $hash, $password;

        close $fh;
    } catch {
        $self->logger->error("Falha ao salvar: %s", $_);
    };
}

1;