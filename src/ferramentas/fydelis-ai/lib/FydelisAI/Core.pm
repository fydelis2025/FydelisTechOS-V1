package FydelisAI::Core;
use strict;
use warnings;
use HTTP::Tiny;
use JSON;

sub new {
    my ($class, %args) = @_;
    my $self = {
        api_url => $args{api_url} || 'http://localhost:11434/api/generate',
        model   => $args{model}   || 'gemma:latest',
    };
    bless $self, $class;
    return $self;
}

sub consultar_ia {
    my ($self, $prompt_usuario) = @_;
    
    my $payload = encode_json({
        model  => $self->{model},
        prompt => $prompt_usuario,
        stream => 0
    });

    my $response = HTTP::Tiny->new->post(
        $self->{api_url},
        { 
            headers => { 'Content-Type' => 'application/json' },
            content => $payload 
        }
    );

    if ($response->{success}) {
        my $data = decode_json($response->{content});
        return $data->{response};
    } else {
        return "[!] Erro de comunicação com o backend de IA: $response->{status}";
    }
}

1;