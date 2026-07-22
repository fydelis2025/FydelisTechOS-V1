package FydelisAI;
use v5.20;
use strict;
use warnings;
use Moo;

use FydelisAI::Config;
use FydelisAI::Logger;
use FydelisAI::LLM;
use FydelisAI::Session;
use FydelisAI::Prompts;
use FydelisAI::Parser;
use FydelisAI::Tools;
use FydelisAI::Cache;

# ── Atributos ───────────────────────────────────────────
has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );
has target => ( is => 'ro', default => '' );

has llm     => ( is => 'lazy' );
has session => ( is => 'lazy' );
has prompts => ( is => 'lazy' );
has parser  => ( is => 'lazy' );
has tools   => ( is => 'lazy' );
has cache   => ( is => 'lazy' );

sub _build_llm {
    my $self = shift;
    return FydelisAI::LLM->new(
        config => $self->config,
        logger => $self->logger,
    );
}

sub _build_session {
    my $self = shift;
    return FydelisAI::Session->new(
        config => $self->config,
        logger => $self->logger,
        target => $self->target,
    );
}

sub _build_prompts {
    my $self = shift;
    return FydelisAI::Prompts->new(
        config => $self->config,
        logger => $self->logger,
    );
}

sub _build_parser {
    my $self = shift;
    return FydelisAI::Parser->new(
        config => $self->config,
        logger => $self->logger,
    );
}

sub _build_tools {
    my $self = shift;
    return FydelisAI::Tools->new(
        config => $self->config,
        logger => $self->logger,
    );
}

sub _build_cache {
    my $self = shift;
    return FydelisAI::Cache->new(
        config => $self->config,
        logger => $self->logger,
    );
}

# ============================================================
# INTERFACE PRINCIPAL
# ============================================================

# ── Perguntar ao assistente de IA ──────────────────────
sub ask {
    my ($self, $question, $template) = @_;

    $template //= 'comando_livre';

    # Verificar cache primeiro
    my $cache_key = join('|', $template, $question);
    my $cached = $self->cache->get($cache_key);
    if ($cached) {
        $self->logger->info("  (resposta do cache)");
        return $cached;
    }

    # Renderizar template
    my $prompt = $self->prompts->render($template, $self->target, $question);
    $self->logger->debug("Prompt enviado:\n%s", $prompt);

    # Adicionar contexto da sessão
    my $context = $self->session->get_context(5);
    if ($context) {
        $prompt = "Histórico da conversa:\n$context\n---\nNova pergunta:\n$prompt";
    }

    # Consultar LLM
    $self->logger->info("Consultando IA (modelo: %s)...", $self->config->ollama_model);

    my $response = '';
    my $callback;
    if ($self->config->ollama_stream) {
        $callback = sub {
            my $chunk = shift;
            print $chunk;
            $response .= $chunk;
        };
        print "\n";
    }

    $response = $self->llm->ask($prompt, $callback);

    unless ($self->config->ollama_stream) {
        $self->logger->output("\n%s", $response);
    } else {
        print "\n";
    }

    # Salvar na sessão
    $self->session->add_message('user', $question);
    $self->session->add_message('assistant', $response);

    # Salvar no cache
    $self->cache->set($cache_key, $response);

    return $response;
}

# ── Analisar output de ferramenta ──────────────────────
sub analyze_output {
    my ($self, $output_file, $tool_type) = @_;

    $self->logger->info("Analisando output: %s", $output_file);

    my $parsed;
    if ($tool_type) {
        my $method = "parse_$tool_type";
        if ($self->parser->can($method)) {
            $parsed = $self->parser->$method($output_file);
        } else {
            $parsed = $self->parser->parse_auto($output_file);
        }
    } else {
        $parsed = $self->parser->parse_auto($output_file);
    }

    # Formatar para prompt
    my $context = $self->_format_parsed($parsed);

    # Perguntar à IA
    return $self->ask(
        "Analise estes resultados de scan:\n\n$context",
        'analise_vulnerabilidade'
    );
}

# ── Executar comando e analisar resultado ──────────────
sub run_and_analyze {
    my ($self, $cmd, $timeout) = @_;

    $self->logger->info("Executando comando e analisando resultado...");

    my $result = $self->tools->execute($cmd, $timeout);

    unless ($result->{success}) {
        return "❌ Comando falhou: " . ($result->{error} // "exit code $result->{exitcode}");
    }

    # Analisar output
    return $self->analyze_output($result->{stdout});
}

# ── Sugerir comando com base no contexto ───────────────
sub suggest_command {
    my ($self, $context) = @_;

    $self->logger->info("Solicitando sugestão de comando...");

    my $response = $self->ask($context, 'nmap_sugestao');

    # Tentar extrair comando da resposta
    if ($response =~ /(nmap|curl|gobuster|dirb|hydra|nikto|sqlmap|wpscan)\s+.*/) {
        my $cmd = $1;
        $cmd .= $' if defined $';

        # Limpar
        $cmd =~ s/^\s+|\s+$//g;
        $cmd =~ s/[\r\n]+/ /g;

        $self->logger->info("Comando sugerido: %s", $cmd);

        return {
            command  => $cmd,
            analysis => $response,
        };
    }

    return {
        command  => undef,
        analysis => $response,
    };
}

# ── Listar modelos disponíveis ─────────────────────────
sub list_models {
    my $self = shift;
    return $self->llm->list_models();
}

# ── Verificar status do Ollama ─────────────────────────
sub ping {
    my $self = shift;
    return $self->llm->ping();
}

# ── Estatísticas do cache ──────────────────────────────
sub cache_stats {
    my $self = shift;
    return $self->cache->stats();
}

# ── Limpar cache ───────────────────────────────────────
sub clean_cache {
    my $self = shift;
    $self->cache->clean();
}

# ── Limpar sessão atual ────────────────────────────────
sub clear_session {
    my $self = shift;
    $self->session->clear();
    $self->logger->info("Sessão limpa para o alvo: %s", $self->target);
}

# ============================================================
# HELPERS INTERNOS
# ============================================================

sub _format_parsed {
    my ($self, $parsed) = @_;

    my $type = $parsed->{type} // 'unknown';
    my $data = $parsed->{data};

    return "Tipo: $type\nDados: " . ($data // 'sem dados') unless ref $data;

    my $output = "Tipo: $type\n\n";

    if ($type eq 'nmap') {
        $output .= "Host: $data->{host}\n";
        $output .= "Portas abertas:\n";
        for my $p ($data->{ports}->@*) {
            $output .= "  $p->{port}/$p->{protocol}  $p->{state}  $p->{service}";
            $output .= "  $p->{version}" if $p->{version};
            $output .= "\n";
        }
        $output .= "OS: $data->{os}\n" if $data->{os};

    } elsif ($type eq 'web_dirs') {
        $output .= "Diretórios/arquivos encontrados:\n";
        for my $r ($data->@*) {
            $output .= "  [$r->{status}] $r->{path}";
            $output .= " ($r->{size} bytes)" if $r->{size};
            $output .= "\n";
        }

    } elsif ($type eq 'hydra') {
        $output .= "Credenciais encontradas:\n";
        for my $c ($data->@*) {
            $output .= "  [$c->{service}:$c->{port}] $c->{host} | $c->{username} : $c->{password}\n";
        }

    } elsif ($type eq 'nikto') {
        $output .= "Vulnerabilidades encontradas:\n";
        for my $v ($data->@*) {
            $output .= "  [$v->{severity}] $v->{path}: $v->{description}";
            $output .= " ($v->{cve})" if $v->{cve};
            $output .= "\n";
        }

    } elsif ($type eq 'http') {
        $output .= "Status: $data->{status}\n";
        $output .= "Headers:\n";
        for my $k (keys $data->{headers}->%*) {
            $output .= "  $k: $data->{headers}->{$k}\n";
        }
        $output .= "Tamanho do body: $data->{body_size} bytes\n";

    } elsif ($type eq 'wpscan') {
        $output .= "WordPress: $data->{url}\n";
        $output .= "Versão: $data->{wordpress_version}\n" if $data->{wordpress_version};
        $output .= "Tema: $data->{wordpress_theme}\n" if $data->{wordpress_theme};
        if ($data->{plugins}->@*) {
            $output .= "Plugins:\n";
            for my $p ($data->{plugins}->@*) {
                $output .= "  - $p->{name}\n";
            }
        }
        if ($data->{users}->@*) {
            $output .= "Usuários:\n";
            for my $u ($data->{users}->@*) {
                $output .= "  - $u->{username}\n";
            }
        }
        if ($data->{vulnerabilities}->@*) {
            $output .= "Vulnerabilidades:\n";
            for my $v ($data->{vulnerabilities}->@*) {
                $output .= "  [$v->{severity}] $v->{description}";
                $output .= " ($v->{cve})" if $v->{cve};
                $output .= "\n";
            }
        }

    } elsif ($type eq 'openvas') {
        $output .= "OpenVAS Report:\n";
        $output .= "  Total de resultados: $data->{total_results}\n";
        if (keys $data->{summary}->%*) {
            $output .= "  Sumário:\n";
            for my $sev (sort keys $data->{summary}->%*) {
                $output .= "    $sev: $data->{summary}->{$sev}\n";
            }
        }
        if ($data->{results}->@*) {
            $output .= "  Resultados:\n";
            my $count = 0;
            for my $r ($data->{results}->@*) {
                $count++;
                last if $count > 20;  # limitar para não estourar o prompt
                $output .= "    [$r->{severity}] $r->{name} ($r->{port})\n";
                $output .= "      $r->{description}\n" if $r->{description};
            }
        }

    } elsif ($type eq 'metasploit') {
        $output .= "Metasploit Session:\n";
        if ($data->{sessions}->@*) {
            $output .= "  Sessions:\n";
            for my $s ($data->{sessions}->@*) {
                $output .= "    ID $s->{id}: $s->{type} ($s->{info})\n";
            }
        }
        if ($data->{credentials}->@*) {
            $output .= "  Credenciais:\n";
            for my $c ($data->{credentials}->@*) {
                $output .= "    $c->{username}:$c->{password}\n" if $c->{password};
                $output .= "    $c->{username}:$c->{hash}\n" if $c->{hash};
            }
        }
        if ($data->{vulns}->@*) {
            $output .= "  CVEs:\n";
            for my $v ($data->{vulns}->@*) {
                $output .= "    $v->{cve}\n" if $v->{cve};
            }
        }

    } else {
        $output .= "Dados brutos:\n$data\n";
    }

    return $output;
}

1;