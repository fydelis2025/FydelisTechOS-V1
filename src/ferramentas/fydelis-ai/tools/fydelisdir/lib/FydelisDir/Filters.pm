package FydelisDir::Filters;
use v5.20;
use strict;
use warnings;
use Moo::Role;

requires qw(config);

# ── Verificar se o resultado é válido ─────────────────
sub is_valid_result {
    my ($self, $path, $response) = @_;

    return 0 unless defined $response;
    return 0 unless $response->code;

    # ── 1. Status code válido? ────────────────────────
    my $code = $response->code;
    my $valid = $self->config->valid_status_codes;
    return 0 unless grep { $_ == $code } $valid->@*;

    # ── 2. Tamanho mínimo da resposta? ────────────────
    if ($self->config->min_response_size > 0) {
        my $body = $response->decoded_content // $response->content // '';
        return 0 if length($body) < $self->config->min_response_size;
    }

    # ── 3. Texto de exclusão no body? ─────────────────
    if ($self->config->exclude_text) {
        my $body = lc($response->decoded_content // $response->content // '');
        my $excl = lc($self->config->exclude_text);
        return 0 if index($body, $excl) != -1;
    }

    # ── 4. Detecção de página "not found" customizada ─
    # Sites que retornam 200 com "not found" no body
    my $body_lc = lc($response->decoded_content // $response->content // '');
    my @not_found_indicators = (
        'not found', 'page not found', '404 not found',
        'no such page', 'doesn\'t exist', 'does not exist',
        'file not found', 'cannot be found', 'nothing here',
        'página não encontrada', 'página não existe',
    );

    for my $indicator (@not_found_indicators) {
        return 0 if index($body_lc, $indicator) != -1;
    }

    # ── 5. Content-Type válido (evitar redirects para binários) ─
    my $ct = $response->header('Content-Type') // '';
    # Remover páginas que são claramente de erro do servidor
    if ($ct =~ /text\/html/ && $code == 200) {
        # Verificar se o título indica erro
        if ($body_lc =~ /<title>\s*(404|403|error|not found)/) {
            return 0;
        }
    }

    return 1;
}

# ── Identificar se é diretório (para recursão) ───────
sub is_directory {
    my ($self, $path, $response) = @_;

    return 0 unless $response;
    my $code = $response->code;

    # 301, 302, 307 com Location terminando em /
    if ($code == 301 || $code == 302 || $code == 307) {
        my $loc = $response->header('Location') // '';
        return 1 if $loc =~ m{/$};
    }

    # 200 com links para subdiretórios (indicativo)
    if ($code == 200) {
        my $body = $response->decoded_content // $response->content // '';
        # Index of listing
        return 1 if $body =~ /<title>\s*index of\s+/i;
        return 1 if $body =~ /<a\s+href="[^"]*\/"/i;
    }

    return 0;
}

1;