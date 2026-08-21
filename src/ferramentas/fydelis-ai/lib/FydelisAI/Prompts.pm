package FydelisAI::Prompts;
use v5.20;
use strict;
use warnings;
use Moo;
use File::Spec;

has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );

my %DEFAULT_TEMPLATES = (

    nmap_sugestao => <<'TEMPLATE',
Você é um especialista em segurança ofensiva integrado ao FydelisTechOS.

COMANDOS DISPONÍVEIS:
  nmap, curl, gobuster, dirb, hydra, john, hashcat, sqlmap, nikto, wpscan

ALVO: {{alvo}}
CONTEXTO: {{contexto}}

Com base no alvo e contexto acima, sugira APENAS UM comando de scan/recon
que seja o mais adequado para a situação.

REGRAS:
1. Retorne SOMENTE o comando completo em uma linha
2. Use flags eficientes (não genéricas como -A)
3. Inclua timeouts razoáveis
4. Priorize discrição (evite scans muito agressivos)
5. Após o comando, explique brevemente o que ele faz (máx 2 linhas)

Exemplo de saída:
  nmap -sV -sC --top-ports 100 --min-rate 500 -T4 {{alvo}}
  # Scan de versões + scripts padrão nas 100 portas mais comuns, com taxa moderada.
TEMPLATE

    analise_vulnerabilidade => <<'TEMPLATE',
Você é um analista de segurança ofensiva experiente.

ALVO: {{alvo}}
CONTEXTO:
{{contexto}}

Analise os resultados acima e identifique:
1. Serviços/versões potencialmente vulneráveis
2. Configurações incorretas ou inseguras
3. Possíveis vetores de ataque (priorizando RCE, auth bypass, LFI)
4. Recomendações de próximos passos

Seja direto, técnico e específico. Mencione CVEs quando aplicável.
TEMPLATE

    payload_geracao => <<'TEMPLATE',
Atue como engenheiro de segurança ofensiva.

ALVO: {{alvo}}
CONTEXTO: {{contexto}}

Com base no contexto, gere um payload ou script de teste para VALIDAÇÃO DE SEGURANÇA.
O payload deve ser:
- Educativo e não-destrutivo
- Específico para a vulnerabilidade identificada
- Em Python, Bash ou Perl (uma linha se possível)

Após o payload, explique o que ele testa e como interpretar o resultado.
TEMPLATE

    explicacao_tecnica => <<'TEMPLATE',
Você é um tutor de segurança ofensiva.

ALUNO PERGUNTA: {{contexto}}

Explique o conceito de forma técnica e completa, incluindo:
1. O que é
2. Como funciona (mecanismo)
3. Exemplo prático
4. Como se proteger/mitigar

Use linguagem técnica mas didática. Inclua exemplos de código quando relevante.
TEMPLATE

    comando_livre => <<'TEMPLATE',
Você é um assistente de segurança ofensiva integrado ao terminal FydelisTechOS.

ALVO: {{alvo}}
PERGUNTA: {{contexto}}

Responda de forma técnica e direta. Se for um comando, sugira o comando completo.
Se for dúvida conceitual, explique com exemplos práticos.
TEMPLATE

);

sub render {
    my ($self, $template_name, $target, $context) = @_;

    my $template = $DEFAULT_TEMPLATES{$template_name};

    unless ($template) {
        $template = $self->_load_template_file($template_name);
    }

    unless ($template) {
        $template = $DEFAULT_TEMPLATES{comando_livre};
    }

    $target  //= '';
    $context //= '';

    $template =~ s/\{\{alvo\}\}/$target/g;
    $template =~ s/\{\{contexto\}\}/$context/g;

    return $template;
}

sub _load_template_file {
    my ($self, $name) = @_;

    my $file = File::Spec->catfile('templates', "$name.txt");
    return undef unless -f $file;

    open my $fh, '<', $file or return undef;
    local $/;
    my $content = <$fh>;
    close $fh;

    return $content;
}

sub list_templates {
    my $self = shift;
    return [sort keys %DEFAULT_TEMPLATES];
}

1;