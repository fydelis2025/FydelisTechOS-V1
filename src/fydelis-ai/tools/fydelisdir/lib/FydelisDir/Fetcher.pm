package FydelisDir::Fetcher;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use Try::Tiny;
use HTTP::Response;
use HTTP::Request;
use LWP::UserAgent;
use HTTP::Cookies;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use Time::HiRes qw(usleep);

requires qw(config logger shutdown);

# ── User-Agents para rotação ──────────────────────────
my @USER_AGENTS = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36',
);

# ── Pool de User-Agents (reutilizado por thread) ──────
has _ua_pool => (
    is      => 'rw',
    default => sub { {} },
);

# ── Obter UserAgent da pool ou criar novo ─────────────
sub _get_ua {
    my ($self) = @_;

    my $tid = threads->tid() // 0;
    my $pool = $self->_ua_pool;

    return $pool->{$tid} if exists $pool->{$tid};

    # Criar novo UA
    my $ua = LWP::UserAgent->new(
        timeout   => $self->config->request_timeout,
        max_redirect => $self->config->follow_redirects ? $self->config->max_redirects : 0,
        protocols_allowed => ['http', 'https'],
        ssl_opts  => {
            verify_hostname => 0,
            SSL_verify_mode => SSL_VERIFY_NONE,
        },
    );

    $ua->agent($self->config->user_agent);
    $ua->default_header('Accept' => '*/*');
    $ua->default_header('Accept-Language' => 'en-US,en;q=0.9,pt-BR;q=0.8,pt;q=0.7');
    $ua->default_header('Connection' => 'keep-alive');

    # Cookie jar
    $ua->cookie_jar(HTTP::Cookies->new());

    # Autenticação
    if ($self->config->has_auth) {
        $ua->credentials(
            $self->config->host . ':' . $self->config->port,
            '',  # realm (qualquer)
            $self->config->username,
            $self->config->password,
        );
    }

    $pool->{$tid} = $ua;
    return $ua;
}

# ── Fazer requisição ─────────────────────────────────
sub fetch {
    my ($self, $path) = @_;

    return undef if ${$self->shutdown};

    my $ua = $self->_get_ua();

    # Rotacionar User-Agent se configurado
    if ($self->config->rotate_agents) {
        my $idx = int(rand(scalar @USER_AGENTS));
        $ua->agent($USER_AGENTS[$idx]);
    }

    my $url = $self->config->base_url . $path;
    my $request = HTTP::Request->new(GET => $url);

    # Headers anti-detecção
    $request->header('Referer' => $self->config->base_url);
    $request->header('DNT' => '1');
    $request->header('X-Forwarded-For' => $self->_random_ip());

    my $start = time();
    my $response;

    try {
        $response = $ua->request($request);
    } catch {
        $self->logger->debug("Erro na requisição para %s: %s", $path, $_);
        return undef;
    };

    # Delay entre requisições
    if ($self->config->delay_ms > 0) {
        usleep($self->config->delay_ms * 1000);
    }

    return $response;
}

# ── IP aleatório para X-Forwarded-For ─────────────────
sub _random_ip {
    my $self = shift;
    return join('.', map { int(rand(254)) + 1 } (1..4));
}

sub _reset_ua {
    my ($self) = @_;
    my $tid = threads->tid() // 0;
    delete $self->_ua_pool->{$tid};
}

1;