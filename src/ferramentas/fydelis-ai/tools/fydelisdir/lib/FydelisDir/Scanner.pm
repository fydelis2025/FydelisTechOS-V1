package FydelisDir::Scanner;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use Try::Tiny;
use Time::HiRes qw(time);

requires qw(config logger shutdown);

# ── Consumir roles ────────────────────────────────────
with 'FydelisDir::Fetcher';
with 'FydelisDir::Filters';

# ── Resultados compartilhados ─────────────────────────
has _found_results => (
    is      => 'rw',
    default => sub { [] },
);

has _stats => (
    is      => 'rw',
    default => sub {
        return {
            total    => 0,
            found    => 0,
            filtered => 0,
            errors   => 0,
            start    => 0,
        };
    },
);

# ── Executar scan ─────────────────────────────────────
sub scan {
    my $self = shift;

    my $stats = $self->_stats;
    $stats->{start} = time();

    $self->logger->info("Iniciando enumeração em %s", $self->config->base_url);
    $self->logger->info("  Wordlist:    %d itens", scalar $self->config->wordlist->@*);
    $self->logger->info("  Extensões:   %s", join(', ', grep { $_ ne '' } $self->config->extensions->@*) || '(nenhuma)');
    $self->logger->info("  Status:      %s", join(', ', $self->config->valid_status_codes->@*));
    $self->logger->info("  Recursão:    %d níveis", $self->config->recursion_depth);
    $self->logger->info("  Threads:     %d", $self->config->threads);
    $self->logger->info("");

    # Scan inicial
    $self->_scan_level('/', 0);

    # Recursão em diretórios encontrados
    if ($self->config->recursion_depth > 0) {
        $self->_scan_recursive('/', 1);
    }

    $stats->{elapsed} = time() - $stats->{start};
    return $self->_found_results;
}

# ── Scan de um nível ──────────────────────────────────
sub _scan_level {
    my ($self, $base_path, $depth) = @_;

    my $stats   = $self->_stats;
    my $wordlist = $self->config->wordlist;
    my $exts     = $self->config->extensions;

    my $total_items = scalar($wordlist->@*) * scalar($exts->@*);
    my $processed   = 0;

    # ── Pool de threads simples ───────────────────────
    my @threads;
    my $max_threads = $self->config->threads;

    for my $word ($wordlist->@*) {
        last if ${$self->shutdown};

        for my $ext ($exts->@*) {
            last if ${$self->shutdown};
            $processed++;

            my $path = join('', $base_path, $word);
            $path .= ".$ext" if $ext ne '';
            $path =~ s{//+}{/}g;

            # Criar thread se houver slot
            while (scalar(threads->list(threads::joinable)) > 0) {
                $_->join() for threads->list(threads::joinable);
            }

            while (scalar(threads->list()) >= $max_threads + 1) {  # +1 para main thread
                threads->yield();
                Time::HiRes::usleep(10_000);
            }

            push @threads, threads->create(sub {
                my ($self_ref, $path) = @_;
                $self_ref->_test_path($path, $base_path, $depth);
                return;
            }, $self, $path);

            # Progresso
            if ($processed % 50 == 0 && !$self->config->quiet) {
                $self->logger->progress(
                    sprintf("  [%d/%d] %d encontrados | %d erros | testando %s",
                        $processed, $total_items,
                        $stats->{found}, $stats->{errors},
                        $path)
                );
            }
        }
    }

    # Aguardar threads restantes
    for my $thr (@threads) {
        $thr->join() if $thr->is_joinable();
    }

    # Forçar join de todas
    $_->join() for threads->list();
}

# ── Testar caminho individual ─────────────────────────
sub _test_path {
    my ($self, $path, $base_path, $depth) = @_;

    my $stats = $self->_stats;
    lock $stats;

    $stats->{total}++;

    my $response = $self->fetch($path);

    unless ($response) {
        $stats->{errors}++;
        return;
    }

    if ($self->is_valid_result($path, $response)) {
        $stats->{found}++;

        my $code    = $response->code;
        my $size    = length($response->decoded_content // $response->content // '');
        my $ct      = $response->header('Content-Type') // 'unknown';

        my $result = {
            path        => $path,
            code        => $code,
            size        => $size,
            content_type => $ct,
            depth       => $depth,
            is_dir      => $self->is_directory($path, $response),
            location    => $response->header('Location') // '',
        };

        push $self->_found_results->@*, $result;

        # Log do resultado
        if (!$self->config->quiet) {
            my $icon = $result->{is_dir} ? '📁' : '📄';
            my $extra = $result->{location} ? " → $result->{location}" : '';
            $self->logger->info("  %s %-6d %-8s %s%s",
                $icon, $code, $self->_human_size($size), $path, $extra);
        }

        # Salvar imediatamente
        $self->_save_result($result);
    } else {
        $stats->{filtered}++;

        if ($self->config->verbose) {
            my $code = $response->code // '???';
            $self->logger->debug("    [%s] %s (filtrado)", $code, $path);
        }
    }

    # Delay
    if ($self->config->delay_ms > 0) {
        usleep($self->config->delay_ms * 1000);
    }
}

# ── Recursão em diretórios encontrados ────────────────
sub _scan_recursive {
    my ($self, $base_path, $current_depth) = @_;

    return if $current_depth > $self->config->recursion_depth;

    my @dirs = grep { $_->{is_dir} } $self->_found_results->@*;

    for my $dir (@dirs) {
        last if ${$self->shutdown};

        my $dir_path = $dir->{path};
        $dir_path .= '/' unless $dir_path =~ m{/$};

        $self->logger->info("");
        $self->logger->info("🔁 Recursão nível %d em %s", $current_depth, $dir_path);

        # Salvar o path atual como base para recursão
        local $self->config->{base_path} = $dir_path;
        $self->_scan_level($dir_path, $current_depth);

        # Sub-recursão
        $self->_scan_recursive($dir_path, $current_depth + 1);
    }
}

# ── Salvar resultado ──────────────────────────────────
sub _save_result {
    my ($self, $result) = @_;

    return unless $self->config->output_file;

    try {
        open my $fh, '>>', $self->config->output_file or die $!;
        $fh->autoflush(1);

        printf $fh "[%s] %d | %d bytes | %s | %s%s\n",
            POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime),
            $result->{code},
            $result->{size},
            $result->{content_type},
            $result->{path},
            $result->{location} ? " -> $result->{location}" : '';

        close $fh;
    } catch {
        $self->logger->error("Falha ao salvar resultado: %s", $_);
    };
}

# ── Human readable size ──────────────────────────────
sub _human_size {
    my ($self, $bytes) = @_;
    return '0B' if $bytes == 0;

    my @units = qw(B KB MB GB);
    my $unit = 0;
    my $size = $bytes;

    while ($size >= 1024 && $unit < 3) {
        $size /= 1024;
        $unit++;
    }

    return sprintf('%.1f%s', $size, $units[$unit]);
}

1;