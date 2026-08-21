package FydelisAI::FydelisBrute;
use v5.20;
use strict;
use warnings;
use Moo;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );

sub run_attack {
    my ($self, %args) = @_;

    my $protocol = $args{protocol} // 'ssh';
    my $target   = $args{target};
    my $userlist = $args{userlist} // 'users.txt';
    my $passlist = $args{passlist} // 'pass.txt';

    unless ($target) {
        return { success => 0, error => "Alvo não especificado para o ataque." };
    }

    $self->logger->info("Iniciando motor FydelisBrute (via tools/) em [%s] contra: %s", uc($protocol), $target);

    my @found_credentials;

    # ── CARREGAMENTO DINÂMICO DA PASTA TOOLS ──────────────────────────
    eval {
        # Adiciona a pasta do fydelisbrute ao @INC do Perl temporariamente
        my $root_dir = dirname(dirname(dirname(abs_path(__FILE__))));
        my $brute_dir = "$root_dir/tools/fydelisbrute";
        
        unshift @INC, $brute_dir;

        # Se o seu fydelisbrute principal exportar uma função ou classe, chame aqui.
        # Exemplo se ele tiver um arquivo principal (ex: engine.pl ou similar):
        # require "engine.pl";
        # @found_credentials = rodar_forca_bruta(target => $target, protocol => $protocol);
        
        # Simulação de captura caso o script execute e popule resultados:
        push @found_credentials, { user => 'admin', pass => 'admin123', status => 'SUCCESS' };
    };

    if ($@) {
        $self->logger->error("Erro ao carregar o motor de tools/fydelisbrute: %s", $@);
        return { success => 0, error => $@ };
    }
    # ──────────────────────────────────────────────────────────────────

    $self->logger->info("✅ Varredura da ferramenta concluída.");

    return {
        success     => 1,
        target      => $target,
        protocol    => $protocol,
        credentials => \@found_credentials,
    };
}

1;