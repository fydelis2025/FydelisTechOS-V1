#!/usr/bin/env perl
#
# fydelis-ai.pl - Script de inicialização alternativo para Windows
# ================================================================
# Uso: perl fydelis-ai.pl [opções]
# ================================================================

use v5.20;
use strict;
use utf8;
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);


# Forçar o caminho correto do lib/
BEGIN {
    my $script_dir = dirname(abs_path($0));
    my $lib_dir    = "$script_dir/lib";
    if (-d $lib_dir) {
        unshift @INC, $lib_dir;
    } else {
        die "❌ Diretório lib/ não encontrado em: $lib_dir\n"
          . "   Certifique-se de que o script está na raiz do projeto FydelisAI.\n";
    }
}

use FydelisAI;
use FydelisAI::Config;
use FydelisAI::Logger;
use FydelisAI::CLI;
use FydelisAI::FydelisBrute;

# ── Graceful shutdown ──────────────────────────────────
our $SHUTDOWN = 0;
$SIG{INT}  = sub { $SHUTDOWN = 1; print "\n⚠️  Encerrando...\n"; };
$SIG{TERM} = sub { $SHUTDOWN = 1; };

# Função auxiliar segura declarada antes de ser utilizada
sub get_conf {
    my ($conf, $key) = @_;
    return eval { $conf->can($key) ? $conf->$key : $conf->{$key} };
}

sub main {
    my $cli  = FydelisAI::CLI->new();
    my $conf = $cli->parse_args(\@ARGV) or return 1;

    my $is_verbose = get_conf($conf, 'verbose');
    my $log_file   = get_conf($conf, 'logfile');

    my $logger = FydelisAI::Logger->new(
        level   => $is_verbose ? 1 : 2, # Ajuste numérico se exigido pelo Logger.pm
        defined($log_file) && $log_file ne '' ? (logfile => $log_file) : (),
    );

    my $target = get_conf($conf, 'target') // '';

	eval {
        $conf->{ollama_stream} = 0;
        $conf->can('ollama_stream') and $conf->{ollama_stream} = 0;
    };
	
    my $fydelis = FydelisAI->new(
        config => $conf,
        logger => $logger,
        target => $target,
    );

    my $action = get_conf($conf, 'action');

    # ── Ações ──────────────────────────────────────────

    if ($action && $action eq 'ping') {
        my $ollama_url = get_conf($conf, 'ollama_url');
        if ($fydelis->ping()) {
            $logger->info("✅ Ollama está rodando em %s", $ollama_url);
        } else {
            $logger->error("❌ Ollama não está respondendo em %s", $ollama_url);
        }
        return 0;
    }

    if ($action && $action eq 'models') {
        my $models = $fydelis->list_models();
        $logger->info("Modelos disponíveis:");
        for my $m ($models->@*) {
            $logger->info("  %s (%s)", $m->{name},
                $m->{size} > 1_000_000_000
                    ? sprintf("%.1f GB", $m->{size} / 1_000_000_000)
                    : sprintf("%.1f MB", $m->{size} / 1_000_000)
            );
        }
        return 0;
    }

    if ($action && $action eq 'clear-session') {
        $fydelis->clear_session();
        return 0;
    }

    if ($action && $action eq 'cache-stats') {
        my $stats = $fydelis->cache_stats();
        $logger->info("Cache: %d arquivos, %s", $stats->{files}, $stats->{size_str});
        return 0;
    }

    if ($action && $action eq 'clean-cache') {
        $fydelis->clean_cache();
        return 0;
    }

    # ── Modo interativo ───────────────────────────────
    if ($action && $action eq 'interactive') {
        $logger->info("Modo interativo. Digite 'exit' ou 'quit' para sair.");
        $logger->info("Comandos especiais: /clear, /models, /ping, /cache\n");

        while (1) {
            last if $SHUTDOWN;
            print "\n\033[1;32mfydelis-ai>\033[0m ";
            my $input = <STDIN>;
            last unless defined $input;
            chomp $input;
            last if $input =~ /^(exit|quit|q)$/i;

            if ($input =~ /^\/clear/) {
                $fydelis->clear_session();
                print "✅ Sessão limpa.\n";
                next;
            }

            if ($input =~ /^\/models/) {
                my $models = $fydelis->list_models();
                print "Modelos disponíveis:\n";
                for my $m ($models->@*) {
                    print "  $m->{name}\n";
                }
                next;
            }

            if ($input =~ /^\/ping/) {
                my $ok = $fydelis->ping();
                print $ok ? "✅ Ollama OK\n" : "❌ Ollama offline\n";
                next;
            }

            if ($input =~ /^\/cache/) {
                my $stats = $fydelis->cache_stats();
                print "Cache: $stats->{files} arquivos, $stats->{size_str}\n";
                next;
            }

            next if $input =~ /^\s*$/;

            my $template = get_conf($conf, 'template');
            my $response = $fydelis->ask($input, $template);
        }

        return 0;
    }

    # ── Executar comando e analisar ──────────────────
    if ($action && $action eq 'exec') {
        my $command = get_conf($conf, 'command');
        unless ($command) {
            $logger->error("Comando não fornecido. Use --command ou -c.");
            return 1;
        }

        my $timeout = get_conf($conf, 'timeout');
        my $result = $fydelis->run_and_analyze($command, $timeout);
        $logger->output("\n%s", $result);
        return 0;
    }

    # ── Sugerir comando ──────────────────────────────
    if ($action && $action eq 'suggest') {
        my $query = get_conf($conf, 'query');
        my $context = $query || "scaneie o alvo $target";
        my $suggestion = $fydelis->suggest_command($context);

        if ($suggestion->{command}) {
            $logger->info("Comando sugerido:\n  \033[1;33m%s\033[0m", $suggestion->{command});
        }

        $logger->output("\n%s", $suggestion->{analysis});
        return 0;
    }

    # ── Analisar output de arquivo ───────────────────
    if ($action && $action eq 'analyze') {
        my $file = get_conf($conf, 'file');
        unless ($file) {
            $logger->error("Arquivo não fornecido. Use --file ou -f.");
            return 1;
        }

        my $tool_type = get_conf($conf, 'tool_type');
        my $analysis = $fydelis->analyze_output($file, $tool_type);
        $logger->output("\n%s", $analysis);
        return 0;
    }
	
	if($action && $action eq 'fydelisbrute'){
		my $brute_engine = FydelisAI::FydelisBrute->new(
			config => $conf,
			logger => $logger,
		);

		my $protocol = get_conf($conf, 'protocol') // 'ssh';
		my $userlist = get_conf($conf, 'userlist') // 'users.txt';
		my $passlist = get_conf($conf, 'passlist') // 'pass.txt';

		unless ($target) {
			$logger->error("Alvo não especificado. Use -t <alvo>.");
			return 1;
		}

		my $result = $brute_engine->run_attack(
			protocol => $protocol,
			target   => $target,
			userlist => $userlist,
			passlist => $passlist,
		);

		if ($result->{success}) {
			$logger->info("✅ Ataque finalizado com sucesso no alvo: %s", $result->{target});
			
			require Data::Dumper;
			my $prompt_ia = "Analise os seguintes resultados de testes de credenciais obtidos pelo FydelisBrute no alvo $target e aponte riscos: " . Data::Dumper::Dumper($result);
			
			my $analise = $fydelis->ask($prompt_ia);
			$logger->output("\n--- Relatório da IA ---\n%s", $analise);

		} else {
			$logger->error("[-] Erro: %s", $result->{error} // 'Desconhecido');
		}
		return 0;
	}

    # ── Pergunta livre ─────────────────────────────
    my $query = get_conf($conf, 'query');
    if ($query) {
        my $template = get_conf($conf, 'template');
        my $response = $fydelis->ask($query, $template);
        my $stream = get_conf($conf, 'ollama_stream');
        unless ($stream) {
            $logger->output("\n%s", $response);
        }
        return 0;
    }

    $cli->show_help();
    return 1;
}

exit main();