package FydelisAI::LLM;
use v5.20;
use strict;
use warnings;
use Moo;
use JSON;
use IO::Handle;
use Time::HiRes qw(time);

has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );

sub ask {
    my ($self, $prompt, $context_callback) = @_;

    my $url     = $self->config->ollama_url . '/api/generate';
    my $model   = $self->config->ollama_model;
    my $timeout = $self->config->ollama_timeout;
    my $stream  = $self->config->ollama_stream;
    my $temp    = $self->config->ollama_temperature;
    my $maxtok  = $self->config->ollama_max_tokens;

    my $payload = {
        model       => $model,
        prompt      => $prompt,
        stream => JSON::false,
        
    };

    $self->logger->debug("Enviando para Ollama [%s]: %s...", $model, substr($prompt, 0, 100));

    my $json_payload = encode_json($payload);
    my $response_text = '';

    if ($stream) {
        require IO::Socket::INET;
        my ($host, $port) = $self->_parse_url($url);

        my $sock = IO::Socket::INET->new(
            PeerHost  => $host,
            PeerPort  => $port,
            Proto     => 'tcp',
            Timeout   => $timeout,
        );

        unless ($sock) {
            $self->logger->error("Não foi possível conectar a %s:%s: %s", $host, $port, $!);
            return "⚠️  Erro de conexão com Ollama em $host:$port. Verifique se o serviço está rodando.\n";
        }

        $sock->autoflush(1);

        my $http_req = "POST /api/generate HTTP/1.1\r\n"
                     . "Host: $host:$port\r\n"
                     . "Content-Type: application/json\r\n"
                     . "Content-Length: " . length($json_payload) . "\r\n"
                     . "Connection: close\r\n"
                     . "\r\n"
                     . $json_payload;

        print $sock $http_req;

        my $in_body = 0;

        while (my $line = <$sock>) {
            last unless defined $line;

            if (!$in_body) {
                if ($line =~ /^\r?$/) {
                    $in_body = 1;
                }
                next;
            }

            eval {
                my $chunk = decode_json($line);
                my $text  = $chunk->{response} // '';
                $response_text .= $text;

                if ($context_callback) {
                    $context_callback->($text);
                } else {
                    print $text;
                }

                last if $chunk->{done};
            };
        }

        close $sock;

    } else {
        require HTTP::Tiny;

        my $http = HTTP::Tiny->new(
            timeout => 120,
        );

        my $response = $http->post(
            $url,  # Usando a variável correta $url
            { 
                headers => { 'Content-Type' => 'application/json' },
                content => $json_payload  # Passando a string JSON codificada
            }
        );

        unless ($response->{success}) {
            $self->logger->error("Ollama retornou erro: %s", $response->{status});
            return "⚠️  Erro HTTP $response->{status} ao contactar Ollama.\n";
        }

        my $data = decode_json($response->{content});
        $response_text = $data->{response} // '';
    }

    return $response_text;
}

sub list_models {
    my $self = shift;

    my $url = $self->config->ollama_url . '/api/tags';

    require HTTP::Tiny;
    my $http = HTTP::Tiny->new(timeout => 5);
    my $res  = $http->get($url);

    return [] unless $res->{success};

    my $data = decode_json($res->{content});
    my @models;

    for my $m ($data->{models}->@*) {
        push @models, {
            name    => $m->{name},
            size    => $m->{size},
            details => $m->{details} // {},
        };
    }

    return \@models;
}

sub ping {
    my $self = shift;

    my $url = $self->config->ollama_url;

    require HTTP::Tiny;
    my $http = HTTP::Tiny->new(timeout => 3);
    my $res  = $http->get($url);

    return $res->{success} ? 1 : 0;
}

sub _parse_url {
    my ($self, $url) = @_;

    $url =~ s{^https?://}{};
    my ($host, $port) = split(/:/, $url, 2);
    $port ||= 11434;
    $host =~ s{/.*$}{};

    return ($host, $port);
}

1;