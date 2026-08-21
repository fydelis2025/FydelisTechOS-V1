#!/usr/bin/perl
# ==============================================================
#          F Y D E L I S A U D I T   v 2 . 0   P R O
#                     FydelisTechos © 2026
#   Analisador Profissional de Segurança de Senhas & Hashes
#   Uso Exclusivo em Ambientes Autorizados
# ==============================================================
#
# Dependências opcionais:
#   - Digest::SHA / Digest::MD5 / Digest::NTLM (hash lookup)
#   - Term::ANSIColor (saída colorida)
#   - File::Slurp (leitura rápida de wordlists grandes)
#
# Compatibilidade: Linux/Unix/macOS com Perl 5.10+
#
# ==============================================================

use strict;
use warnings;
use v5.10.0;

# --- Módulos padrão ---
use Getopt::Long qw(:config no_ignore_case bundling);
use POSIX qw(strftime floor);
use File::Spec;
use English qw(-no_match_vars);
use List::Util qw(sum max);
use Fcntl qw(:flock);

# --- Tenta carregar módulos opcionais ---
my $HAS_COLOR   = eval { require Term::ANSIColor; 1 };
my $HAS_FLOAT   = eval { require Math::BigFloat; 1 };
my $HAS_DIGEST  = 0;

# --- Constantes ---
use constant {
    VERSION        => '2.0',
    AUTHOR         => 'FydelisTechos',
    YEAR           => '2026',
    TOOL_NAME      => 'FydelisAudit',
    MIN_ENTROPY    => 60,          # bits — mínimo recomendado NIST
    RECOMEND_SIZE  => 12,          # caracteres mínimo OWASP 2023
    KEYBOARD_ROWS  => ['qwertyuiop', 'asdfghjkl', 'zxcvbnm',
                       'QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM',
                       '1234567890', 'qwertzuiop', 'azertyuiop'],
    COMMON_PATTERNS => [
        qr/^19\d{2}$|^20[012]\d$/,            # anos 1900-2029
        qr/\d{2}\/\d{2}\/\d{4}/,              # datas formato br
        qr/(\d)\1{3,}/,                        # dígitos repetidos
        qr/([a-zA-Z])\1{3,}/,                  # letras repetidas
        qr/(?:abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)/i, # sequências alfabéticas
    ],
    CRACKTIME_2024 => {
        # Estimativas de tempo de cracking (2024, GPU NVIDIA RTX 4090)
        # Baseado em benchmarks de hashcat
        '7'  => 'instantâneo',       # < 1s
        '8'  => 'segundos',
        '10' => 'minutos',
        '12' => 'horas',
        '14' => 'dias',
        '16' => 'meses',
        '18' => 'anos',
        '20' => 'décadas',
        '24' => 'séculos',
        '28' => 'milênios',
    },
};

# --- Variáveis globais ---
my ($arquivo_senhas, $saida, $wordlist, $verbose, $cores, $json, $csv);
my ($ajuda, $versao, $check_hash, $min_length, $max_length, $top, $quieto);
my ($nocolor, $relatorio_completo, $benchmark);
my $stats = {
    total       => 0,
    criticas    => 0,
    fracas      => 0,
    medias      => 0,
    fortes      => 0,
    total_ent   => 0,
    comprimentos => [],
    chars_unicos => 0,
};

# ======================================================================
#                        SUB-ROTINAS PRINCIPAIS
# ======================================================================

sub colorir {
    my ($cor, $texto) = @_;
    return $texto unless $cores && $HAS_COLOR;
    return Term::ANSIColor::colored($texto, $cor);
}

sub mostra_ajuda {
    print <<"AJUDA";
======================================================================
    ${\(TOOL_NAME)} v@{[VERSION]} — ${\(AUTHOR)} © ${\(YEAR)}
         Analisador Profissional de Segurança de Senhas
======================================================================

  📌 USO: $0 -l ARQUIVO_SENHAS [OPÇÕES]

  ═══════════════════════════════════════════════════════════════════
   OBRIGATÓRIO
  ═══════════════════════════════════════════════════════════════════
   -l, --lista ARQUIVO      Arquivo com senhas (uma por linha)

  ═══════════════════════════════════════════════════════════════════
   WORDLIST / DICIONÁRIO
  ═══════════════════════════════════════════════════════════════════
   -w, --wordlist ARQUIVO   Arquivo de wordlist para marcar senhas
                            conhecidas/exfiltradas (ex: rockyou.txt)

  ═══════════════════════════════════════════════════════════════════
   FILTROS
  ═══════════════════════════════════════════════════════════════════
       --min-length N       Ignorar senhas com menos de N caracteres
       --max-length N       Ignorar senhas com mais de N caracteres
       --top N              Mostrar apenas as N piores senhas

  ═══════════════════════════════════════════════════════════════════
   SAÍDA
  ═══════════════════════════════════════════════════════════════════
   -o, --salvar ARQUIVO    Salvar relatório completo
       --json ARQUIVO       Exportar resultados em JSON
       --csv ARQUIVO        Exportar resultados em CSV
   -q, --quieto             Modo silencioso (apenas resumo)
       --no-color           Desativar cores (útil para pipes)
       --full               Relatório completo (todas as senhas)

  ═══════════════════════════════════════════════════════════════════
   COMPORTAMENTO
  ═══════════════════════════════════════════════════════════════════
   -v, --verbose            Aumenta verbosidade
   -b, --benchmark          Modo benchmark (mostra estatísticas de
                            desempenho)
   -H, --ajuda              Mostra esta mensagem e sai
   -V, --versao             Exibe versão e sai

  ═══════════════════════════════════════════════════════════════════
   EXEMPLOS
  ═══════════════════════════════════════════════════════════════════
   # Análise básica
   $0 -l senhas.txt

   # Análise completa com wordlist rockyou
   $0 -l senhas.txt -w /usr/share/wordlists/rockyou.txt -o relatorio.txt

   # Exportar JSON para integração
   $0 -l senhas.txt --json resultados.json --full

   # Apenas as 20 piores senhas
   $0 -l senhas.txt --top 20 --full

   # Benchmark com wordlist grande
   $0 -l milhao_senhas.txt -w rockyou.txt -b -q --csv dados.csv

======================================================================
AJUDA
    exit 0;
}

sub mostra_versao {
    say TOOL_NAME . " v" . VERSION . " | " . AUTHOR . " © " . YEAR;
    printf "Perl v%vd | %s\n", $^V, $^O;
    say "Módulos: " . join(', ',
        ($HAS_COLOR  ? 'Term::ANSIColor' : ()),
        ($HAS_FLOAT  ? 'Math::BigFloat'  : ()),
    ) || '(todos nativos)';
    exit 0;
}

sub log_msg {
    my ($nivel, $msg) = @_;
    return if $quieto && $nivel eq 'info';
    return if $verbose < 1 && $nivel eq 'debug';

    my $timestamp = strftime('%H:%M:%S', localtime);
    my $nivel_str = uc(substr($nivel, 0, 4));
    my $saida = sprintf("[%s] [%s] %s", $timestamp, $nivel_str, $msg);

    say $saida;
}

# ======================================================================
#                    ENTROPIA E ANÁLISE TÉCNICA
# ======================================================================

sub calcular_entropia_shannon {
    my $senha = shift;
    return 0 unless length $senha;

    my %freq;
    $freq{$_}++ for split //, $senha;
    my $len = length $senha;
    my $entropia = 0;

    for my $count (values %freq) {
        my $p = $count / $len;
        $entropia -= $p * log($p) / log(2);
    }

    return $entropia * $len;  # entropia total em bits
}

sub calcular_entropia_nist {
    my $senha = shift;
    my $len = length $senha;
    return 0 unless $len;

    # Algoritmo NIST SP 800-63B simplificado:
    # Primeiros 8 chars: 2 bits cada
    # Chars 9+: 1.5 bits cada
    # Bônus: +6 bits para maiúscula, +6 para minúscula, +6 para número, +6 para especial
    my $ent = 0;
    if ($len <= 8) {
        $ent = $len * 2;
    } else {
        $ent = 8 * 2 + ($len - 8) * 1.5;
    }

    $ent += 6 if $senha =~ /[A-Z]/;
    $ent += 6 if $senha =~ /[a-z]/;
    $ent += 6 if $senha =~ /[0-9]/;
    $ent += 6 if $senha =~ /[^A-Za-z0-9]/;

    # Penalidade para repetições
    my $reps = 0;
    $reps++ while $senha =~ /(.)\1/g;
    $ent -= $reps * 2 if $reps > 0;

    return $ent < 0 ? 0 : $ent;
}

sub detectar_padrao_teclado {
    my $senha = shift;
    my $lower = lc($senha);

    for my $row (KEYBOARD_ROWS) {
        my $len = length($row);
        for my $start (0 .. $len - 3) {
            my $seq = substr($row, $start, 4);  # 4 chars consecutivos
            return "sequência de teclado ($seq)" if index($lower, $seq) >= 0;
        }
        # Sequências reversas
        my $rev = reverse($row);
        for my $start (0 .. length($rev) - 3) {
            my $seq = substr($rev, $start, 4);
            return "sequência de teclado reversa ($seq)" if index($lower, $seq) >= 0;
        }
    }

    return undef;
}

sub detectar_padrao_comum {
    my $senha = shift;

    # Padrões de data
    if ($senha =~ /^(?:19|20)\d{2}$/) {
        return "ano isolado";
    }
    if ($senha =~ /^(?:0?[1-9]|[12]\d|3[01])(?:0?[1-9]|1[0-2])\d{4}$/) {
        return "data (DDMMYYYY)";
    }
    if ($senha =~ /^(?:0?[1-9]|1[0-2])(?:0?[1-9]|[12]\d|3[01])\d{4}$/) {
        return "data (MMDDYYYY)";
    }

    # Repetições
    if ($senha =~ /^(.)\1{3,}$/) {
        return "caractere repetido (" . (length $senha) . "x '$1')";
    }
    if ($senha =~ /^(\d{2,3})\1+$/) {
        return "padrão de dígitos repetidos";
    }

    # Sequências numéricas
    if ($senha =~ /^12345|^54321|^qwerty|^asdfgh|^zxcvbn/i) {
        return "sequência previsível padrão";
    }

    # Palavras comuns em senhas
    if ($senha =~ /^(?:senha|password|admin|root|user|login|master|default|12345)/i) {
        my $palavra = lc($1 // $senha);
        return "palavra comum: '$palavra'";
    }

    return undef;
}

sub verificar_wordlist {
    my ($senha, $wl_ref) = @_;
    return 0 unless $wl_ref && ref $wl_ref eq 'HASH';
    return exists $wl_ref->{lc($senha)} ? 1 : 0;
}

sub classificar_senha {
    my ($senha, $wl_ref) = @_;

    my $len = length $senha;
    my $resultado = {
        senha       => $senha,
        tamanho     => $len,
        ent_shannon => 0,
        ent_nist    => 0,
        score       => 0,
        nivel       => 'CRÍTICA',
        status      => '❌❌❌',
        cor         => 'bold red',
        em_wordlist => 0,
        padrao      => undef,
        teclado     => undef,
        tempo_quebra => 'instantâneo',
        detalhes    => [],
    };

    # --- Entropia ---
    $resultado->{ent_shannon} = calcular_entropia_shannon($senha);
    $resultado->{ent_nist}    = calcular_entropia_nist($senha);

    # --- Verificação de wordlist (case insensitive) ---
    if ($wl_ref && verificar_wordlist($senha, $wl_ref)) {
        $resultado->{em_wordlist} = 1;
        push @{$resultado->{detalhes}}, "senha presente em wordlist conhecida";
    }

    # --- Detecção de padrões ---
    $resultado->{teclado} = detectar_padrao_teclado($senha);
    push @{$resultado->{detalhes}}, $resultado->{teclado} if $resultado->{teclado};

    $resultado->{padrao} = detectar_padrao_comum($senha);
    push @{$resultado->{detalhes}}, $resultado->{padrao} if $resultado->{padrao};

    # --- Scoring (0-100) ---
    my $score = 0;

    # Comprimento (até 40 pts)
    if ($len >= 16)      { $score += 40; }
    elsif ($len >= 12)   { $score += 35; }
    elsif ($len >= 10)   { $score += 25; }
    elsif ($len >= 8)    { $score += 15; }
    elsif ($len >= 6)    { $score += 5; }

    # Diversidade de caracteres (até 30 pts)
    my $tem_maiuscula  = $senha =~ /[A-Z]/ ? 1 : 0;
    my $tem_minuscula  = $senha =~ /[a-z]/ ? 1 : 0;
    my $tem_numero     = $senha =~ /[0-9]/ ? 1 : 0;
    my $tem_especial   = $senha =~ /[^A-Za-z0-9\s]/ ? 1 : 0;

    $score += 7.5 * $tem_maiuscula;
    $score += 7.5 * $tem_minuscula;
    $score += 7.5 * $tem_numero;
    $score += 7.5 * $tem_especial;

    # Entropia (até 20 pts)
    if ($resultado->{ent_shannon} >= 60)      { $score += 20; }
    elsif ($resultado->{ent_shannon} >= 40)   { $score += 15; }
    elsif ($resultado->{ent_shannon} >= 20)   { $score += 8; }

    # Penalidades
    $score -= 20 if $resultado->{em_wordlist};
    $score -= 10 if $resultado->{teclado};
    $score -= 15 if $resultado->{padrao};

    $score = 0   if $score < 0;
    $score = 100 if $score > 100;
    $resultado->{score} = $score;

    # --- Classificação ---
    if ($score <= 20 || $resultado->{em_wordlist}) {
        $resultado->{nivel}  = 'CRÍTICA';
        $resultado->{status} = '❌❌❌';
        $resultado->{cor}    = 'bold red';
    }
    elsif ($score <= 40) {
        $resultado->{nivel}  = 'FRACA';
        $resultado->{status} = '❌❌';
        $resultado->{cor}    = 'red';
    }
    elsif ($score <= 60) {
        $resultado->{nivel}  = 'MÉDIA';
        $resultado->{status} = '⚠️⚠️';
        $resultado->{cor}    = 'yellow';
    }
    elsif ($score <= 80) {
        $resultado->{nivel}  = 'FORTE';
        $resultado->{status} = '✅✅';
        $resultado->{cor}    = 'green';
    }
    else {
        $resultado->{nivel}  = 'EXCELENTE';
        $resultado->{status} = '✅✅✅';
        $resultado->{cor}    = 'bold cyan';
    }

    # --- Tempo estimado de quebra (baseado em entropia NIST) ---
    my $ent = $resultado->{ent_nist};
    my $tempo = 'instantâneo';
    if    ($ent >= 28) { $tempo = 'milênios'; }
    elsif ($ent >= 24) { $tempo = 'séculos'; }
    elsif ($ent >= 20) { $tempo = 'décadas'; }
    elsif ($ent >= 18) { $tempo = 'anos'; }
    elsif ($ent >= 16) { $tempo = 'meses'; }
    elsif ($ent >= 14) { $tempo = 'dias'; }
    elsif ($ent >= 12) { $tempo = 'horas'; }
    elsif ($ent >= 10) { $tempo = 'minutos'; }
    elsif ($ent >= 8)  { $tempo = 'segundos'; }

    $resultado->{tempo_quebra} = $tempo;

    return $resultado;
}

# ======================================================================
#                    CARREGAMENTO DE WORDLIST
# ======================================================================

sub carregar_wordlist {
    my $arquivo = shift;
    return undef unless $arquivo && -f $arquivo;

    log_msg('info', "Carregando wordlist: $arquivo...");

    my $tamanho = (stat($arquivo))[7];
    log_msg('debug', sprintf("Tamanho do arquivo: %.2f MB", $tamanho / (1024*1024)));

    my %wordlist;
    my $count = 0;
    my $tempo_inicio = time();

    open(my $wl, '<', $arquivo) or do {
        log_msg('erro', "Não foi possível abrir $arquivo: $!");
        return undef;
    };

    while (my $linha = <$wl>) {
        chomp $linha;
        next unless length $linha > 0;
        $wordlist{lc($linha)} = 1;
        $count++;

        # Progresso a cada 1M de linhas
        if ($verbose && $count % 1_000_000 == 0) {
            my $elapsed = time() - $tempo_inicio;
            log_msg('debug', "  ... $count linhas carregadas (${elapsed}s)");
        }
    }

    close $wl;

    my $elapsed = time() - $tempo_inicio;
    log_msg('info', sprintf("Wordlist carregada: %d senhas únicas em %ds", $count, $elapsed));
    log_msg('info', sprintf("  Memória aproximada: %.1f MB", $count * 50 / (1024*1024)));

    return \%wordlist;
}

# ======================================================================
#                    GERAÇÃO DE RELATÓRIOS
# ======================================================================

sub gerar_relatorio_texto {
    my ($resultados, $wl_ref) = @_;
    my @linhas;

    push @linhas, '=' x 72;
    push @linhas, sprintf "  %s v%s  —  %s © %s", TOOL_NAME, VERSION, AUTHOR, YEAR;
    push @linhas, sprintf "  Relatório de Auditoria de Senhas";
    push @linhas, sprintf "  Data: %s", strftime('%d/%m/%Y às %H:%M:%S', localtime);
    push @linhas, '=' x 72;
    push @linhas, '';

    # Parâmetros
    push @linhas, "  ┌─ Parâmetros da análise";
    push @linhas, "  ├ Arquivo     : $arquivo_senhas";
    push @linhas, "  ├ Wordlist    : " . ($wordlist || '(nenhuma)');
    push @linhas, "  ├ Método      : Entropia NIST SP 800-63B + Shannon";
    push @linhas, "  └ Scoring     : 0-100 (comprimento, diversidade, padrões)";
    push @linhas, '';

    # Resumo
    push @linhas, "  ┌─ RESUMO DA ANÁLISE";
    push @linhas, sprintf "  ├ Total de senhas : %d", $stats->{total};
    push @linhas, sprintf "  ├ Críticas        : %d (%s%%)",
        $stats->{criticas}, $stats->{total} ? sprintf('%.1f', 100 * $stats->{criticas} / $stats->{total}) : 0;
    push @linhas, sprintf "  ├ Fracas          : %d (%s%%)",
        $stats->{fracas}, $stats->{total} ? sprintf('%.1f', 100 * $stats->{fracas} / $stats->{total}) : 0;
    push @linhas, sprintf "  ├ Médias          : %d (%s%%)",
        $stats->{medias}, $stats->{total} ? sprintf('%.1f', 100 * $stats->{medias} / $stats->{total}) : 0;
    push @linhas, sprintf "  ├ Fortes          : %d (%s%%)",
        $stats->{fortes}, $stats->{total} ? sprintf('%.1f', 100 * $stats->{fortes} / $stats->{total}) : 0;
    push @linhas, sprintf "  ├ Excelentes      : %d (%s%%)",
        $stats->{excelentes}, $stats->{total} ? sprintf('%.1f', 100 * $stats->{excelentes} / $stats->{total}) : 0;

    if (@{$stats->{comprimentos}}) {
        my $med = sum(@{$stats->{comprimentos}}) / @{$stats->{comprimentos}};
        push @linhas, sprintf "  ├ Comprimento médio: %.1f caracteres", $med;
        push @linhas, sprintf "  ├ Maior senha     : %d caracteres", max(@{$stats->{comprimentos}});
        push @linhas, sprintf "  └ Menor senha     : %d caracteres", (sort { $a <=> $b } @{$stats->{comprimentos}})[0];
    }
    push @linhas, '';

    # Barra de distribuição
    push @linhas, "  ┌─ DISTRIBUIÇÃO";
    my $max_bar = 40;
    for my $label (['Críticas'   , $stats->{criticas}],
                   ['Fracas'     , $stats->{fracas}],
                   ['Médias'     , $stats->{medias}],
                   ['Fortes'     , $stats->{fortes}],
                   ['Excelentes' , $stats->{excelentes}]) {
        my ($nome, $valor) = @$label;
        next unless $stats->{total} > 0;
        my $pct = 100 * $valor / $stats->{total};
        my $bar = '█' x int($max_bar * $pct / 100);
        push @linhas, sprintf "  ├ %-12s %4d (%5.1f%%) %s", $nome, $valor, $pct, $bar;
    }
    push @linhas, '';

    # Lista detalhada (apenas se --full ou --top)
    my @exibir = @$resultados;

    if ($top && $top > 0) {
        @exibir = sort { $a->{score} <=> $b->{score} } @exibir;
        @exibir = splice(@exibir, 0, $top);
        push @linhas, "  ┌─ TOP $top PIORES SENHAS";
    }
    elsif ($relatorio_completo) {
        push @linhas, "  ┌─ ANÁLISE DETALHADA (${\(scalar @exibir)} senhas)";
    }
    else {
        # Sem --full, mostra apenas as piores (score < 40)
        @exibir = grep { $_->{score} < 40 } @$resultados;
        if (@exibir) {
            push @linhas, "  ┌─ SENHAS CRÍTICAS/FRACAS (${\(scalar @exibir)} encontradas)";
        } else {
            push @linhas, "  ┌─ NENHUMA SENHA CRÍTICA OU FRACA ENCONTRADA ✅";
        }
    }

    push @linhas, '';

    for my $r (@exibir) {
        push @linhas, sprintf "  ├─ [%s] %s", $r->{nivel}, $r->{senha};
        push @linhas, sprintf "  │   Score: %d/100 | Entropia: %.1f bits (Shannon) / %.1f bits (NIST)",
            $r->{score}, $r->{ent_shannon}, $r->{ent_nist};
        push @linhas, sprintf "  │   Tamanho: %d chars | Tempo estimado: %s",
            $r->{tamanho}, $r->{tempo_quebra};

        if ($r->{em_wordlist}) {
            push @linhas, "  │   ⚠ SENHA ENCONTRADA EM WORDLIST PÚBLICA";
        }
        for my $d (@{$r->{detalhes}}) {
            push @linhas, "  │   ⚠ $d";
        }
        push @linhas, '  │';
    }

    # Recomendações
    push @linhas, '  ┌─ RECOMENDAÇÕES';
    push @linhas, '  ├ 1. Senhas devem ter no mínimo 12 caracteres (OWASP 2023)';
    push @linhas, '  ├ 2. Usar combinação de maiúsculas, minúsculas, números e símbolos';
    push @linhas, '  ├ 3. Evitar palavras de dicionário, datas, sequências de teclado';
    push @linhas, '  ├ 4. Senhas críticas/fracas devem ser trocadas imediatamente';
    push @linhas, '  ├ 5. Implementar MFA (autenticação multifator)';
    push @linhas, '  └ 6. Considerar uso de gerenciador de senhas corporativo';
    push @linhas, '';

    push @linhas, '=' x 72;
    push @linhas, "  FydelisAudit v" . VERSION . " — Relatório gerado automaticamente";
    push @linhas, '  Apenas para ambientes autorizados.';
    push @linhas, '=' x 72;
    push @linhas, '';

    return join("\n", @linhas);
}

sub gerar_json {
    my ($resultados) = @_;

    my @json_resultados;
    for my $r (@$resultados) {
        push @json_resultados, {
            senha            => $r->{senha},
            tamanho          => $r->{tamanho},
            entropia_shannon => sprintf('%.2f', $r->{ent_shannon}),
            entropia_nist    => sprintf('%.2f', $r->{ent_nist}),
            score            => $r->{score},
            nivel            => $r->{nivel},
            em_wordlist      => $r->{em_wordlist} ? JSON::true : JSON::false,
            padrao           => $r->{padrao} // JSON::null,
            teclado          => $r->{teclado} // JSON::null,
            tempo_quebra     => $r->{tempo_quebra},
        };
    }

    my $json = {
        ferramenta  => TOOL_NAME,
        versao      => VERSION,
        autor       => AUTHOR,
        data        => strftime('%Y-%m-%dT%H:%M:%S', localtime),
        arquivo     => $arquivo_senhas,
        wordlist    => $wordlist // JSON::null,
        estatisticas => {
            total       => $stats->{total},
            criticas    => $stats->{criticas},
            fracas      => $stats->{fracas},
            medias      => $stats->{medias},
            fortes      => $stats->{fortes},
            excelentes  => $stats->{excelentes},
            comp_medio  => @{$stats->{comprimentos}}
                ? sprintf('%.1f', sum(@{$stats->{comprimentos}}) / @{$stats->{comprimentos}})
                : 0,
        },
        resultados => \@json_resultados,
    };

    # JSON manual (sem dependência externa)
    return _encode_json($json);
}

sub _encode_json {
    my $data = shift;
    my $ref = ref $data;

    if ($ref eq 'HASH') {
        my @pares;
        for my $k (sort keys %$data) {
            my $v = _encode_json($data->{$k});
            push @pares, qq{"$k":$v};
        }
        return '{' . join(',', @pares) . '}';
    }
    elsif ($ref eq 'ARRAY') {
        my @vals = map { _encode_json($_) } @$data;
        return '[' . join(',', @vals) . ']';
    }
    elsif ($ref eq '') {
        if (!defined $data || $data eq 'JSON::null') {
            return 'null';
        }
        if ($data eq 'JSON::true')  { return 'true';  }
        if ($data eq 'JSON::false') { return 'false'; }
        if ($data =~ /^\d+(?:\.\d+)?$/) { return $data; }
        # Escapa caracteres especiais
        my $escaped = $data;
        $escaped =~ s/"/\\"/g;
        $escaped =~ s/\n/\\n/g;
        $escaped =~ s/\t/\\t/g;
        $escaped =~ s/\r/\\r/g;
        $escaped =~ s/\\/\\\\/g;
        return qq{"$escaped"};
    }
    return 'null';
}

sub gerar_csv {
    my ($resultados) = @_;

    my @linhas;
    push @linhas, 'senha,tamanho,entropia_shannon,entropia_nist,score,nivel,em_wordlist,padrao,teclado,tempo_quebra';

    for my $r (@$resultados) {
        my $senha_clean = $r->{senha};
        $senha_clean =~ s/"/""/g;  # CSV escape
        push @linhas, sprintf(qq{"%s",%d,%.2f,%.2f,%d,%s,%s,%s,%s,%s},
            $senha_clean,
            $r->{tamanho},
            $r->{ent_shannon},
            $r->{ent_nist},
            $r->{score},
            $r->{nivel},
            $r->{em_wordlist} ? 'SIM' : 'NÃO',
            $r->{padrao}  // '',
            $r->{teclado} // '',
            $r->{tempo_quebra},
        );
    }

    return join("\n", @linhas);
}

# ======================================================================
#                      VALIDAÇÕES E AMBIENTE
# ======================================================================

sub validar_ambiente {
    my $erros = 0;

    # Arquivo de senhas
    if (!$arquivo_senhas) {
        say "❌ Arquivo de senhas não especificado. Use -l ARQUIVO";
        $erros++;
    }
    elsif (!-f $arquivo_senhas) {
        say "❌ Arquivo '$arquivo_senhas' não encontrado.";
        $erros++;
    }
    elsif (!-r $arquivo_senhas) {
        say "❌ Arquivo '$arquivo_senhas' sem permissão de leitura.";
        $erros++;
    }

    # Wordlist (se especificada)
    if ($wordlist && !-f $wordlist) {
        say "❌ Wordlist '$wordlist' não encontrada.";
        $erros++;
    }

    if ($erros) {
        say "\n💡 Use -H para ajuda completa.";
        exit 1;
    }

    return 1;
}

# ======================================================================
#                         EXECUÇÃO PRINCIPAL
# ======================================================================

sub main {
    # --- Banner ---
    unless ($quieto) {
        say '';
        say '=' x 72;
        printf "  %s v%s  |  %s © %s\n", TOOL_NAME, VERSION, AUTHOR, YEAR;
        say '  Analisador Profissional de Segurança de Senhas';
        say '=' x 72;
        say '';
    }

    # --- Parse de argumentos ---
    GetOptions(
        'l|lista=s'          => \$arquivo_senhas,
        'o|salvar=s'         => \$saida,
        'w|wordlist=s'       => \$wordlist,
        'v|verbose+'         => \$verbose,
        'b|benchmark'        => \$benchmark,
        'q|quieto'           => \$quieto,
        'no-color'           => \$nocolor,
        'full'               => \$relatorio_completo,
        'json=s'             => \$json,
        'csv=s'              => \$csv,
        'top=i'              => \$top,
        'min-length=i'       => \$min_length,
        'max-length=i'       => \$max_length,
        'H|ajuda'            => \$ajuda,
        'V|versao'           => \$versao,
        'h|help'             => \$ajuda,
    ) or do {
        say "\n❌ Erro nos argumentos. Use -H para ajuda.\n";
        exit 1;
    };

    mostra_ajuda()   if $ajuda;
    mostra_versao()  if $versao;

    # Configurar cores
    $cores = !$nocolor && (-t STDOUT);

    # --- Validações ---
    validar_ambiente();

    # --- Carregar wordlist ---
    my $wl_ref;
    if ($wordlist) {
        my $t_inicio = time();
        $wl_ref = carregar_wordlist($wordlist);
        if ($benchmark) {
            log_msg('info', sprintf("⏱ Wordlist carregada em %ds", time() - $t_inicio));
        }
    }

    # --- Ler senhas ---
    log_msg('info', "Lendo senhas de: $arquivo_senhas...");
    my $t_inicio = time();

    open(my $fh, '<', $arquivo_senhas) or die "❌ Não foi possível abrir $arquivo_senhas: $!";
    my @senhas;
    while (my $linha = <$fh>) {
        chomp $linha;
        next unless length $linha > 0;
        next if $min_length && length($linha) < $min_length;
        next if $max_length && length($linha) > $max_length;
        push @senhas, $linha;
    }
    close $fh;

    log_msg('info', sprintf("Lidas %d senhas em %ds", scalar @senhas, time() - $t_inicio));
    log_msg('debug', "Iniciando análise...");

    # --- Analisar ---
    $stats->{total} = scalar @senhas;
    $stats->{excelentes} = 0;

    my @resultados;
    my $count = 0;

    for my $senha (@senhas) {
        my $r = classificar_senha($senha, $wl_ref);
        push @resultados, $r;

        # Estatísticas
        push @{$stats->{comprimentos}}, $r->{tamanho};

        if ($r->{nivel} eq 'CRÍTICA')    { $stats->{criticas}++; }
        elsif ($r->{nivel} eq 'FRACA')   { $stats->{fracas}++; }
        elsif ($r->{nivel} eq 'MÉDIA')   { $stats->{medias}++; }
        elsif ($r->{nivel} eq 'FORTE')   { $stats->{fortes}++; }
        elsif ($r->{nivel} eq 'EXCELENTE') { $stats->{excelentes}++; }

        $count++;
        if ($verbose && $count % 10_000 == 0) {
            log_msg('debug', sprintf("  ... %d senhas analisadas", $count));
        }
    }

    if ($benchmark) {
        log_msg('info', sprintf("⏱ Análise concluída em %ds (%.0f senhas/s)",
            time() - $t_inicio, $count / (time() - $t_inicio || 1)));
    }

    # --- Gerar relatórios ---
    my $relatorio_texto = gerar_relatorio_texto(\@resultados, $wl_ref);

    # Saída no terminal
    unless ($quieto) {
        print $relatorio_texto;
    }

    # Salvar relatório texto
    if ($saida) {
        open(my $out, '>', $saida) or die "❌ Não foi possível salvar $saida: $!";
        print $out $relatorio_texto;
        close $out;
        log_msg('info', "Relatório salvo em: $saida");
    }

    # Exportar JSON
    if ($json) {
        my $json_data = gerar_json(\@resultados);
        open(my $out, '>', $json) or die "❌ Não foi possível salvar $json: $!";
        print $out $json_data;
        close $out;
        log_msg('info', "JSON exportado para: $json");
    }

    # Exportar CSV
    if ($csv) {
        my $csv_data = gerar_csv(\@resultados);
        open(my $out, '>', $csv) or die "❌ Não foi possível salvar $csv: $!";
        print $out $csv_data;
        close $out;
        log_msg('info', "CSV exportado para: $csv");
    }

    # --- Resumo final ---
    unless ($quieto) {
        say '';
        say '=' x 72;
        printf "  ✅ Análise concluída: %d senhas | Críticas: %d | Fracas: %d | Médias: %d | Fortes: %d | Excelentes: %d\n",
            $stats->{total}, $stats->{criticas}, $stats->{fracas}, $stats->{medias}, $stats->{fortes}, $stats->{excelentes};
        say '=' x 72;
        say '';
    }
}

# --- Ponto de entrada ---
main();

__END__

=head1 NOME

FydelisAudit - Analisador Profissional de Segurança de Senhas

=head1 DESCRIÇÃO

Ferramenta avançada para auditoria de senhas com análise de entropia
(Shannon e NIST SP 800-63B), detecção de padrões previsíveis,
verificação contra wordlists públicas e classificação profissional.

=head1 CARACTERÍSTICAS

=over 4

=item * Entropia Shannon (teoria da informação)

=item * Entropia NIST SP 800-63B (recomendação governamental)

=item * Verificação contra wordlists (rockyou, common passwords)

=item * Detecção de padrões de teclado (QWERTY, ASDF, etc.)

=item * Detecção de padrões comuns (datas, anos, repetições)

=item * Tempo estimado de quebra (instantâneo a milênios)

=item * Score 0-100 com penalidades

=item * Exportação em TXT, JSON e CSV

=item * Benchmark de desempenho

=back

=head1 REQUISITOS

=over 4

=item * Perl 5.10+

=item * Opcional: Term::ANSIColor (cores no terminal)

=back

=head1 SEGURANÇA

Esta ferramenta deve ser usada exclusivamente em sistemas para os
quais você possui autorização explícita por escrito.

=head1 AUTOR

FydelisTechos © 2026

=cut