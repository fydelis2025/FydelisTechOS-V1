#!/usr/bin/perl
# ================================================================
#            F Y D E L I S D O R K   v 3 . 0   P R O
#                    FydelisTechos © 2026
#   Ferramenta Profissional de Google Dorks & OSINT
#   USO EXCLUSIVO PARA ESTUDO E PESQUISA DE DADOS PÚBLICOS
# ================================================================

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use POSIX qw(strftime ceil);
use Term::ANSIColor;
use URI::Escape;
use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use List::Util qw(shuffle);

# ────────────────────────────────────────────────────────────────
#                     C O N F I G U R A Ç Õ E S
# ────────────────────────────────────────────────────────────────
my %CONFIG = (
    termo        => undef,
    site         => '',
    arquivo      => '',
    titulo       => '',
    url          => '',
    salvar       => undef,
    abrir        => 0,
    motor        => 'google',
    operador     => 'AND',
    exato        => 0,
    categorias   => undef,
    excluir      => '',
    intervalo    => '',
    intensidade  => 1,
    limite       => 0,
    interativo   => 0,
    extrair_urls => 0,
    verbose      => 0,
);

# ────────────────────────────────────────────────────────────────
#                    C O R E S   A N S I
# ────────────────────────────────────────────────────────────────
my $C_RED       = color('bold red');
my $C_GREEN     = color('bold green');
my $C_YELLOW    = color('bold yellow');
my $C_CYAN      = color('bold cyan');
my $C_MAGENTA   = color('bold magenta');
my $C_WHITE     = color('bold white');
my $C_BLUE      = color('bold blue');
my $C_RESET     = color('reset');

# ────────────────────────────────────────────────────────────────
#           C A T E G O R I A S   D E   D O R K S
# ────────────────────────────────────────────────────────────────
my %CATEGORIAS = (

    admin => [
        'intitle:"painel de administração"',
        'intitle:"login" inurl:admin',
        'inurl:admin filetype:php',
        'intitle:"administrador" inurl:admin',
        'site:gov.br intitle:"área restrita"',
        'inurl:/admin/login.php',
        'intitle:"controle administrativo"',
        'inurl:dashboard',
        'site:com.br inurl:admin intitle:login',
        'inurl:cpanel filetype:php',
        'intitle:"sistema de gestão"',
        'inurl:administrator',
        'inurl:wp-admin site:com.br',
        'intitle:"backend" inurl:admin',
        'inurl:portal filetype:php',
    ],

    painel => [
        'inurl:painel filetype:php',
        'intitle:"painel" inurl:controle',
        'intitle:"painel de controle"',
        'inurl:/panel/login',
        'intitle:"dashboard" inurl:painel',
        'inurl:gestao filetype:php',
        'intitle:"monitoramento" inurl:dashboard',
        'inurl:admin/painel',
        'intitle:"controle de acesso" inurl:login',
        'site:org.br intitle:"painel do sistema"',
    ],

    sql => [
        'inurl:php?id= site:com.br',
        'inurl:page_id= site:org',
        'inurl:index.php?id= filetype:php',
        'inurl:produto.php?id=',
        'inurl:noticia.php?id=',
        'inurl:artigo.php?id=',
        'inurl:categoria.php?id=',
        'inurl:post.php?id=',
        'inurl:download.php?file=',
        'intitle:"error in mysql" filetype:php',
        'inurl:?id= site:gov.br',
        'inurl:secao.php?id=',
        'inurl:noticias.php?id=',
        'inurl:item.php?id=',
        'inurl:pagina.php?id=',
    ],

    xss => [
        'inurl:search.php?q=',
        'inurl:busca.php?q=',
        'inurl:?query= site:com.br',
        'inurl:pesquisa.php?q=',
        'inurl:?search= filetype:php',
        'inurl:termo.php?palavra=',
        'inurl:resultado.php?s=',
        'inurl:index.php?search=',
        'inurl:?s= site:org',
        'intitle:"search" inurl:php?q=',
    ],

    info => [
        'intitle:"index of" site:com.br',
        'intitle:"index of" "backup"',
        'intitle:"index of" "logs"',
        'intitle:"index of" "config"',
        'intitle:"index of" "database"',
        'inurl:robots.txt site:com.br',
        'inurl:backup filetype:zip',
        'intitle:"directory listing" site:org',
        'site:com.br filetype:sql "insert into"',
        'site:com.br filetype:env',
        'intitle:"index of /" "secret"',
        'inurl:.git/config site:com.br',
        'site:com.br intitle:"phpinfo"',
        'inurl:wp-config.php site:com.br',
        'inurl:crossdomain.xml site:com.br',
    ],

    docs => [
        'filetype:pdf intitle:"relatório técnico"',
        'filetype:pdf "confidencial" site:com.br',
        'filetype:pdf "senha" site:org',
        'filetype:xls "usuários" "senha"',
        'filetype:doc "confidencial"',
        'filetype:pdf "dados pessoais"',
        'filetype:pdf intitle:"plano de segurança"',
        'filetype:csv "cpf" "nome"',
        'filetype:pdf "relatório anual" site:gov.br',
        'filetype:pdf "contrato" "confidencial"',
        'filetype:xlsx "controle de acesso"',
        'filetype:pdf "RFP" site:com.br',
        'filetype:pdf "auditoria" intitle:"relatório"',
        'filetype:docx "senha"',
        'filetype:pdf "proposta técnica" site:org',
    ],

    camera => [
        'inurl:view/view.shtml',
        'inurl:/webcam/ site:com.br',
        'intitle:"webcam" inurl:/',
        'inurl:cgi-bin/webcam',
        'intitle:"live view" inurl:snapshot',
        'inurl:/axis-cgi/',
        'intitle:"DVR" inurl:/login',
        'inurl:/control/userimage.html',
        'intitle:"IP Camera" site:com.br',
        'inurl:/cgi-bin/snapshot.cgi',
    ],
);

# ────────────────────────────────────────────────────────────────
#                    B A N N E R
# ────────────────────────────────────────────────────────────────
sub banner {
    print <<"BANNER";
${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗
║        ${C_WHITE}F Y D E L I S D O R K   v 3 . 0   P R O${C_CYAN}                     ║
║                  ${C_YELLOW}FydelisTechos © 2026${C_CYAN}                                  ║
║     ${C_GREEN}Ferramenta Profissional de Google Dorks & OSINT${C_CYAN}                   ║
╚══════════════════════════════════════════════════════════════════════╝${C_RESET}
BANNER
}

# ────────────────────────────────────────────────────────────────
#                       A J U D A
# ────────────────────────────────────────────────────────────────
sub ajuda {
    banner();
    print <<"AJUDA";
${C_WHITE}USO:${C_RESET}
    fydelisdork -t "TERMO" [OPÇÕES]
    fydelisdork -c CATEGORIA [OPÇÕES]
    fydelisdork -i

${C_WHITE}OPÇÕES BÁSICAS:${C_RESET}
  -t, --termo TEXTO         ${C_YELLOW}Palavra ou frase principal${C_RESET}
  -c, --categoria NOME       ${C_YELLOW}Categoria pronta: admin | painel | sql | xss | info | docs | camera${C_RESET}
  -s, --site DOMINIO         ${C_YELLOW}Filtrar por site (ex: gov.br)${C_RESET}
  -a, --arquivo TIPO         ${C_YELLOW}Tipo de arquivo: pdf, doc, xls, sql, txt, php, zip, csv, json${C_RESET}
  -T, --titulo TEXTO         ${C_YELLOW}Palavra no título da página${C_RESET}
  -u, --url TEXTO            ${C_YELLOW}Palavra na URL da página${C_RESET}

${C_WHITE}OPÇÕES AVANÇADAS:${C_RESET}
  -m, --motor MOTOR          ${C_YELLOW}google | bing | duckduckgo | yandex | startpage | all${C_RESET}
  -e, --excluir TEXTO        ${C_YELLOW}Palavra a EXCLUIR da busca${C_RESET}
  -E, --exato                ${C_YELLOW}Busca exata (aspas duplas)${C_RESET}
  -o, --operador TIPO        ${C_YELLOW}AND | OR | -${C_RESET}
  -d, --data "INICIO..FIM"   ${C_YELLOW}Filtrar intervalo de datas${C_RESET}
  -n, --intensidade N        ${C_YELLOW}1=mínimo | 2=médio | 3=agressivo${C_RESET}
  -l, --limite N             ${C_YELLOW}Limitar número de dorks gerados${C_RESET}

${C_WHITE}SAÍDA E EXPORTAÇÃO:${C_RESET}
  -o, --salvar ARQUIVO       ${C_YELLOW}Salvar resultados em arquivo${C_RESET}
  -f, --formato FORMATO      ${C_YELLOW}txt | html | json | csv | md${C_RESET}
  -A, --abrir                ${C_YELLOW}Abrir links no navegador${C_RESET}
  -v, --verbose              ${C_YELLOW}Modo detalhado${C_RESET}
  -i, --interativo           ${C_YELLOW}Modo interativo (menu guiado)${C_RESET}

${C_WHITE}EXEMPLOS:${C_RESET}
  ${C_GREEN}fydelisdork -t "segurança" -s exemplo.com -a pdf -o dorks.txt${C_RESET}
  ${C_GREEN}fydelisdork -c admin -s gov.br -f html -o admin_gov.html${C_RESET}
  ${C_GREEN}fydelisdork -c sql -n 3 -A -o sqli_dorks.txt${C_RESET}
  ${C_GREEN}fydelisdork -t "painel" -s com.br -u admin -i${C_RESET}
  ${C_GREEN}fydelisdork -c camera -m all -f json -o cameras.json${C_RESET}
  ${C_GREEN}fydelisdork -i${C_RESET}

${C_WHITE}⚠  AVISO:${C_YELLOW} USO EXCLUSIVO PARA ESTUDO E PESQUISA DE DADOS PÚBLICOS${C_RESET}
AJUDA
    exit 0;
}

# ────────────────────────────────────────────────────────────────
#                P A R S E   D E   A R G U M E N T O S
# ────────────────────────────────────────────────────────────────
sub parse_args {
    my ($termo, $site, $arquivo, $titulo, $url, $excluir, $exato,
        $motor, $operador, $data, $categoria, $intens, $limite,
        $salvar, $formato, $abrir, $verbose, $interativo, $extrair,
        $ajuda, $versao);
    my $excluir_val;
    my $exato_flag;

    my $result = GetOptions(
        "t|termo:s"          => \$termo,
        "c|categoria:s"      => \$categoria,
        "s|site:s"           => \$site,
        "a|arquivo:s"        => \$arquivo,
        "T|titulo:s"         => \$titulo,
        "u|url:s"            => \$url,
        "e|excluir:s"        => \$excluir_val,
        "E|exato"            => \$exato_flag,
        "m|motor:s"          => \$motor,
        "o|operador:s"       => \$operador,
        "d|data:s"           => \$data,
        "n|intensidade:i"    => \$intens,
        "l|limite:i"         => \$limite,
        "O|salvar:s"         => \$salvar,
        "f|formato:s"        => \$formato,
        "A|abrir"            => \$abrir,
        "v|verbose"          => \$verbose,
        "i|interativo"       => \$interativo,
        "x|extrair"          => \$extrair,
        "H|ajuda"            => \$ajuda,
        "V|versao"           => \$versao,
    );

    if (!$result) {
        print "${C_RED}❌ Erro ao parsear argumentos. Use -H para ajuda.${C_RESET}\n";
        exit 1;
    }

    ajuda() if $ajuda;

    if ($versao) {
        print "FydelisDork v3.0 Pro | FydelisTechos © 2026\n";
        print "Categorias: " . join(", ", sort keys %CATEGORIAS) . "\n";
        exit 0;
    }

    $CONFIG{termo}       = $termo       if defined $termo;
    $CONFIG{site}        = $site        if defined $site;
    $CONFIG{arquivo}     = $arquivo     if defined $arquivo;
    $CONFIG{titulo}      = $titulo      if defined $titulo;
    $CONFIG{url}         = $url         if defined $url;
    $CONFIG{excluir}     = $excluir_val if defined $excluir_val;
    $CONFIG{exato}       = $exato_flag  if defined $exato_flag;
    $CONFIG{motor}       = $motor        if defined $motor;
    $CONFIG{operador}    = $operador     if defined $operador;
    $CONFIG{intervalo}   = $data        if defined $data;
    $CONFIG{intensidade} = $intens      if defined $intens;
    $CONFIG{limite}      = $limite      if defined $limite;
    $CONFIG{salvar}      = $salvar      if defined $salvar;
    $CONFIG{abrir}       = $abrir       if defined $abrir;
    $CONFIG{verbose}     = $verbose;
    $CONFIG{interativo}  = $interativo;
    $CONFIG{extrair_urls}= $extrair;

    my @motores_validos = qw(google bing duckduckgo yandex startpage all);
    $CONFIG{motor} ||= 'google';
    unless (grep { $_ eq $CONFIG{motor} } @motores_validos) {
        die "${C_RED}❌ Motor inválido: $CONFIG{motor}. Use: @motores_validos${C_RESET}\n";
    }

    $CONFIG{operador} ||= 'AND';
    unless ($CONFIG{operador} =~ /^(AND|OR|-)$/i) {
        die "${C_RED}❌ Operador inválido. Use AND, OR ou -${C_RESET}\n";
    }

    $CONFIG{intensidade} ||= 1;
    $CONFIG{intensidade} = 1 if $CONFIG{intensidade} < 1;
    $CONFIG{intensidade} = 3 if $CONFIG{intensidade} > 3;

    $CONFIG{formato} = $formato if defined $formato;
    $CONFIG{formato} ||= 'txt';
    unless ($CONFIG{formato} =~ /^(txt|html|json|csv|md)$/i) {
        die "${C_RED}❌ Formato inválido. Use: txt, html, json, csv, md${C_RESET}\n";
    }
    $CONFIG{formato} = lc($CONFIG{formato});

    if ($categoria) {
        my $cat = lc($categoria);
        unless (exists $CATEGORIAS{$cat}) {
            die "${C_RED}❌ Categoria '$cat' não encontrada. Disponíveis: " .
                join(", ", sort keys %CATEGORIAS) . "${C_RESET}\n";
        }
        $CONFIG{categorias} = $cat;
        $CONFIG{termo} ||= $cat;
    }
}

# ────────────────────────────────────────────────────────────────
#            G E R A D O R   D E   D O R K S
# ────────────────────────────────────────────────────────────────
sub gerar_dorks {
    my @dorks;
    my $termo = $CONFIG{termo} || '';
    my $site  = $CONFIG{site};

    if ($CONFIG{categorias}) {
        @dorks = @{$CATEGORIAS{$CONFIG{categorias}}};

        if ($site) {
            for (my $i = 0; $i < @dorks; $i++) {
                $dorks[$i] .= " site:$site";
            }
        }

        if ($termo && $termo ne $CONFIG{categorias}) {
            for (my $i = 0; $i < @dorks; $i++) {
                $dorks[$i] = "$termo $dorks[$i]";
            }
        }

    } else {
        my $dork = $termo;

        $dork = "\"$dork\"" if $CONFIG{exato} && $dork !~ /^"/;

        $dork .= " site:$site"             if $site;
        $dork .= " filetype:$CONFIG{arquivo}" if $CONFIG{arquivo};
        $dork .= " intitle:$CONFIG{titulo}"   if $CONFIG{titulo};
        $dork .= " inurl:$CONFIG{url}"        if $CONFIG{url};

        if ($CONFIG{excluir}) {
            my @excluir = split(/[,\s]+/, $CONFIG{excluir});
            for my $ex (@excluir) {
                $dork .= " -$ex";
            }
        }

        push @dorks, $dork;

        if ($CONFIG{intensidade} >= 2 && $termo) {
            my $dork2 = $termo;
            $dork2 = "\"$dork2\"" if $CONFIG{exato};
            $dork2 .= " intitle:$termo" if $CONFIG{titulo};
            $dork2 .= " site:$site" if $site;
            push @dorks, $dork2 if $dork2 ne $dork;
        }

        if ($CONFIG{intensidade} >= 3 && $termo) {
            my @extras = (
                "inurl:$termo" . ($site ? " site:$site" : ""),
                "intitle:\"$termo\"" . ($site ? " site:$site" : ""),
                "site:$site \"$termo\" filetype:$CONFIG{arquivo}" . ($CONFIG{arquivo} ? "" : " pdf"),
            );
            for my $ex (@extras) {
                push @dorks, $ex unless grep { $_ eq $ex } @dorks;
            }
        }
    }

    my %seen;
    @dorks = grep { !$seen{$_}++ } @dorks;

    if ($CONFIG{limite} > 0 && scalar @dorks > $CONFIG{limite}) {
        @dorks = @dorks[0 .. $CONFIG{limite}-1];
    }

    @dorks = shuffle @dorks if $CONFIG{intensidade} >= 2;

    return @dorks;
}

# ────────────────────────────────────────────────────────────────
#              U R I   E S C A P E
# ────────────────────────────────────────────────────────────────
sub construir_url_motor {
    my ($dork, $motor) = @_;
    my $q = uri_escape($dork);

    my %urls = (
        google     => "https://www.google.com/search?q=$q",
        bing       => "https://www.bing.com/search?q=$q",
        duckduckgo => "https://duckduckgo.com/?q=$q",
        yandex     => "https://yandex.com/search/?text=$q",
        startpage  => "https://www.startpage.com/do/dsearch?query=$q",
    );

    return $urls{$motor} || $urls{google};
}

# ────────────────────────────────────────────────────────────────
#                  E X I B I Ç Ã O   N A   T E L A
# ────────────────────────────────────────────────────────────────
sub exibir_dorks {
    my ($dorks_ref, $motores_ref) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;

    print "\n";
    print "${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}\n";
    printf "${C_CYAN}║${C_WHITE} %-66s ${C_CYAN}║${C_RESET}\n",
        "🔍 DORKS GERADOS: " . scalar(@dorks) . " | MOTOR: " . uc($motores[0]) . " | INTENSIDADE: $CONFIG{intensidade}";
    print "${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n";

    my $count = 1;
    for my $dork (@dorks) {
        my $color = ($count % 2 == 0) ? $C_CYAN : $C_WHITE;
        print "${C_YELLOW}[$count]${C_RESET} $color🔎$C_RESET ${C_GREEN}$dork${C_RESET}\n";

        for my $motor (@motores) {
            my $url = construir_url_motor($dork, $motor);
            my $motor_label = ucfirst($motor);
            printf "  ${C_BLUE}➡ $motor_label:${C_RESET} %s\n", $url;
        }
        print "\n";
        $count++;
    }
}

# ────────────────────────────────────────────────────────────────
#           E X P O R T A Ç Ã O   D O S   R E S U L T A D O S
# ────────────────────────────────────────────────────────────────
sub exportar_resultados {
    my ($dorks_ref, $motores_ref, $filename) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;
    my $formato = $CONFIG{formato};

    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);

    if ($formato eq 'txt') {
        exportar_txt(\@dorks, \@motores, $filename, $timestamp);
    } elsif ($formato eq 'html') {
        exportar_html(\@dorks, \@motores, $filename, $timestamp);
    } elsif ($formato eq 'json') {
        exportar_json(\@dorks, \@motores, $filename, $timestamp);
    } elsif ($formato eq 'csv') {
        exportar_csv(\@dorks, \@motores, $filename, $timestamp);
    } elsif ($formato eq 'md') {
        exportar_md(\@dorks, \@motores, $filename, $timestamp);
    }

    print "${C_GREEN}✅ Resultados exportados para: ${C_WHITE}$filename${C_RESET}\n\n";
}

sub exportar_txt {
    my ($dorks_ref, $motores_ref, $file, $ts) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;

    open my $fh, '>', $file or die "${C_RED}❌ Erro ao escrever $file: $!${C_RESET}\n";

    print $fh "=" x 70 . "\n";
    print $fh "FYDELISDORK v3.0 PRO - Relatório de Dorks\n";
    print $fh "FydelisTechos © 2026\n";
    print $fh "Gerado em: $ts\n";
    print $fh "Motores: " . join(", ", map { ucfirst } @motores) . "\n";
    print $fh "Intensidade: $CONFIG{intensidade}\n";
    print $fh "=" x 70 . "\n\n";

    my $count = 1;
    for my $dork (@dorks) {
        print $fh "[$count] $dork\n";
        for my $motor (@motores) {
            my $url = construir_url_motor($dork, $motor);
            printf $fh "  -> %s: %s\n", ucfirst($motor), $url;
        }
        print $fh "\n";
        $count++;
    }

    print $fh "=" x 70 . "\n";
    print $fh "Total de dorks gerados: " . scalar(@dorks) . "\n";
    print $fh "=" x 70 . "\n";
    close $fh;
}

sub exportar_html {
    my ($dorks_ref, $motores_ref, $file, $ts) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;

    open my $fh, '>', $file or die "${C_RED}❌ Erro ao escrever $file: $!${C_RESET}\n";

    my $motores_str = join(", ", map { ucfirst } @motores);

    print $fh <<"HTML";
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FydelisDork v3.0 - Relatório de Dorks</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #0d1117;
            color: #c9d1d9;
            padding: 30px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            background: linear-gradient(135deg, #1a1a2e, #16213e);
            padding: 25px 30px;
            border-radius: 12px;
            border: 1px solid #30363d;
            margin-bottom: 30px;
        }
        .header h1 { color: #58a6ff; font-size: 28px; }
        .header p { color: #8b949e; margin-top: 8px; font-size: 14px; }
        .header .meta { margin-top: 12px; font-size: 13px; color: #6e7681; }
        .dork-card {
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 18px 22px;
            margin-bottom: 15px;
            transition: border-color 0.2s;
        }
        .dork-card:hover { border-color: #58a6ff; }
        .dork-number {
            display: inline-block;
            background: #1f6feb;
            color: #fff;
            font-weight: bold;
            padding: 2px 10px;
            border-radius: 12px;
            font-size: 12px;
            margin-right: 10px;
        }
        .dork-query {
            color: #7ee787;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            word-break: break-all;
        }
        .dork-links { margin-top: 10px; }
        .dork-links a {
            display: inline-block;
            background: #21262d;
            color: #58a6ff;
            text-decoration: none;
            padding: 4px 12px;
            border-radius: 6px;
            font-size: 12px;
            margin-right: 8px;
            margin-bottom: 5px;
            border: 1px solid #30363d;
            transition: background 0.2s;
        }
        .dork-links a:hover { background: #1f6feb; color: #fff; }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #6e7681;
            font-size: 13px;
            border-top: 1px solid #30363d;
        }
        .stats {
            display: flex;
            gap: 15px;
            margin-top: 15px;
        }
        .stat-box {
            background: #21262d;
            padding: 10px 18px;
            border-radius: 8px;
            border: 1px solid #30363d;
            text-align: center;
        }
        .stat-box .num { color: #58a6ff; font-size: 20px; font-weight: bold; }
        .stat-box .label { color: #8b949e; font-size: 11px; margin-top: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 FydelisDork v3.0 PRO</h1>
            <p>Relatório de Google Dorks & OSINT</p>
            <div class="meta">
                📅 Gerado em: $ts |
                🌐 Motores: $motores_str |
                ⚡ Intensidade: $CONFIG{intensidade}
            </div>
            <div class="stats">
                <div class="stat-box">
                    <div class="num">@{[scalar @dorks]}</div>
                    <div class="label">Dorks Gerados</div>
                </div>
                <div class="stat-box">
                    <div class="num">@{[scalar @motores]}</div>
                    <div class="label">Motores</div>
                </div>
            </div>
        </div>
HTML

    my $count = 1;
    for my $dork (@dorks) {
        print $fh qq{        <div class="dork-card">\n};
        print $fh qq{            <span class="dork-number">#$count</span>\n};
        print $fh qq{            <span class="dork-query">$dork</span>\n};
        print $fh qq{            <div class="dork-links">\n};

        for my $motor (@motores) {
            my $url = construir_url_motor($dork, $motor);
            my $label = ucfirst($motor);
            print $fh qq{                <a href="$url" target="_blank" rel="noopener">🌐 $label</a>\n};
        }

        print $fh qq{            </div>\n};
        print $fh qq{        </div>\n};
        $count++;
    }

    print $fh <<"HTML";
        <div class="footer">
            FydelisDork v3.0 PRO &bull; FydelisTechos &copy; 2026 &bull;
            Uso exclusivo para estudo e pesquisa de dados públicos
        </div>
    </div>
</body>
</html>
HTML

    close $fh;
}

sub exportar_json {
    my ($dorks_ref, $motores_ref, $file, $ts) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;

    my @entries;
    my $count = 1;
    for my $dork (@dorks) {
        my %entry = (
            id   => $count,
            dork => $dork,
            urls => {},
        );
        for my $motor (@motores) {
            $entry{urls}{$motor} = construir_url_motor($dork, $motor);
        }
        push @entries, \%entry;
        $count++;
    }

    my %data = (
        tool        => "FydelisDork v3.0 PRO",
        author      => "FydelisTechos © 2026",
        timestamp   => $ts,
        motors      => [map { ucfirst } @motores],
        parameters  => {
            termo       => $CONFIG{termo} || 'N/A',
            site        => $CONFIG{site} || 'N/A',
            arquivo     => $CONFIG{arquivo} || 'N/A',
            titulo      => $CONFIG{titulo} || 'N/A',
            url         => $CONFIG{url} || 'N/A',
            intensidade => $CONFIG{intensidade},
            categoria   => $CONFIG{categorias} || 'N/A',
        },
        total_dorks => scalar(@dorks),
        dorks       => \@entries,
    );

    require JSON;
    my $json = JSON->new->pretty->canonical->encode(\%data);

    open my $fh, '>', $file or die "${C_RED}❌ Erro ao escrever $file: $!${C_RESET}\n";
    print $fh $json;
    close $fh;
}

sub exportar_csv {
    my ($dorks_ref, $motores_ref, $file, $ts) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;

    open my $fh, '>', $file or die "${C_RED}❌ Erro ao escrever $file: $!${C_RESET}\n";

    my @headers = ('#', 'dork');
    for my $motor (@motores) {
        push @headers, "url_$motor";
    }
    print $fh join(',', @headers) . "\n";

    my $count = 1;
    for my $dork (@dorks) {
        my @row = ($count, "\"$dork\"");
        for my $motor (@motores) {
            my $url = construir_url_motor($dork, $motor);
            push @row, "\"$url\"";
        }
        print $fh join(',', @row) . "\n";
        $count++;
    }

    close $fh;
}

sub exportar_md {
    my ($dorks_ref, $motores_ref, $file, $ts) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;

    open my $fh, '>', $file or die "${C_RED}❌ Erro ao escrever $file: $!${C_RESET}\n";

    print $fh "# 🔍 FydelisDork v3.0 PRO - Relatório de Dorks\n\n";
    print $fh "**Gerado em:** $ts  \n";
    print $fh "**Motores:** " . join(", ", map { ucfirst } @motores) . "  \n";
    print $fh "**Intensidade:** $CONFIG{intensidade}  \n\n";
    print $fh "---\n\n";

    my $count = 1;
    for my $dork (@dorks) {
        print $fh "### [$count] $dork\n\n";
        for my $motor (@motores) {
            my $url = construir_url_motor($dork, $motor);
            printf $fh "  - [%s](%s)\n", ucfirst($motor), $url;
        }
        print $fh "\n";
        $count++;
    }

    print $fh "---\n\n";
    print $fh "_FydelisDork v3.0 PRO | FydelisTechos © 2026_\n";
    print $fh "_Uso exclusivo para estudo e pesquisa de dados públicos_\n";

    close $fh;
}

# ────────────────────────────────────────────────────────────────
#                M O D O   I N T E R A T I V O
# ────────────────────────────────────────────────────────────────
sub modo_interativo {
    banner();
    print "\n${C_YELLOW}⚠  MODO INTERATIVO ATIVADO${C_RESET}\n";
    print "${C_CYAN}Preencha os campos abaixo. Deixe em branco para pular.${C_RESET}\n\n";

    print "${C_WHITE}🔍 Termo principal:${C_RESET} ";
    chomp(my $termo = <STDIN>);
    $CONFIG{termo} = $termo if $termo;

    print "${C_WHITE}🌐 Filtrar por site (ex: gov.br):${C_RESET} ";
    chomp(my $site = <STDIN>);
    $CONFIG{site} = $site if $site;

    print "${C_WHITE}📄 Tipo de arquivo (pdf, doc, xls, sql, php, zip):${C_RESET} ";
    chomp(my $arquivo = <STDIN>);
    $CONFIG{arquivo} = $arquivo if $arquivo;

    print "${C_WHITE}📝 Palavra no título:${C_RESET} ";
    chomp(my $titulo = <STDIN>);
    $CONFIG{titulo} = $titulo if $titulo;

    print "${C_WHITE}🔗 Palavra na URL:${C_RESET} ";
    chomp(my $url = <STDIN>);
    $CONFIG{url} = $url if $url;

    print "${C_WHITE}❌ Palavras a excluir (separadas por vírgula):${C_RESET} ";
    chomp(my $excluir = <STDIN>);
    $CONFIG{excluir} = $excluir if $excluir;

    print "\n${C_WHITE}Categorias disponíveis:${C_RESET}\n";
    for my $cat (sort keys %CATEGORIAS) {
        printf "  ${C_YELLOW}%s${C_RESET} - %s\n",
            sprintf("%-10s", $cat),
            (split("\n", $CATEGORIAS{$cat}[0] // ''))[0] // '';
    }
    print "${C_WHITE}Usar categoria (opcional):${C_RESET} ";
    chomp(my $categoria = <STDIN>);
    if ($categoria && exists $CATEGORIAS{lc($categoria)}) {
        $CONFIG{categorias} = lc($categoria);
    }

    print "\n${C_WHITE}🌐 Motor de busca (google | bing | duckduckgo | yandex | startpage | all) [google]:${C_RESET} ";
    chomp(my $motor = <STDIN>);
    $CONFIG{motor} = $motor if $motor;

    print "${C_WHITE}⚡ Intensidade (1=básica, 2=média, 3=agressiva) [1]:${C_RESET} ";
    chomp(my $intens = <STDIN>);
    $CONFIG{intensidade} = int($intens) if $intens =~ /^\d+$/;

    print "${C_WHITE}🔢 Limite de dorks (0=ilimitado):${C_RESET} ";
    chomp(my $limite = <STDIN>);
    $CONFIG{limite} = int($limite) if $limite =~ /^\d+$/;

    print "${C_WHITE}💾 Exportar para arquivo? (s/N):${C_RESET} ";
    chomp(my $exportar = <STDIN>);
    if ($exportar =~ /^s/im) {
        print "${C_WHITE}  Nome do arquivo:${C_RESET} ";
        chomp(my $exp_file = <STDIN>);
        $CONFIG{salvar} = $exp_file if $exp_file;

        print "${C_WHITE}  Formato (txt/html/json/csv/md) [txt]:${C_RESET} ";
        chomp(my $formato = <STDIN>);
        $CONFIG{formato} = $formato if $formato;
    }

    print "${C_WHITE}🌍 Abrir links no navegador? (s/N):${C_RESET} ";
    chomp(my $abrir = <STDIN>);
    $CONFIG{abrir} = 1 if $abrir =~ /^s/im;

    print "\n${C_GREEN}✅ Configuração concluída! Gerando dorks...${C_RESET}\n";
    sleep 1;
}

# ────────────────────────────────────────────────────────────────
#              A B R I R   N O   N A V E G A D O R
# ────────────────────────────────────────────────────────────────
sub abrir_navegador {
    my ($dorks_ref, $motores_ref) = @_;
    my @dorks   = @$dorks_ref;
    my @motores = @$motores_ref;

    print "\n${C_YELLOW}🌍 Abrindo links no navegador...${C_RESET}\n";

    for my $dork (@dorks) {
        for my $motor (@motores) {
            my $url = construir_url_motor($dork, $motor);
            if ($^O eq 'linux') {
                system("xdg-open '$url' &");
            } elsif ($^O eq 'MSWin32') {
                system("start $url");
            } elsif ($^O eq 'darwin') {
                system("open '$url'");
            }
            sleep 1;
        }
    }
}

# ════════════════════════════════════════════════════════════════
#                         M A I N
# ════════════════════════════════════════════════════════════════

# 1. Parse
parse_args(@ARGV);

# 2. Modo interativo
if ($CONFIG{interativo}) {
    modo_interativo();
}

# 3. Banner
banner();

# 4. Valida
unless ($CONFIG{termo} || $CONFIG{categorias}) {
    die "\n${C_RED}❌ Informe -t (termo) ou -c (categoria)! Use -H para ajuda.${C_RESET}\n\n";
}

# 5. Motores
my @motores;
if ($CONFIG{motor} eq 'all') {
    @motores = qw(google bing duckduckgo yandex startpage);
} else {
    @motores = ($CONFIG{motor});
}

# 6. Gera dorks
print "${C_YELLOW}🔍 Gerando dorks...${C_RESET}\n";
my @dorks = gerar_dorks();

unless (scalar @dorks) {
    die "\n${C_RED}❌ Nenhum dork gerado. Verifique os parâmetros.${C_RESET}\n\n";
}

sleep 1;

# 7. Exibe
exibir_dorks(\@dorks, \@motores);

# 8. Exporta
if ($CONFIG{salvar}) {
    my $filename = $CONFIG{salvar};
    $filename .= ".$CONFIG{formato}" unless $filename =~ /\.\w+$/;
    exportar_resultados(\@dorks, \@motores, $filename);
}

# 9. Abre navegador
if ($CONFIG{abrir}) {
    abrir_navegador(\@dorks, \@motores);
}

# 10. Resumo final
print "\n";
print "${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}\n";
print "${C_CYAN}║${C_WHITE}                           R E S U M O${C_CYAN}                                 ║${C_RESET}\n";
print "${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n";
printf "  ${C_WHITE}%-20s${C_RESET} ${C_GREEN}%s${C_RESET}\n", "🔍 Dorks gerados:", scalar(@dorks);
printf "  ${C_WHITE}%-20s${C_RESET} ${C_CYAN}%s${C_RESET}\n", "🌐 Motores:", join(", ", map { ucfirst } @motores);
printf "  ${C_WHITE}%-20s${C_RESET} ${C_YELLOW}%d${C_RESET}\n", "⚡ Intensidade:", $CONFIG{intensidade};
if ($CONFIG{salvar}) {
    printf "  ${C_WHITE}%-20s${C_RESET} ${C_GREEN}%s${C_RESET}\n", "💾 Exportado:", $CONFIG{salvar};
}

print "\n${C_GREEN}✅ FydelisDork finalizado com sucesso!${C_RESET}\n";
print "${C_YELLOW}⚠  Lembre-se: uso exclusivo para estudo e pesquisa de dados públicos.${C_RESET}\n";
print "=" x 70 . "\n";

exit 0;