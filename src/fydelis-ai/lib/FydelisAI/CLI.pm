package FydelisAI::CLI;
use v5.20;
use strict;
use warnings;
use Moo;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Pod::Usage;
use File::Spec;

use FydelisAI::Config;

sub parse_args {
    my ($self, $argv) = @_;

    my %opts;
    GetOptionsFromArray($argv, \%opts,
        't|target=s'            => \$opts{target},
        'a|action=s'            => \$opts{action},
        'q|query|question=s'    => \$opts{query},
        'c|command=s'           => \$opts{command},
        'f|file=s'              => \$opts{file},
        'tool-type=s'           => \$opts{tool_type},

        'm|model=s'             => \$opts{model},
        'template=s'            => \$opts{template},
        'timeout=i'             => \$opts{timeout},
        'no-stream'             => \$opts{no_stream},
        'temperature=f'         => \$opts{temperature},

        'config=s'              => \$opts{config},
        'o|output=s'            => \$opts{output},
        'l|log=s'               => \$opts{log},
        'v|verbose'             => \$opts{verbose},
        'yes|auto-confirm'      => \$opts{auto_confirm},
		
		'protocol|p=s'   		=> \$opts{protocol},

        'help|?'                => \$opts{help},
        'version'               => \$opts{version},
    ) or pod2usage(2);

    # ── Help / Version ─────────────────────────────────
    if ($opts{help}) {
        $self->show_help();
        pod2usage(-verbose => 2, -exitval => 0);
    }

    if ($opts{version}) {
        print "FydelisAI v2.0.0 | FydelisTechos © 2026\n";
        exit 0;
    }

    # ── Carregar configuração ─────────────────────────
    my $config_file = $opts{config} || $self->_find_config();
    my $config = FydelisAI::Config->from_file($config_file);

    # Sobrescrever com CLI
    $config->{target}        = $opts{target}     if $opts{target};
    $config->{action}        = $opts{action}     if $opts{action};
    $config->{query}         = $opts{query}      if $opts{query};
    $config->{command}       = $opts{command}    if $opts{command};
    $config->{file}          = $opts{file}       if $opts{file};
    $config->{tool_type}     = $opts{tool_type}  if $opts{tool_type};
    $config->{verbose}       = $opts{verbose}    if defined $opts{verbose};
    $config->{ollama_model}  = $opts{model}      if $opts{model};
    $config->{template}      = $opts{template}   if $opts{template};
    $config->{ollama_timeout}= $opts{timeout}    if $opts{timeout};
    $config->{ollama_stream} = $opts{no_stream} ? 0 : 1;
    $config->{ollama_temperature} = $opts{temperature} if $opts{temperature};
    $config->{confirm_before_exec} = $opts{auto_confirm} ? 0 : 1;

    if ($opts{output}) {
        $config->{output_file} = $opts{output};
    }
    if ($opts{log}) {
        $config->{logfile} = $opts{log};
    }

    return $config;
}

sub show_help {
    my $self = shift;

    print <<'HELP';
╔══════════════════════════════════════════════════════════╗
║             FydelisAI  v2.0                               ║
║      AI-Powered Security Assessment Assistant             ║
║              FydelisTechos © 2026                        ║
╚══════════════════════════════════════════════════════════╝

USO: fydelis-ai [OPÇÕES]

OPÇÕES:

  Alvo:
    -t, --target HOST       IP ou hostname alvo
    -a, --action AÇÃO       Ação a executar (veja abaixo)

  Consulta:
    -q, --query TEXTO       Pergunta direta ao assistente
    --template NOME         Template de prompt (nmap_sugestao, analise_vulnerabilidade,
                            payload_geracao, explicacao_tecnica, comando_livre)

  Execução:
    -c, --command CMD       Comando a executar (com --action exec)
    -f, --file ARQUIVO      Arquivo de output para analisar (com --action analyze)
    --tool-type TIPO        Tipo de ferramenta (nmap, hydra, nikto, etc.)

  Conexão:
    -m, --model MODELO      Modelo Ollama (padrão: gemma:latest)
    --timeout SEGUNDOS      Timeout (padrão: 60s)
    --no-stream             Desabilitar streaming
    --temperature VALOR     Temperatura do modelo (0-2, padrão: 0.7)

  Config:
    --config ARQUIVO        Arquivo YAML de configuração
    -o, --output ARQUIVO    Salvar resultados
    -l, --log ARQUIVO       Arquivo de log
    -v, --verbose           Modo verboso
    --yes                   Auto-confirmar execução de comandos

  Informação:
    --help                  Mostra esta ajuda
    --version               Versão

AÇÕES DISPONÍVEIS:
  (sem ação)    Modo consulta livre
  interactive   Modo interativo (shell)
  suggest       Sugerir comando com base no alvo/contexto
  exec          Executar comando e analisar resultado
  analyze       Analisar output de ferramenta
  ping          Verificar se Ollama está rodando
  models        Listar modelos disponíveis
  clear-session Limpar histórico da sessão atual
  cache-stats   Mostrar estatísticas do cache
  clean-cache   Limpar cache expirado

EXEMPLOS:

  # Pergunta direta
  fydelis-ai -q "Como detectar SQL injection em formulários de login?"

  # Com alvo e análise
  fydelis-ai -t 192.168.1.100 -q "Quais portas devo verificar primeiro?"

  # Sugerir comando
  fydelis-ai -t scanme.org -a suggest -q "scaneie o alvo para portas HTTP"

  # Executar comando e analisar resultado
  fydelis-ai -a exec -c "nmap -sV -p 80,443 scanme.org"

  # Analisar output de ferramenta salvo em arquivo
  fydelis-ai -a analyze -f resultados/nmap.txt --tool-type nmap

  # Modo interativo
  fydelis-ai -t 10.0.0.1 -a interactive

  # Usar modelo diferente
  fydelis-ai -m llama3:8b -q "Explique blind SQL injection"
  
  # Como usar o FydelisBrute
  fydelis-ai -t 192.168.1.10 -a fydelisbrute -p ssh

HELP
}

sub _find_config {
    my $self = shift;

    # Procurar em locais comuns
    my @candidates = (
        File::Spec->catfile('.', 'fydelis-ai.yaml'),
        File::Spec->catfile('.', 'fydelis-ai.yml'),
        File::Spec->catfile('.', 'config', 'fydelis-ai.yaml'),
        File::Spec->catfile($ENV{HOME} // '.', '.fydelis-ai', 'config.yaml'),
        '/etc/fydelis-ai/config.yaml',
    );

    for my $file (@candidates) {
        return $file if -f $file;
    }

    return undef;
}

1;

__END__

=head1 NAME

fydelis-ai - AI-Powered Security Assessment Assistant

=head1 SYNOPSIS

  fydelis-ai [options]

=head1 DESCRIPTION

FydelisAI integrates with Ollama running local LLMs to provide
an intelligent assistant for authorized security assessments.
It supports context-aware conversations, command suggestion,
output analysis, and safe command execution.

=head1 REQUIREMENTS

=over 4

=item * Ollama running locally (http://localhost:11434)

=item * At least one model pulled (gemma:latest, llama3, etc.)

=back

=head1 EXAMPLES

  # Start interactive session
  fydelis-ai -a interactive

  # Ask about a specific target
  fydelis-ai -t 10.0.0.1 -q "What vulnerabilities might this host have?"

  # Analyze nmap output
  fydelis-ai -a analyze -f nmap-output.txt --tool-type nmap

=cut