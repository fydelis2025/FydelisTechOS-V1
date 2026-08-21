#!/usr/bin/perl
# ================================================================
#    F Y D E L I S S T R E S S   v 3 . 0   U L T I M A T E
#                    FydelisTechos © 2026
#   Ferramenta Profissional de Teste de Resiliência
#   USO EXCLUSIVO EM INFRAESTRUTURA PRÓPRIA E AUTORIZADA
# ================================================================

use strict;
use warnings;
use Socket;
use Getopt::Long qw(:config no_ignore_case);
use threads;
use threads::shared;
use Time::HiRes qw(sleep time);
use Term::ANSIColor;
use POSIX qw(ceil floor);
use IO::Select;

# ────────────────────────────────────────────────────────────────
#                     C O N F I G U R A Ç Õ E S
# ────────────────────────────────────────────────────────────────
my %CONFIG = (
    host        => undef,
    port        => undef,
    duration    => 10,
    threads     => 5,
    timeout     => 1,
    confirmed   => 0,
    method      => 'tcp_connect',
    verbose     => 0,
    interval    => 1,
    export      => undef,      # json | csv | none
    export_file => undef,
    proxy       => undef,      # user:pass@host:port
    slowloris_interval => 10,  # segundos entre keep-alive no slowloris
);

# ────────────────────────────────────────────────────────────────
#               E S T A D O   C O M P A R T I L H A D O
# ────────────────────────────────────────────────────────────────
my $start_time    :shared = 0;
my $stop_flag     :shared = 0;
my $conn_ok       :shared = 0;
my $conn_fail     :shared = 0;
my $conn_total    :shared = 0;
my $active_thr    :shared = 0;
my $mutex         :shared = 0;

# Amostras para o gráfico ASCII (coletadas a cada intervalo)
my @rate_samples  :shared = ();
my @time_samples  :shared = ();

# ────────────────────────────────────────────────────────────────
#                    C O R E S   A N S I
# ────────────────────────────────────────────────────────────────
my $C_RED       = color('bold red');
my $C_GREEN     = color('bold green');
my $C_YELLOW    = color('bold yellow');
my $C_CYAN      = color('bold cyan');
my $C_MAGENTA   = color('bold magenta');
my $C_WHITE     = color('bold white');
my $C_RESET     = color('reset');

# ────────────────────────────────────────────────────────────────
#                   B A N N E R   /   A J U D A
# ────────────────────────────────────────────────────────────────
sub banner {
    print <<"BANNER";
${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗
║        ${C_WHITE}F Y D E L I S S T R E S S   v 3 . 0   U L T I M A T E${C_CYAN}           ║
║                  ${C_YELLOW}FydelisTechos © 2026${C_CYAN}                                  ║
║    ${C_GREEN}Ferramenta Profissional de Teste de Resiliência${C_CYAN}                     ║
╚══════════════════════════════════════════════════════════════════════╝${C_RESET}
BANNER
}

sub ajuda {
    banner();
    print <<"AJUDA";
${C_WHITE}USO:${C_RESET}
    fydelisstress -h <SEU_IP> -p <PORTA> --confirmar [OPÇÕES]

${C_WHITE}OPÇÕES OBRIGATÓRIAS:${C_RESET}
  -h, --host ENDEREÇO         ${C_YELLOW}Seu endereço IP ou domínio${C_RESET}
  -p, --porta NÚMERO          ${C_YELLOW}Porta do serviço a testar${C_RESET}
  --confirmar                 ${C_YELLOW}Confirma que é ambiente próprio${C_RESET}

${C_WHITE}OPÇÕES GERAIS:${C_RESET}
  -d, --duracao SEGUNDOS      Duração do teste (padrão: 10, máx: 60)
  -T, --threads NÚMERO        Threads simultâneas (padrão: 5, máx: 20)
  -t, --timeout SEGUNDOS      Timeout por conexão (padrão: 1)
  -m, --method MÉTODO         Método: tcp_connect | http_get | slowloris
  -L, --slowloris-interval    Intervalo keep-alive slowloris (padrão: 10s)
  -i, --interval SEGUNDOS     Intervalo de relatório (padrão: 1)
  -v, --verbose               Modo detalhado (log de cada conexão)

${C_WHITE}PROXY:${C_RESET}
  -P, --proxy PROXY           ${C_YELLOW}Proxy HTTP CONNECT (user:pass@host:porta)${C_RESET}

${C_WHITE}EXPORTAÇÃO:${C_RESET}
  -e, --export FORMATO        json | csv (exporta relatório para arquivo)
  -o, --output ARQUIVO        Nome do arquivo de saída (auto se omitido)

${C_WHITE}OUTROS:${C_RESET}
  -H, --ajuda                 Mostra esta ajuda
  -V, --versao                Mostra a versão

${C_WHITE}EXEMPLOS:${C_RESET}
  ${C_GREEN}fydelisstress -h 192.168.0.50 -p 80 -d 15 --confirmar${C_RESET}
  ${C_GREEN}fydelisstress -h 10.0.0.1 -p 443 -T 10 -d 30 -m http_get --confirmar -v${C_RESET}
  ${C_GREEN}fydelisstress -h 10.0.0.1 -p 80 -m slowloris -T 50 -d 30 --confirmar${C_RESET}
  ${C_GREEN}fydelisstress -h 10.0.0.1 -p 8080 -P proxy.local:3128 -d 20 --confirmar${C_RESET}
  ${C_GREEN}fydelisstress -h 10.0.0.1 -p 80 -d 20 -e json -o relatorio.json --confirmar${C_RESET}

${C_WHITE}⚠  AVISO:${C_YELLOW} USO EXCLUSIVO EM SISTEMAS PRÓPRIOS OU AUTORIZADOS${C_RESET}
AJUDA
    exit 0;
}

# ────────────────────────────────────────────────────────────────
#               P A R S E   D E   A R G U M E N T O S
# ────────────────────────────────────────────────────────────────
sub parse_args {
    my ($host, $port, $duration, $threads, $timeout, $method,
        $interval, $confirm, $help, $version, $verbose,
        $export, $output, $proxy, $slowloris_interval);

    my $result = GetOptions(
        "h|host=s"               => \$host,
        "p|porta=i"              => \$port,
        "d|duracao=i"            => \$duration,
        "T|threads=i"            => \$threads,
        "t|timeout=f"            => \$timeout,
        "m|method=s"             => \$method,
        "i|interval=i"           => \$interval,
        "L|slowloris-interval=i" => \$slowloris_interval,
        "confirmar"              => \$confirm,
        "H|ajuda"                => \$help,
        "V|versao"               => \$version,
        "v|verbose"              => \$verbose,
        "e|export=s"             => \$export,
        "o|output=s"             => \$output,
        "P|proxy=s"              => \$proxy,
    );

    if (!$result) {
        print "${C_RED}❌ Erro ao parsear argumentos. Use -H para ajuda.${C_RESET}\n";
        exit 1;
    }

    ajuda() if $help;

    if ($version) {
        print "FydelisStress v3.0 Ultimate | FydelisTechos © 2026\n";
        exit 0;
    }

    die "${C_RED}❌ VOCÊ DEVE CONFIRMAR USO PRÓPRIO COM --confirmar${C_RESET}\n" unless $confirm;
    die "${C_RED}❌ Informe --host e --porta${C_RESET}\n" if !$host || !$port;
    die "${C_RED}❌ Porta inválida: $port${C_RESET}\n" if $port < 1 || $port > 65535;

    my @valid_methods = qw(tcp_connect http_get slowloris);
    $method ||= 'tcp_connect';
    die "${C_RED}❌ Método inválido. Use: @valid_methods${C_RESET}\n"
        unless grep { $_ eq $method } @valid_methods;

    if ($export) {
        die "${C_RED}❌ Formato de exportação inválido. Use json ou csv${C_RESET}\n"
            unless $export =~ /^(json|csv)$/i;
    }

    # Proxy parsing
    if ($proxy) {
        # Formatos aceitos:
        #   proxy.host:3128
        #   user:pass@proxy.host:3128
        if ($proxy =~ /^(.+):(\d+)$/) {
            $CONFIG{proxy} = { host => $1, port => $2, user => undef, pass => undef };
        } elsif ($proxy =~ /^(.+?):(.+?)@(.+?):(\d+)$/) {
            $CONFIG{proxy} = { host => $3, port => $4, user => $1, pass => $2 };
        } else {
            die "${C_RED}❌ Formato de proxy inválido. Use: host:porta ou user:pass@host:porta${C_RESET}\n";
        }
    }

    $CONFIG{duration}          = $duration if defined $duration;
    $CONFIG{duration}          = 60 if $CONFIG{duration} > 60;
    $CONFIG{duration}          = 2  if $CONFIG{duration} < 2;

    $CONFIG{threads}           = $threads if defined $threads;
    $CONFIG{threads}           = 20  if $CONFIG{threads} > 20;
    $CONFIG{threads}           = 1   if $CONFIG{threads} < 1;

    $CONFIG{timeout}           = $timeout  if defined $timeout;
    $CONFIG{interval}          = $interval if defined $interval;
    $CONFIG{slowloris_interval}= $slowloris_interval if defined $slowloris_interval;
    $CONFIG{verbose}           = $verbose;
    $CONFIG{method}            = lc($method);
    $CONFIG{host}              = $host;
    $CONFIG{port}              = $port;
    $CONFIG{export}            = lc($export) if $export;
    $CONFIG{export_file}       = $output;
}

# ────────────────────────────────────────────────────────────────
#                      U T I L I T Á R I O S
# ────────────────────────────────────────────────────────────────
sub fmt_time {
    my $sec = int(shift || 0);
    return sprintf("%02d:%02d", int($sec/60), $sec % 60);
}

sub fmt_num {
    my $n = shift;
    $n = reverse $n;
    $n =~ s/(\d{3})(?=\d)/$1./g;
    return reverse $n;
}

sub clear_line {
    print "\r" . " " x 90 . "\r";
}

sub progress_bar {
    my ($elapsed, $total, $width) = @_;
    $width ||= 30;
    my $ratio = $total > 0 ? $elapsed / $total : 0;
    $ratio = 1 if $ratio > 1;
    my $filled = ceil($ratio * $width);
    $filled = $width if $filled > $width;
    my $empty  = $width - $filled;
    my $bar_color = $ratio < 0.5 ? $C_GREEN
                  : $ratio < 0.8 ? $C_YELLOW : $C_RED;
    return $bar_color . "█" x $filled . $C_RESET . "░" x $empty;
}

sub resolve_host {
    my $host = shift;
    my $ip;
    eval {
        local $SIG{ALRM} = sub { die "timeout" };
        alarm 5;
        $ip = inet_aton($host);
        alarm 0;
    };
    if ($@ || !$ip) {
        warn "${C_RED}❌ Falha ao resolver DNS: $host${C_RESET}\n";
        return undef;
    }
    return $ip;
}

# ────────────────────────────────────────────────────────────────
#          C O N E X Ã O   C O M   S U P O R T E   A   P R O X Y
# ────────────────────────────────────────────────────────────────

# Cria um socket conectado ao destino, passando por proxy HTTP CONNECT se configurado
sub criar_conexao {
    my ($host_ip, $port) = @_;

    my $proxy = $CONFIG{proxy};
    my $sock;

    if ($proxy) {
        # ── Conecta ao proxy primeiro ──────────────────────
        $sock = IO::Socket::INET->new(
            PeerAddr => $proxy->{host},
            PeerPort => $proxy->{port},
            Proto    => 'tcp',
            Timeout  => $CONFIG{timeout},
        ) or return undef;

        # ── Envia requisição CONNECT ───────────────────────
        my $target_host = inet_ntoa($host_ip);
        my $connect_req = "CONNECT $target_host:$port HTTP/1.1\r\n"
                        . "Host: $target_host:$port\r\n";

        if ($proxy->{user} && $proxy->{pass}) {
            require MIME::Base64;
            my $auth = MIME::Base64::encode_base64("$proxy->{user}:$proxy->{pass}", '');
            $connect_req .= "Proxy-Authorization: Basic $auth\r\n";
        }

        $connect_req .= "\r\n";
        print $sock $connect_req;

        # ── Lê resposta do proxy ──────────────────────────
        my $resp = '';
        while (<$sock>) {
            $resp .= $_;
            last if /^\s*$/;
        }

        # Verifica se o proxy respondeu 200 Connection established
        if ($resp !~ /HTTP\/[\d.]+\s+2\d{2}/) {
            close $sock;
            return undef;
        }

    } else {
        # ── Conexão direta ────────────────────────────────
        $sock = IO::Socket::INET->new(
            PeerAddr => inet_ntoa($host_ip),
            PeerPort => $port,
            Proto    => 'tcp',
            Timeout  => $CONFIG{timeout},
        ) or return undef;
    }

    return $sock;
}

# ────────────────────────────────────────────────────────────────
#              M É T O D O S   D E   A T A Q U E
# ────────────────────────────────────────────────────────────────

# ─── TCP Connect ───────────────────────────────────────────────
sub attack_tcp_connect {
    my ($host_ip, $port) = @_;

    while (!$stop_flag) {
        my $sock = eval {
            local $SIG{ALRM} = sub { die "timeout" };
            alarm $CONFIG{timeout};
            my $s = criar_conexao($host_ip, $port);
            alarm 0;
            $s;
        };

        if ($sock) {
            close $sock;
            { lock $mutex; $conn_ok++; $conn_total++; }
        } else {
            { lock $mutex; $conn_fail++; $conn_total++; }
            alarm 0;
        }

        sleep 0.01 unless $CONFIG{verbose};
    }
}

# ─── HTTP GET ──────────────────────────────────────────────────
sub attack_http_get {
    my ($host_ip, $port) = @_;

    while (!$stop_flag) {
        my $sock = eval {
            local $SIG{ALRM} = sub { die "timeout" };
            alarm $CONFIG{timeout};

            my $s = criar_conexao($host_ip, $port) or return undef;

            my $host_name = $CONFIG{host};
            print $s "GET / HTTP/1.1\r\n"
                   . "Host: $host_name\r\n"
                   . "User-Agent: FydelisStress/3.0\r\n"
                   . "Connection: close\r\n\r\n";

            # Lê headers da resposta
            while (<$s>) {
                last if /^\s*$/;
            }

            alarm 0;
            $s;
        };

        if ($sock) {
            close $sock;
            { lock $mutex; $conn_ok++; $conn_total++; }
        } else {
            { lock $mutex; $conn_fail++; $conn_total++; }
            alarm 0;
        }

        sleep 0.01 unless $CONFIG{verbose};
    }
}

# ─── Slowloris ─────────────────────────────────────────────────
# Mantém conexões HTTP abertas enviando headers parciais
sub attack_slowloris {
    my ($host_ip, $port) = @_;
    my $keepalive = $CONFIG{slowloris_interval};

    while (!$stop_flag) {
        my $sock = eval {
            local $SIG{ALRM} = sub { die "timeout" };
            alarm $CONFIG{timeout};

            my $s = criar_conexao($host_ip, $port) or return undef;

            # Envia linha inicial e um header, mas NÃO finaliza a requisição
            my $host_name = $CONFIG{host};
            print $s "GET / HTTP/1.1\r\n"
                   . "Host: $host_name\r\n"
                   . "User-Agent: FydelisStress/3.0 (Slowloris)\r\n"
                   . "Accept: */*\r\n";

            alarm 0;
            $s;
        };

        if ($sock) {
            { lock $mutex; $conn_ok++; $conn_total++; }

            # Mantém a conexão viva enviando headers periódicos
            my $last_keepalive = time;
            while (!$stop_flag) {
                if ((time - $last_keepalive) >= $keepalive) {
                    last unless eval {
                        local $SIG{ALRM} = sub { die "timeout" };
                        alarm 2;
                        print $sock "X-KeepAlive: " . time() . "\r\n";
                        alarm 0;
                        1;
                    };
                    $last_keepalive = time;
                }
                sleep 0.5;
            }

            close $sock;
            # Se saímos pelo stop_flag, não conta como falha
            # Se saímos porque conexão caiu, conta como falha
            if (!$stop_flag) {
                { lock $mutex; $conn_fail++; }
            }
        } else {
            { lock $mutex; $conn_fail++; $conn_total++; }
            alarm 0;
            sleep 0.5;  # espera um pouco antes de tentar novamente
        }
    }
}

# ────────────────────────────────────────────────────────────────
#                W O R K E R   (dispatch)
# ────────────────────────────────────────────────────────────────
sub worker {
    my ($host_ip, $port, $method) = @_;
    { lock $mutex; $active_thr++; }

    if ($method eq 'tcp_connect') {
        attack_tcp_connect($host_ip, $port);
    } elsif ($method eq 'http_get') {
        attack_http_get($host_ip, $port);
    } elsif ($method eq 'slowloris') {
        attack_slowloris($host_ip, $port);
    }

    { lock $mutex; $active_thr--; }
}

# ────────────────────────────────────────────────────────────────
#            M O N I T O R   (relatório + amostras)
# ────────────────────────────────────────────────────────────────
sub monitor_thread {
    my $duration = shift;
    my $last_total = 0;

    while (!$stop_flag && (time - $start_time) < $duration) {
        my $elapsed = time - $start_time;
        $elapsed = 1 if $elapsed < 1;

        # Calcula taxa instantânea
        my $current_total;
        { lock $mutex; $current_total = $conn_total; }
        my $rate = $current_total - $last_total;
        $last_total = $current_total;

        # Armazena para o gráfico
        push @time_samples, $elapsed;
        push @rate_samples, $rate;

        # Exibe relatório
        report($elapsed, $duration);

        sleep $CONFIG{interval};
    }
}

# ────────────────────────────────────────────────────────────────
#              R E L A T Ó R I O   E M   T E M P O   R E A L
# ────────────────────────────────────────────────────────────────
sub report {
    my ($elapsed, $duration) = @_;
    my $rate = $elapsed > 0 ? int($conn_total / $elapsed) : 0;
    my $pct  = $duration > 0 ? ($elapsed / $duration) * 100 : 0;
    $pct = 100 if $pct > 100;
    my $bar = progress_bar($elapsed, $duration);

    print "\r";
    printf(
        "${C_CYAN}[%s]${C_RESET} %s  " .
        "${C_WHITE}%5.1f%%${C_RESET}  " .
        "${C_GREEN}✓ %s${C_RESET}  " .
        "${C_RED}✗ %s${C_RESET}  " .
        "${C_YELLOW}⏱ %s/s${C_RESET}  " .
        "${C_MAGENTA}⚡ %s thr${C_RESET}   ",
        fmt_time($elapsed),
        $bar,
        $pct,
        fmt_num($conn_ok),
        fmt_num($conn_fail),
        fmt_num($rate),
        $CONFIG{threads},
    );
}

# ────────────────────────────────────────────────────────────────
#           G R Á F I C O   A S C I I   D E   T A X A
# ────────────────────────────────────────────────────────────────
sub desenhar_grafico_ascii {
    my @times  = @{ shift() };
    my @rates  = @{ shift() };
    my $width  = shift || 50;
    my $height = shift || 10;

    return if scalar @rates < 2;

    my $max_rate = 1;
    $max_rate = $_ for grep { $_ > $max_rate } @rates;

    print "\n${C_WHITE}📈 GRÁFICO DE TAXA DE CONEXÕES (cheias/s ao longo do tempo):${C_RESET}\n\n";

    # Desenha o gráfico de cima para baixo
    for (my $y = $height; $y >= 0; $y--) {
        my $row = '';
        my $label = int(($y / $height) * $max_rate);
        $row .= sprintf("${C_YELLOW}%4d${C_RESET} │ ", $label);

        for (my $x = 0; $x < scalar @rates; $x++) {
            my $val = $rates[$x];
            my $bar_height = $height > 0 ? ceil(($val / $max_rate) * $height) : 0;
            $row .= ($y < $bar_height) ? "${C_GREEN}█${C_RESET}" : " ";
        }

        print $row . "\n";
    }

    # Eixo X
    print "      └";
    print "─" x scalar(@rates) . "\n";

    # Labels do eixo X (tempo)
    print "       ";
    my $step = int(scalar(@times) / 6) + 1;
    for (my $i = 0; $i < scalar @times; $i += $step) {
        printf("${C_CYAN}%ds${C_RESET}", $times[$i]);
        my $spaces = $step > 1 ? ($step - 1) : 1;
        print " " x ($spaces - 1);
    }
    print "\n";

    # Legenda
    printf "\n  ${C_WHITE}Legenda:${C_RESET} Pico máximo: ${C_GREEN}%s/s${C_RESET}, Média: ${C_YELLOW}%s/s${C_RESET}\n",
        fmt_num($max_rate),
        fmt_num(scalar(@rates) > 0 ? int((0.5 + grep { 1 } @rates) ? (0.5 + (sum(\@rates) / scalar(@rates))) : 0) : 0);
}

sub sum {
    my $arr = shift;
    my $total = 0;
    $total += $_ for @$arr;
    return $total;
}

# ────────────────────────────────────────────────────────────────
#        R E L A T Ó R I O   F I N A L   (tela + export)
# ────────────────────────────────────────────────────────────────
sub final_report {
    my $elapsed = time - $start_time;
    $elapsed = 1 if $elapsed < 1;
    my $rate = int($conn_total / $elapsed);
    my $fail_pct = $conn_total > 0 ? ($conn_fail / $conn_total) * 100 : 0;

    print "\n\n";
    print "${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}\n";
    print "${C_CYAN}║${C_WHITE}                    R E L A T Ó R I O   F I N A L${C_CYAN}                        ║${C_RESET}\n";
    print "${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n";

    printf "  ${C_WHITE}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n",       "🎯 Alvo:",         "$CONFIG{host}:$CONFIG{port}";
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_CYAN}%s${C_RESET}\n",        "📡 Método:",        uc($CONFIG{method});
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_YELLOW}%s${C_RESET}\n",      "⏱  Duração:",       fmt_time($elapsed);
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_MAGENTA}%d${C_RESET}\n",     "⚡ Threads:",        $CONFIG{threads};
    print  "\n";
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n",       "✅ Conexões OK:",    fmt_num($conn_ok);
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_RED}%s${C_RESET}\n",         "❌ Conexões Falhas:", fmt_num($conn_fail);
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_WHITE}%s${C_RESET}\n",       "📊 Total:",          fmt_num($conn_total));
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_YELLOW}%s/s${C_RESET}\n",    "🚀 Taxa Média:",     fmt_num($rate));
    print  "\n";

    my $rating_color = $fail_pct < 5  ? $C_GREEN
                     : $fail_pct < 20 ? $C_YELLOW : $C_RED;
    my $rating_text  = $fail_pct < 5  ? "EXCELENTE ✓"
                     : $fail_pct < 20 ? "MODERADO ⚠" : "CRÍTICO ✗";

    printf "  ${C_WHITE}%-28s${C_RESET} ${C_GREEN}%.1f%%${C_RESET}\n",   "✅ Taxa de Sucesso:", 100 - $fail_pct;
    printf "  ${C_WHITE}%-28s${C_RESET} ${C_RED}%.1f%%${C_RESET}\n",     "❌ Taxa de Falha:",   $fail_pct;
    printf "  ${C_WHITE}%-28s${C_RESET} %s${C_RESET}\n",                "🏆 Resiliência:",     $rating_color . $rating_text;

    print "\n${C_CYAN}════════════════════════════════════════════════════════════════════════${C_RESET}\n";
    print "${C_GREEN}✅ TESTE FINALIZADO COM SUCESSO${C_RESET}\n";
    print "${C_CYAN}════════════════════════════════════════════════════════════════════════${C_RESET}\n\n";

    # ── Gráfico ASCII ─────────────────────────────────────────
    desenhar_grafico_ascii(\@time_samples, \@rate_samples);

    # ── Exportação ────────────────────────────────────────────
    if ($CONFIG{export}) {
        export_results($elapsed, $fail_pct, $rating_text);
    }
}

# ────────────────────────────────────────────────────────────────
#          E X P O R T A Ç Ã O   ( J S O N   /   C S V )
# ────────────────────────────────────────────────────────────────
sub export_results {
    my ($elapsed, $fail_pct, $rating) = @_;

    my $format = $CONFIG{export};
    my $filename = $CONFIG{export_file};

    # Define nome padrão se não foi especificado
    unless ($filename) {
        my $ts = strftime("%Y%m%d_%H%M%S", localtime);
        $filename = "fydelisstress_$CONFIG{host}_$CONFIG{port}_$ts.$format";
    }

    if ($format eq 'json') {
        export_json($filename, $elapsed, $fail_pct, $rating);
    } elsif ($format eq 'csv') {
        export_csv($filename, $elapsed, $fail_pct, $rating);
    }
}

sub export_json {
    my ($file, $elapsed, $fail_pct, $rating) = @_;

    # Prepara dados das amostras para o JSON
    my @samples_data;
    for (my $i = 0; $i < scalar @time_samples; $i++) {
        push @samples_data, {
            time       => $time_samples[$i],
            timestamp  => time - $start_time + $time_samples[$i],
            rate       => $rate_samples[$i],
        };
    }

    my $data = {
        tool        => "FydelisStress v3.0 Ultimate",
        author      => "FydelisTechos © 2026",
        target      => "$CONFIG{host}:$CONFIG{port}",
        method      => $CONFIG{method},
        duration    => $elapsed,
        threads     => $CONFIG{threads},
        proxy       => $CONFIG{proxy} ? "$CONFIG{proxy}->{host}:$CONFIG{proxy}->{port}" : undef,
        timestamp   => scalar(localtime),
        results     => {
            conn_ok     => $conn_ok,
            conn_fail   => $conn_fail,
            conn_total  => $conn_total,
            avg_rate    => int($conn_total / ($elapsed || 1)),
            success_pct => sprintf("%.1f", 100 - $fail_pct),
            fail_pct    => sprintf("%.1f", $fail_pct),
            resilience  => $rating,
        },
        samples     => \@samples_data,
    };

    require JSON;
    my $json = JSON->new->pretty->canonical->encode($data);

    open(my $fh, '>', $file) or die "${C_RED}❌ Erro ao escrever $file: $!${C_RESET}\n";
    print $fh $json;
    close $fh;

    print "${C_GREEN}📄 Relatório JSON exportado: $file${C_RESET}\n";
}

sub export_csv {
    my ($file, $elapsed, $fail_pct, $rating) = @_;

    open(my $fh, '>', $file) or die "${C_RED}❌ Erro ao escrever $file: $!${C_RESET}\n";

    # Cabeçalho
    print $fh "timestamp,segundos,taxa_conexoes_s\n";

    # Dados das amostras
    my $base_time = time;
    for (my $i = 0; $i < scalar @time_samples; $i++) {
        printf $fh "%s,%d,%d\n",
            scalar(localtime($base_time - $elapsed + $time_samples[$i])),
            $time_samples[$i],
            $rate_samples[$i];
    }

    close $fh;

    print "${C_GREEN}📄 Relatório CSV exportado: $file${C_RESET}\n";
}

# ════════════════════════════════════════════════════════════════
#                         M A I N
# ════════════════════════════════════════════════════════════════

# Sinal de saída limpa
$SIG{INT} = sub {
    print "\n\n${C_YELLOW}⚠  Sinal recebido. Encerrando threads...${C_RESET}\n";
    $stop_flag = 1;
};

# 1. Parse
parse_args(@ARGV);

# 2. Banner
banner();

# 3. Resolve DNS
print "${C_YELLOW}🔍 Resolvendo DNS: $CONFIG{host}...${C_RESET}\n";
my $host_ip = resolve_host($CONFIG{host});
die "${C_RED}❌ Não foi possível resolver o host. Abortando.${C_RESET}\n" unless $host_ip;
print "${C_GREEN}✅ DNS resolvido: " . inet_ntoa($host_ip) . "${C_RESET}\n\n";

# 4. Resumo da configuração
print "${C_YELLOW}⚠  INICIANDO TESTE DE RESILIÊNCIA CONTROLADO${C_RESET}\n";
printf "  ${C_WHITE}%-24s${C_RESET} ${C_CYAN}%s${C_RESET}\n",    "🎯 Alvo:",   "$CONFIG{host}:$CONFIG{port}";
printf "  ${C_WHITE}%-24s${C_RESET} ${C_CYAN}%s${C_RESET}\n",    "📡 Método:", uc($CONFIG{method});
printf "  ${C_WHITE}%-24s${C_RESET} ${C_YELLOW}%ds${C_RESET}\n",  "⏱ Duração:", $CONFIG{duration};
printf "  ${C_WHITE}%-24s${C_RESET} ${C_MAGENTA}%d${C_RESET}\n", "⚡ Threads:", $CONFIG{threads};
if ($CONFIG{proxy}) {
    printf "  ${C_WHITE}%-24s${C_RESET} ${C_YELLOW}%s:%s${C_RESET}\n", "🌐 Proxy:",
        $CONFIG{proxy}->{host}, $CONFIG{proxy}->{port};
}
if ($CONFIG{export}) {
    printf "  ${C_WHITE}%-24s${C_RESET} ${C_GREEN}%s${C_RESET}\n",   "📄 Exportar:", $CONFIG{export};
}
print "\n${C_GREEN}Pressione Ctrl+C para interromper a qualquer momento${C_RESET}\n";
print "=" x 70 . "\n";
sleep 2;

# 5. Inicializa
$start_time = time;

# 6. Thread de monitoramento
my $monitor = threads->create(\&monitor_thread, $CONFIG{duration});

# 7. Threads workers
my @workers;
for (1..$CONFIG{threads}) {
    push @workers, threads->create(\&worker, $host_ip, $CONFIG{port}, $CONFIG{method});
}

# 8. Aguarda término
$_->join for @workers;
$stop_flag = 1;
$monitor->join();

# 9. Relatório final
final_report();

exit 0;