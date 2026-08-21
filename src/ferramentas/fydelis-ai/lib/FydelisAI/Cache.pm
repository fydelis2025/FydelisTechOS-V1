package FydelisAI::Cache;
use v5.20;
use strict;
use warnings;
use Moo;
use JSON;
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use File::Spec;

has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );

has _cache_dir => (
    is      => 'lazy',
);

sub _build__cache_dir {
    my $self = shift;
    my $dir  = File::Spec->catdir($self->config->session_dir, 'cache');
    make_path($dir) unless -d $dir;
    return $dir;
}

sub _cache_key {
    my ($self, $prompt, $model) = @_;

    my $key = sha256_hex(join('|', $model // $self->config->ollama_model, $prompt));
    return $key;
}

sub get {
    my ($self, $prompt) = @_;

    return undef unless $self->config->cache_enabled;

    my $key  = $self->_cache_key($prompt);
    my $file = File::Spec->catfile($self->_cache_dir, "$key.json");

    return undef unless -f $file;

    # Verificar TTL
    my $age = time() - (stat($file))[9];
    if ($age > $self->config->cache_ttl) {
        unlink $file;
        return undef;
    }

    eval {
        open my $fh, '<', $file or return undef;
        local $/;
        my $json = <$fh>;
        close $fh;

        my $data = decode_json($json);
        $self->logger->debug("Cache HIT para prompt (age: %ds)", $age);
        return $data->{response};
    };
    return undef;
}

sub set {
    my ($self, $prompt, $response) = @_;

    return unless $self->config->cache_enabled;
    return unless defined $prompt && defined $response;

    my $key  = $self->_cache_key($prompt);
    my $file = File::Spec->catfile($self->_cache_dir, "$key.json");

    eval {
        open my $fh, '>', $file or return;
        print $fh encode_json({
            prompt    => $prompt,
            response  => $response,
            cached_at => scalar localtime,
            model     => $self->config->ollama_model,
        });
        close $fh;
        $self->logger->debug("Cache MISS — resposta salva");
    };
    if ($@) {
        $self->logger->warn("Falha ao salvar cache: %s", $@);
    }
}

sub clean {
    my $self = shift;

    my $dir = $self->_cache_dir;
    return unless -d $dir;

    opendir my $dh, $dir or return;
    my $count = 0;

    while (my $file = readdir $dh) {
        next unless $file =~ /\.json$/;
        my $path = File::Spec->catfile($dir, $file);
        my $age = time() - (stat($path))[9];
        if ($age > $self->config->cache_ttl) {
            unlink $path;
            $count++;
        }
    }

    closedir $dh;
    $self->logger->info("Cache limpo: %d arquivos removidos", $count);
}

sub stats {
    my $self = shift;

    my $dir = $self->_cache_dir;
    return { files => 0, size => 0 } unless -d $dir;

    my $files = 0;
    my $size  = 0;

    opendir my $dh, $dir or return { files => 0, size => 0 };
    while (my $file = readdir $dh) {
        next unless $file =~ /\.json$/;
        my $path = File::Spec->catfile($dir, $file);
        $files++;
        $size += (stat($path))[7];
    }
    closedir $dh;

    return {
        files => $files,
        size  => $size,
        size_str => $size > 1_000_000
            ? sprintf("%.1f MB", $size / 1_000_000)
            : sprintf("%.1f KB", $size / 1_000),
    };
}

1;