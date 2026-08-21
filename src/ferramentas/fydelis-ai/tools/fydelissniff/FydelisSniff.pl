#!/usr/bin/perl
# ==============================================================
#          F Y D E L I S S N I F F   v 2 . 0   P R O
#                     FydelisTechos © 2026
#   Sniffer de Rede Profissional — Uso Autorizado Apenas
# ==============================================================
#
# Dependências: tcpdump (obrigatório), Net::Pcap (opcional para
#               estatísticas avançadas)
#
# Compatibilidade: Linux/Unix com Perl 5.10+
#
# ==============================================================

use strict;
use warnings;
use v5.10.0;  # para say

# --- Módulos padrão ---
use Getopt::Long qw(:config no_ignore_case bundling);
use POSIX qw(strftime);
use File::Spec;
use Cwd 'abs_path';
use English qw(-no_match_vars);

# --- Constantes ---
use constant {
    VERSION    => '2.0',
    AUTHOR     => 'FydelisTechos',
    YEAR       => '2026',
    TOOL_NAME  => 'FydelisSniff',
    PID_DIR    => '/tmp',
    TcpdumpBin => '/usr/sbin/tcpdump',  # fallback, será procurado
};

# --- Variáveis globais ---
my ($iface, $cont, $filtro, $saida, $timeout, $pid_file);
my ($ajuda, $versao, $verbose, $modo_texto, $pcapng, $no_promisc);
my ($log_file, $quieto);
my $stats = { start_time => undef, packet_count => 0, stopped_by => 'desconhecido' };
my $running = 1;

# ======================================================================
#                        SUB-ROTINAS PRINCIPAIS
# ======================================================================

sub mostra_ajuda {
    print <<"AJUDA";
======================================================================
    ${\(TOOL_NAME)} v@{[VERSION]} — ${\(AUTHOR)} © ${\(YEAR)}
            Sniffer de Rede Profissional
======================================================================

  📌 USO: sudo $0 -i INTERFACE [OPÇÕES]

  ═══════════════════════════════════════════════════════════════════
   OBRIGATÓRIO
  ═══════════════════════════════════════════════════════════════════
   -i, --interface NOME      Interface de rede (eth0, wlan0, lo, etc.)
        --iface NOME         Sinônimo de --interface

  ═══════════════════════════════════════════════════════════════════
   CAPTURA
  ═══════════════════════════════════════════════════════════════════
   -c, --contagem N          Parar após N pacotes
   -t, --timeout SEGUNDOS    Parar após N segundos
   -f, --filtro EXPR         Filtro BPF. Ex: "port 80", "icmp", "host 10.0.0.1"
       --no-promisc          NÃO colocar interface em modo promíscuo
       --pcapng              Usar formato PCAPNG (moderno, inclui metadados)

  ═══════════════════════════════════════════════════════════════════
   SAÍDA E LOG
  ═══════════════════════════════════════════════════════════════════
   -o, --salvar ARQUIVO      Salvar captura em arquivo .pcap
   -T, --texto               Exibir pacotes em tempo real no terminal
   -L, --log ARQUIVO         Arquivo de log da execução
   -q, --quieto              Modo silencioso (mínima saída no terminal)

  ═══════════════════════════════════════════════════════════════════
   COMPORTAMENTO
  ═══════════════════════════════════════════════════════════════════
   -v, --verbose             Aumenta verbosidade (-vv para máximo)
   -H, --ajuda               Mostra esta mensagem e sai
   -V, --versao              Exibe versão e sai

  ═══════════════════════════════════════════════════════════════════
   EXEMPLOS
  ═══════════════════════════════════════════════════════════════════
   # Captura básica na eth0 (modo texto na tela)
   sudo $0 -i eth0 --texto -c 50

   # Captura com filtro, salvando em pcap
   sudo $0 -i wlan0 -f "port 443" -o captura.pcap -t 60

   # Captura silenciosa com log
   sudo $0 -i eth0 -o ataque.pcap -q -L /var/log/sniff.log

   # Captura avançada com PCAPNG
   sudo $0 -i eth0 -f "tcp and not port 22" -o evidencia.pcapng --pcapng

======================================================================
AJUDA
    exit 0;
}

sub mostra_versao {
    print TOOL_NAME . " v" . VERSION . " | " . AUTHOR . " © " . YEAR . "\n";
    print "Perl v$] | $^O\n";
    exit 0;
}

sub log_msg {
    my ($nivel, $msg) = @_;
    return if $quieto && $nivel eq 'info';
    return if $verbose < 1 && $nivel eq 'debug';

    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $nivel_str = uc(substr($nivel, 0, 4));
    my $saida = "[$timestamp] [$nivel_str] $msg";

    # stdout
    say $saida unless $quieto && $nivel eq 'info';

    # arquivo de log
    if ($log_file && open(my $lfh, '>>', $log_file)) {
        say $lfh $saida;
        close $lfh;
    }
}

sub encontrar_tcpdump {
    # Procura o binário tcpdump em PATH ou locais comuns
    my @caminhos = split(/:/, $ENV{PATH} // '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin');
    push @caminhos, '/usr/sbin', '/usr/bin', '/sbin', '/bin';

    my %visto;
    for my $dir (@caminhos) {
        next if $visto{$dir}++;
        my $bin = File::Spec->catfile($dir, 'tcpdump');
        return $bin if -x $bin;
    }

    # Fallback para whereis/which
    for my $cmd ('whereis -b tcpdump', 'which tcpdump') {
        my $output = `$cmd 2>/dev/null`;
        chomp $output;
        my @parts = split(/\s+/, $output);
        next unless @parts > 1;
        for my $p (@parts[1..$#parts]) {
            return $p if -x $p;
        }
    }

    return undef;
}

sub validar_interface {
    my $iface = shift;
    # Verifica se a interface existe no sistema
    return 1 if -d "/sys/class/net/$iface";
    return 1 if `ip link show $iface 2>/dev/null`;
    return 1 if `ifconfig $iface 2>/dev/null`;
    return 0;
}

sub listar_interfaces {
    my @interfaces;
    if (opendir(my $dh, '/sys/class/net')) {
        @interfaces = grep { !/^\./ && !/^lo$/ } readdir($dh);
        closedir $dh;
    }
    return @interfaces;
}

sub criar_pid_file {
    my $iface = shift;
    $pid_file = File::Spec->catfile(PID_DIR, TOOL_NAME . "_${iface}.pid");
    return 1;
}

sub verificar_pid_file {
    return 0 unless $pid_file && -f $pid_file;
    open(my $fh, '<', $pid_file) or return 0;
    my $pid = <$fh>;
    chomp $pid;
    close $fh;
    # Verifica se o processo ainda existe
    if (kill(0, $pid)) {
        log_msg('erro', "Já existe uma instância rodando na interface $iface (PID $pid)");
        return 1;
    }
    # PID órfão, remove
    unlink $pid_file;
    return 0;
}

sub escrever_pid_file {
    return unless $pid_file;
    open(my $fh, '>', $pid_file) or do {
        log_msg('aviso', "Não foi possível criar PID file: $!");
        return;
    };
    say $fh $$;
    close $fh;
    log_msg('debug', "PID file criado: $pid_file (PID $$)");
}

sub limpar_pid_file {
    return unless $pid_file && -f $pid_file;
    unlink $pid_file;
    log_msg('debug', "PID file removido: $pid_file");
}

sub sinal_terminar {
    my $signame = shift;
    $running = 0;
    $stats->{stopped_by} = "Sinal $signame recebido";

    # Se tcpdump está rodando em foreground, o sinal vai para ele também
    # Apenas registramos para exibir estatísticas depois
}

sub exibir_estatisticas {
    return if $quieto;

    my $duracao = $stats->{start_time}
        ? time() - $stats->{start_time}
        : 0;

    print "\n";
    print "=" x 60, "\n";
    print " 📊 ESTATÍSTICAS DA CAPTURA\n";
    print "=" x 60, "\n";
    printf "  Interface : %s\n", $iface;
    printf "  Duração   : %ds (%dmin %ds)\n", $duracao,
        int($duracao / 60), $duracao % 60;
    printf "  Motivo    : %s\n", $stats->{stopped_by};
    print "=" x 60, "\n";

    # Se tivermos um arquivo de saída, informar
    if ($saida && -f $saida) {
        my $tamanho = (stat($saida))[7];
        printf "  Arquivo   : %s (%.2f KB)\n", $saida, $tamanho / 1024;
    }
    print "=" x 60, "\n";
}

# ======================================================================
#                      TRATAMENTO DE SINAIS
# ======================================================================

sub configurar_tratamento_sinais {
    $SIG{INT}  = \&sinal_terminar;
    $SIG{TERM} = \&sinal_terminar;
    $SIG{QUIT} = \&sinal_terminar;
    $SIG{HUP}  = sub {
        log_msg('aviso', 'Sinal SIGHUP recebido — recarregando...');
        # Aqui poderia recarregar config
    };
    $SIG{PIPE} = 'IGNORE';
}

# ======================================================================
#                      CONSTRUÇÃO DO COMANDO
# ======================================================================

sub construir_comando_tcpdump {
    my $tcpdump_bin = encontrar_tcpdump()
        or die "❌ tcpdump não encontrado! Instale com: sudo apt install tcpdump\n";

    my @cmd = ($tcpdump_bin);

    # Interface
    push @cmd, '-i', $iface;

    # Sem resolução de nomes (mais rápido e seguro)
    push @cmd, '-n';

    # Não resolução de portas
    push @cmd, '-nn';

    # Timestamp com microssegundos
    push @cmd, '-tttt';

    # Modo texto (imprimir na tela)
    if ($modo_texto) {
        # -v para um pouco mais de detalhe no texto
        push @cmd, '-v' if $verbose >= 1;
        push @cmd, '-vv' if $verbose >= 2;

        # Buffer de linha (imprime imediatamente)
        push @cmd, '-l';
    }

    # Modo quieto (tcpdump quiet) — não imprime nada no terminal
    push @cmd, '-q' if $quieto && !$modo_texto;

    # Contagem de pacotes
    push @cmd, '-c', $cont if $cont;

    # Timeout (GNU timeout externo)
    # Nota: tcpdump não tem --timeout nativo, usamos timeout do coreutils
    # Será aplicado externamente se necessário

    # Formato PCAPNG
    push @cmd, '--pcapng' if $pcapng;

    # Modo promíscuo
    push @cmd, '--no-promiscuous-mode' if $no_promisc;

    # Salvar arquivo
    push @cmd, '-w', $saida if $saida;

    # Filtro BPF (deve ser o último argumento)
    push @cmd, $filtro if $filtro;

    return @cmd;
}

# ======================================================================
#                      VALIDAÇÃO GERAL
# ======================================================================

sub validar_ambiente {
    my $erros = 0;

    # Verificar se é root
    if ($EFFECTIVE_USER_ID != 0) {
        say "❌ Este script requer privilégios root (sudo).";
        say "   Execute: sudo $0 @ARGV";
        $erros++;
    }

    # Verificar interface
    if (!$iface) {
        say "❌ Interface não especificada. Use -i INTERFACE";
        say "   Interfaces disponíveis: " . join(', ', listar_interfaces());
        $erros++;
    }
    elsif (!validar_interface($iface)) {
        say "❌ Interface '$iface' não encontrada no sistema.";
        my @disp = listar_interfaces();
        if (@disp) {
            say "   Interfaces disponíveis: " . join(', ', @disp);
        }
        $erros++;
    }

    # Verificar tcpdump
    unless (encontrar_tcpdump()) {
        say "❌ tcpdump não encontrado. Instale com:";
        say "   sudo apt install tcpdump   (Debian/Ubuntu/Kali)";
        say "   sudo yum install tcpdump   (RHEL/CentOS)";
        $erros++;
    }

    # Verificar conflito de opções
    if ($saida && $modo_texto) {
        log_msg('aviso', 'Usando --texto com -o: pacotes serão exibidos NA TELA e salvos no arquivo.');
    }

    if ($quieto && $modo_texto) {
        log_msg('aviso', 'Modo quieto + texto: log suprimido, mas pacotes aparecem no terminal.');
    }

    # Se não tem -o nem --texto, avisar
    unless ($saida || $modo_texto) {
        log_msg('aviso', 'Nenhuma saída especificada. Use -o ARQUIVO (salvar) ou --texto (terminal).');
    }

    if ($erros) {
        say "\n💡 Use -H para ajuda completa.";
        exit 1;
    }

    return 1;
}

# ======================================================================
#                        EXECUÇÃO PRINCIPAL
# ======================================================================

sub executar_captura {
    my @cmd = construir_comando_tcpdump();

    log_msg('info', "Iniciando captura na interface $iface...");
    log_msg('debug', "Comando: " . join(' ', @cmd));

    # Registrar início
    $stats->{start_time} = time();

    # Se há timeout, executa com timeout externo
    if ($timeout && $timeout > 0) {
        log_msg('info', "Timeout configurado: ${timeout}s");

        # Verifica se timeout (GNU coreutils) existe
        my $timeout_bin = `which timeout 2>/dev/null`;
        chomp $timeout_bin;

        if ($timeout_bin && -x $timeout_bin) {
            unshift @cmd, $timeout_bin, $timeout;
        }
        else {
            log_msg('aviso', "Comando 'timeout' não encontrado. Usando alarme Perl...");
            # Fallback: alarm Perl
            $SIG{ALRM} = sub {
                $stats->{stopped_by} = "Timeout de ${timeout}s";
                $running = 0;
                kill('TERM', 0);  # Envia para o grupo de processos
            };
            alarm($timeout);
        }
    }

    # Executa o tcpdump
    log_msg('info', "Captura em andamento. Pressione Ctrl+C para interromper.");
    log_msg('info', "-" x 50);

    # Redireciona stdout/stderr se estiver quieto
    if ($quieto && !$modo_texto) {
        my $saida_devnull = File::Spec->devnull();
        open(SAVED_STDOUT, '>&STDOUT');
        open(SAVED_STDERR, '>&STDERR');
        open(STDOUT, '>', $saida_devnull) or warn "Não pode redirecionar stdout: $!";
        open(STDERR, '>', $saida_devnull) or warn "Não pode redirecionar stderr: $!";
    }

    # Executa e captura exit code
    my $exit_code = system(@cmd);

    # Restaura stdout/stderr
    if ($quieto && !$modo_texto) {
        open(STDOUT, '>&SAVED_STDOUT');
        open(STDERR, '>&SAVED_STDERR');
        close(SAVED_STDOUT);
        close(SAVED_STDERR);
    }

    # Desativa alarme se estiver ativo
    alarm(0) if $timeout;

    # Processa resultado
    if ($exit_code == -1) {
        log_msg('erro', "Falha ao executar tcpdump: $!");
    }
    elsif ($exit_code & 127) {
        my $sig = $exit_code & 127;
        log_msg('info', "Captura interrompida pelo sinal $sig");
        $stats->{stopped_by} ||= "Sinal $sig";
    }
    else {
        my $real_exit = $exit_code >> 8;
        if ($real_exit == 0) {
            log_msg('info', "Captura concluída com sucesso.");
            $stats->{stopped_by} = 'Concluída normalmente';
        }
        else {
            log_msg('erro', "tcpdump encerrou com código $real_exit");
            $stats->{stopped_by} = "Erro (código $real_exit)";
        }
    }

    return $exit_code;
}

# ======================================================================
#                        ENTRADA PRINCIPAL
# ======================================================================

sub main {
    # --- Banner ---
    print "\n" . "=" x 60 . "\n";
    printf "  %s v%s  |  %s © %s\n", TOOL_NAME, VERSION, AUTHOR, YEAR;
    printf "  Sniffer de Rede Profissional  |  Perl %vd\n", $^V;
    print "=" x 60 . "\n\n";

    # --- Parse de argumentos ---
    GetOptions(
        'i|interface=s'  => \$iface,
        'iface=s'        => \$iface,        # alias
        'c|contagem=i'   => \$cont,
        't|timeout=i'    => \$timeout,
        'f|filtro=s'     => \$filtro,
        'o|salvar=s'     => \$saida,
        'T|texto!'       => \$modo_texto,   # --texto ativa, --no-texto desativa
        'L|log=s'        => \$log_file,
        'q|quieto!'      => \$quieto,
        'v|verbose+'     => \$verbose,      # acumulativo (-v, -vv, -vvv)
        'no-promisc!'    => \$no_promisc,   # --no-promisc
        'pcapng!'        => \$pcapng,       # --pcapng
        'H|ajuda'        => \$ajuda,
        'V|versao'       => \$versao,
        'h|help'         => \$ajuda,        # alias comum
    ) or do {
        say "\n❌ Erro nos argumentos. Use -H para ajuda.\n";
        exit 1;
    };

    mostra_ajuda()   if $ajuda;
    mostra_versao()  if $versao;

    # --- PID file (proteção contra múltiplas instâncias) ---
    if ($iface) {
        criar_pid_file($iface);
        if (verificar_pid_file()) {
            exit 1;
        }
    }

    # --- Validações ---
    validar_ambiente();

    # --- Configuração ---
    configurar_tratamento_sinais();
    escrever_pid_file();

    # --- Execução ---
    executar_captura();

    # --- Finalização ---
    exibir_estatisticas();
    limpar_pid_file();

    log_msg('info', "FydelisSniff encerrado.");
    print "\n✅ Captura finalizada.\n";
    exit 0;
}

# --- Ponto de entrada ---
main();

__END__

=head1 NOME

FydelisSniff - Sniffer de Rede Profissional

=head1 DESCRIÇÃO

Ferramenta profissional de captura de pacotes de rede, construída
sobre o tcpdump, com recursos avançados para testes de penetração
e análise de tráfego em ambientes autorizados.

=head1 REQUISITOS

=over 4

=item * Perl 5.10+

=item * tcpdump (obrigatório)

=item * Coreutils timeout (opcional, para timeout nativo)

=back

=head1 SEGURANÇA

Esta ferramenta deve ser usada exclusivamente em redes e sistemas
para os quais você possui autorização explícita por escrito.

=head1 AUTOR

FydelisTechos © 2026

=cut