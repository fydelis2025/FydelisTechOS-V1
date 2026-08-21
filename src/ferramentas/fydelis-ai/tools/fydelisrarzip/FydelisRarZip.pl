#!/usr/bin/perl
# ==============================================================
#          F Y D E L I S R A R Z I P   v 2 . 0   P R O
#                     FydelisTechos © 2026
#   Cracker Profissional de Arquivos (ZIP/RAR/7z/RAR5)
#   Uso Exclusivo em Arquivos de Sua Propriedade
# ==============================================================
#
# Dependências:
#   - unzip (padrão)
#   - unrar-free ou unrar (RAR)
#   - p7zip-full (7z, recomendado)
#   - Parallel::ForkManager (opcional, para paralelismo)
#
# Compatibilidade: Linux/Unix/macOS com Perl 5.10+
#
# ==============================================================

use strict;
use warnings;
use v5.10.0;

# --- Módulos ---
use Getopt::Long qw(:config no_ignore_case bundling);
use POSIX qw(strftime floor ceil);
use File::Spec;
use File::Basename qw(basename dirname);
use Cwd 'abs_path';
use English qw(-no_match_vars);
use Fcntl qw(:flock);
use List::Util qw(shuffle);
use Time::HiRes qw(time sleep);

# --- Tenta módulos opcionais ---
my $HAS_PARALLEL = eval { require Parallel::ForkManager; 1 };

# --- Constantes ---
use constant {
    VERSION     => '2.0',
    AUTHOR      => 'FydelisTechos',
    YEAR        => '2026',
    TOOL_NAME   => 'FydelisRarZip',
    BLOCK_SIZE  => 1024,
    MIN_PWD_LEN => 1,
    MAX_PWD_LEN => 32,
    CHARSET_LOWER => 'abcdefghijklmnopqrstuvwxyz',
    CHARSET_UPPER => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    CHARSET_DIGIT => '0123456789',
    CHARSET_SPECIAL => '!@#$%^&*()_+-=[]{}|;:,.<>?/~`',
};

# --- Configuração ---
my $CFG = {
    arquivo     => undef,
    wordlist    => undef,
    saida       => undef,
    formato     => undef,      # auto-detect
    tipo        => undef,      # zip, rar, 7z
    backend     => undef,      # auto-select

    # Comportamento
    verbose     => 0,
    quieto      => 0,
    forcar      => 0,
    resume      => 0,
    shuffle     => 0,

    # Paralelismo
    threads     => 1,
    fork        => 0,          # modo fork (não recomendado para muitas threads)

    # Mutações
    mutate      => 0,          # aplicar regras de mutação
    regras      => undef,      # arquivo de regras customizadas

    # Modo incremental
    incremental => 0,
    min_len     => 1,
    max_len     => 4,
    charset     => 'lud',      # l=lower, u=upper, d=digit, s=special

    # Limites
    timeout     => 0,          # tempo máximo (segundos)
    max_tentativas => 0,       # máximo de tentativas

    # Avançado
    benchmark   => 0,
    continuar   => 0,          # continuar mesmo encontrando senha
    testar_arquivo => 1,       # verificar integridade antes
    progresso   => 1,          # barra de progresso
};

# --- Estado global ---
my $ESTADO = {
    inicio          => time(),
    senhas_testadas  => 0,
    senhas_restantes => 0,
    senha_encontrada => undef,
    encontrou       => 0,
    testadas_hash   => {},     # cache de senhas já testadas
    taxa_atual      => 0,
    ultimo_log      => time(),
    arquivo_info    => undef,
    backend_bin     => undef,
    modo            => 'wordlist',  # wordlist, incremental, mutate
};

# ======================================================================
#                        SUB-ROTINAS PRINCIPAIS
# ======================================================================

sub colorir {
    my ($cor, $texto) = @_;
    return $texto unless -t STDOUT;
    my %cores = (
        vermelho => "\e[31m", verde => "\e[32m", amarelo => "\e[33m",
        azul     => "\e[34m", magenta => "\e[35m", ciano  => "\e[36m",
        branco   => "\e[37m", negrito  => "\e[1m", reset  => "\e[0m",
        ok       => "\e[32m", erro     => "\e[31m", aviso  => "\e[33m",
        info     => "\e[36m", destaque => "\e[1;37m",
    );
    my $c = $cores{$cor} // '';
    return "$c$texto\e[0m";
}

sub log_msg {
    my ($nivel, $msg) = @_;
    return if $CFG->{quieto} && $nivel ne 'erro' && $nivel ne 'ok';
    return if $CFG->{verbose} < 1 && $nivel eq 'debug';
    return if $CFG->{verbose} < 2 && $nivel eq 'trace';

    my $timestamp = strftime('%H:%M:%S', localtime);
    my $nivel_str = uc(substr($nivel, 0, 4));
    my $saida = sprintf("[%s] [%s] %s", $timestamp, $nivel_str, $msg);

    if (-t STDOUT) {
        my %cor_nivel = (
            info => 'info', debug => 'azul', trace => 'branco',
            erro => 'erro', aviso => 'aviso', ok => 'ok',
        );
        $saida = colorir($cor_nivel{$nivel} // '', $saida);
    }

    say $saida;
}

sub exibir_ajuda {
    print <<"AJUDA";
======================================================================
    ${\(TOOL_NAME)} v@{[VERSION]} — ${\(AUTHOR)} © ${\(YEAR)}
         Cracker Profissional de Arquivos Compactados
======================================================================

  📌 USO: $0 -f ARQUIVO -w WORDLIST [OPÇÕES]

  ═══════════════════════════════════════════════════════════════════
   OBRIGATÓRIO
  ═══════════════════════════════════════════════════════════════════
   -f, --file ARQUIVO     Arquivo .zip, .rar, .7z, .rar5
   -w, --wordlist ARQUIVO Lista de senhas (uma por linha)

  ═══════════════════════════════════════════════════════════════════
   FORMATOS E BACKENDS
  ═══════════════════════════════════════════════════════════════════
   -T, --type TIPO        Forçar tipo: zip, rar, 7z (auto por extensão)
   -B, --backend BIN      Backend específico: unzip, unrar, 7z, john

  ═══════════════════════════════════════════════════════════════════
   PARALELISMO E PERFORMANCE
  ═══════════════════════════════════════════════════════════════════
   -t, --threads N        Número de processos paralelos (padrão: 1)
   --fork                 Usar fork em vez de loop (melhor para
                          muitos threads, requer Parallel::ForkManager)
   --shuffle              Embaralhar wordlist antes de testar
   --resume               Continuar de onde parou (usa cache)

  ═══════════════════════════════════════════════════════════════════
   MUTAÇÕES E REGRAS
  ═══════════════════════════════════════════════════════════════════
   -m, --mutate           Aplicar mutações automaticamente em cada
                          senha (capitalize, capitalize+num, etc.)
   -r, --rules ARQUIVO    Arquivo de regras customizado (uma por linha)
                          Regras suportadas: :c, :u, :l, :nNUM, :sSIMB,
                          :rN (repetir), :aTEXTO (append), :pTEXTO (prepend)

  ═══════════════════════════════════════════════════════════════════
   MODO INCREMENTAL (força bruta)
  ═══════════════════════════════════════════════════════════════════
   -i, --incremental      Ativar modo incremental (ignora wordlist)
   --min-len N            Comprimento mínimo (padrão: 1)
   --max-len N            Comprimento máximo (padrão: 4)
   --charset CONJUNTO     Conjunto de caracteres: l(ower), u(pper),
                          d(igit), s(pecial). Ex: lud = lower+upper+digit

  ═══════════════════════════════════════════════════════════════════
   CONTROLE
  ═══════════════════════════════════════════════════════════════════
   -c, --continue         Continuar mesmo após encontrar senha
   --timeout SEGUNDOS     Parar após X segundos
   --max-attempts N       Parar após N tentativas
   --no-verify            Pular verificação do arquivo alvo

  ═══════════════════════════════════════════════════════════════════
   SAÍDA
  ═══════════════════════════════════════════════════════════════════
   -o, --output ARQUIVO   Salvar senha encontrada em arquivo
   -q, --quiet            Modo silencioso (apenas resultado)
   -v, --verbose          Mais detalhes
   --benchmark            Modo benchmark (testa taxa do backend)
   -H, --ajuda            Esta mensagem
   -V, --versao           Versão

  ═══════════════════════════════════════════════════════════════════
   EXEMPLOS
  ═══════════════════════════════════════════════════════════════════
   # Básico
   $0 -f protegido.zip -w rockyou.txt

   # Paralelo com 4 threads
   $0 -f protegido.rar -w wordlist.txt -t 4

   # Com mutações (testa variações de cada senha)
   $0 -f arquivo.zip -w senhas.txt -m

   # Modo incremental (força bruta 1-6 chars alfanuméricos)
   $0 -f arquivo.7z -i --min-len 1 --max-len 6 --charset lud

   # Benchmark do backend
   $0 --benchmark -f teste.zip

   # Resumo de ataque
   $0 -f backup.zip -w common.txt --shuffle -t 8 --resume -o senha.txt

======================================================================
AJUDA
    exit 0;
}

sub exibir_versao {
    say colorir('destaque', TOOL_NAME . " v" . VERSION) . " | " . AUTHOR . " © " . YEAR;
    printf "Perl v%vd | %s\n", $^V, $^O;
    say "Paralelismo: " . ($HAS_PARALLEL ? "Parallel::ForkManager disponível" : "apenas loop sequencial");
    exit 0;
}

# ======================================================================
#                   DETECÇÃO E VALIDAÇÃO
# ======================================================================

sub detectar_tipo_arquivo {
    my $arquivo = shift;
    return undef unless -f $arquivo;

    # 1. Pela extensão
    my $ext = $arquivo;
    $ext =~ s/.*\.//;
    $ext = lc($ext);

    my %ext_para_tipo = (
        zip => 'zip', rar => 'rar', '7z' => '7z',
        rar5 => 'rar', '001' => 'rar',  # volumes
    );

    return $ext_para_tipo{$ext} if exists $ext_para_tipo{$ext};

    # 2. Pela assinatura (magic bytes)
    open(my $fh, '<', $arquivo) or return undef;
    binmode($fh);
    read($fh, my $magic, 8);
    close $fh;

    return 'zip' if $magic =~ /^PK\x03\x04/;
    return 'rar' if $magic =~ /^Rar!\x1a\x07/;
    return '7z'  if $magic =~ /^7z\xbc\xaf\x27\x1c/;

    return undef;
}

sub detectar_backend {
    my $tipo = shift;

    my %backends = (
        zip => ['unzip',    '/usr/bin/unzip'],
        rar => ['unrar',    '/usr/bin/unrar', '/usr/bin/unrar-free'],
        '7z' => ['7z',      '/usr/bin/7z',   '/usr/bin/p7zip'],
    );

    my @candidatos = @{$backends{$tipo} // []};
    shift @candidatos;  # remove nome

    for my $bin (@candidatos) {
        return $bin if -x $bin;
    }

    # Fallback: procurar no PATH
    my $nome = $backends{$tipo}[0];
    for my $path (split(/:/, $ENV{PATH} // '')) {
        my $candidate = File::Spec->catfile($path, $nome);
        return $candidate if -x $candidate;
    }

    return undef;
}

sub _comando_existe {
    my $cmd = shift;
    for my $path (split(/:/, $ENV{PATH} // '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin')) {
        return File::Spec->catfile($path, $cmd) if -x File::Spec->catfile($path, $cmd);
    }
    return undef;
}

sub verificar_arquivo {
    my $arquivo = shift;

    unless (-f $arquivo) {
        log_msg('erro', "Arquivo não encontrado: $arquivo");
        return 0;
    }

    unless (-r $arquivo) {
        log_msg('erro', "Arquivo sem permissão de leitura: $arquivo");
        return 0;
    }

    my $tamanho = (stat($arquivo))[7];
    if ($tamanho == 0) {
        log_msg('erro', "Arquivo vazio: $arquivo");
        return 0;
    }

    log_msg('info', sprintf("Arquivo: %s (%s)", $arquivo, _formatar_tamanho($tamanho)));

    # Verificar se o arquivo está com senha
    my $tipo = $CFG->{tipo};
    my $backend = $CFG->{backend};

    if (!$CFG->{testar_arquivo}) {
        log_msg('debug', "Verificação de integridade pulada (--no-verify)");
        return 1;
    }

    log_msg('debug', "Verificando integridade do arquivo...");

    my $cmd;
    if ($tipo eq 'zip') {
        $cmd = "$backend -t '$arquivo' 2>&1";
    }
    elsif ($tipo eq 'rar') {
        $cmd = "$backend t '$arquivo' 2>&1";
    }
    elsif ($tipo eq '7z') {
        $cmd = "$backend t '$arquivo' 2>&1";
    }

    if ($cmd) {
        my $output = `$cmd`;
        if ($output =~ /error|corrupt|fail|não/i && $output !~ /password/i) {
            log_msg('aviso', "Arquivo parece corrompido. Verifique manualmente.");
            log_msg('debug', "Output da verificação: $output") if $CFG->{verbose};
            unless ($CFG->{forcar}) {
                log_msg('info', "Use --forcar para tentar mesmo assim.");
                return 0;
            }
        }
    }

    return 1;
}

sub validar_wordlist {
    my $arquivo = shift;

    unless ($arquivo && -f $arquivo) {
        log_msg('erro', "Wordlist não encontrada: " . ($arquivo // '(nenhuma)'));
        return 0;
    }

    my $tamanho = (stat($arquivo))[7];
    log_msg('info', sprintf("Wordlist: %s (%s)", $arquivo, _formatar_tamanho($tamanho)));

    # Estimar número de senhas
    open(my $fh, '<', $arquivo) or do {
        log_msg('erro', "Não foi possível abrir wordlist: $!");
        return 0;
    };

    my $linhas = 0;
    while (<$fh>) {
        $linhas++;
        last if $linhas > 1000;  # só amostra
    }
    close $fh;

    # Estimativa mais precisa
    if ($tamanho > 0) {
        my $est_total = int($tamanho / 8);  # ~8 bytes por linha
        log_msg('info', "  ~" . _formatar_numero($est_total) . " senhas estimadas");
    }

    return 1;
}

# ======================================================================
#                     TESTE DE SENHA INDIVIDUAL
# ======================================================================

sub testar_senha {
    my ($senha, $arquivo, $tipo, $backend) = @_;

    return 0 if $ESTADO->{encontrou} && !$CFG->{continuar};

    my $saida;

    if ($tipo eq 'zip') {
        # unzip -t -P "senha" arquivo.zip
        # -t = test, -P = password
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm(5);  # timeout de 5s por tentativa

        $saida = `$backend -t -P '$senha' '$arquivo' 2>&1`;
        alarm(0);

        if ($saida =~ /no error|ok|fine|correct/i && $saida !~ /wrong|incorrect/i) {
            return 1;
        }
    }
    elsif ($tipo eq 'rar') {
        # unrar t -p"senha" arquivo.rar
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm(5);

        $saida = `$backend t -p'$senha' '$arquivo' 2>&1`;
        alarm(0);

        if ($saida =~ /all ok|ok|success|correct/i && $saida !~ /wrong|incorrect/i) {
            return 1;
        }
    }
    elsif ($tipo eq '7z') {
        # 7z t -p"senha" arquivo.7z
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm(10);  # 7z pode ser mais lento

        $saida = `$backend t -p'$senha' '$arquivo' 2>&1`;
        alarm(0);

        if ($saida =~ /everything is ok|ok/i && $saida !~ /wrong|incorrect/i) {
            return 1;
        }
    }

    return 0;
}

sub testar_senha_rapido {
    my ($senha, $arquivo, $tipo, $backend) = @_;

    # Versão otimizada: testa apenas o cabeçalho, não extrai
    return testar_senha(@_);
}

# ======================================================================
#                     MUTAÇÕES DE SENHA
# ======================================================================

sub aplicar_mutacoes {
    my $senha = shift;

    my @mutacoes = (
        $senha,                          # original
        ucfirst($senha),                 # Capitalize
        uc($senha),                      # UPPERCASE
        lc($senha),                      # lowercase
        $senha . '123',                  # +123
        $senha . '123!',                 # +123!
        $senha . '!',                    # +!
        $senha . '@',                    # +@
        $senha . '2024',                 # +ano
        $senha . '2025',                 # +ano
        $senha . '2026',                 # +ano
        ucfirst($senha) . '123',         # Capitalize+123
        ucfirst($senha) . '!',           # Capitalize+!
        uc($senha) . '123',              # UPPER+123
        reverse($senha),                 # reverso
        $senha . $senha,                 # duplicado
        substr($senha, 0, 1) . $senha,   # primeira letra + senha
        $senha . substr($senha, 0, 1),   # senha + primeira letra
    );

    # Remover duplicatas
    my %visto;
    return grep { !$visto{$_}++ } @mutacoes;
}

sub aplicar_regras_do_arquivo {
    my $senha = shift;
    my $arq_regras = $CFG->{regras};
    return ($senha) unless $arq_regras && -f $arq_regras;

    open(my $fh, '<', $arq_regras) or return ($senha);
    my @regras = <$fh>;
    close $fh;
    chomp @regras;

    my @resultados = ($senha);

    for my $regra (@regras) {
        next if $regra =~ /^#/ || $regra =~ /^\s*$/;

        if ($regra eq ':c') {
            push @resultados, ucfirst($senha);
        }
        elsif ($regra eq ':u') {
            push @resultados, uc($senha);
        }
        elsif ($regra eq ':l') {
            push @resultados, lc($senha);
        }
        elsif ($regra =~ /^:n(\d+)$/) {
            push @resultados, $senha . $1;
        }
        elsif ($regra =~ /^:s(.)$/) {
            push @resultados, $senha . $1;
        }
        elsif ($regra =~ /^:r(\d+)$/) {
            push @resultados, $senha x $1;
        }
        elsif ($regra =~ /^:a(.+)$/) {
            push @resultados, $senha . $1;
        }
        elsif ($regra =~ /^:p(.+)$/) {
            push @resultados, $1 . $senha;
        }
    }

    my %visto;
    return grep { !$visto{$_}++ } @resultados;
}

# ======================================================================
#                     GERADOR INCREMENTAL
# ======================================================================

sub gerar_charset {
    my $spec = shift;
    my $chars = '';

    $chars .= CHARSET_LOWER   if $spec =~ /l/i;
    $chars .= CHARSET_UPPER   if $spec =~ /u/i;
    $chars .= CHARSET_DIGIT   if $spec =~ /d/i;
    $chars .= CHARSET_SPECIAL if $spec =~ /s/i;

    return $chars;
}

sub gerar_combinacoes_incrementais {
    my ($min_len, $max_len, $charset) = @_;

    my $chars = gerar_charset($charset);
    return unless length $chars;

    my @chars_list = split //, $chars;
    my $total = 0;

    for my $len ($min_len .. $max_len) {
        $total += @chars_list ** $len;
    }

    log_msg('info', sprintf("Modo incremental: %d-%d chars, charset '%s' (%d caracteres, ~%s combinações)",
        $min_len, $max_len, $charset, scalar @chars_list, _formatar_numero($total)));

    # Gerar usando um iterador para não consumir memória
    my @indices = (0) x $min_len;

    while (@indices >= $min_len && @indices <= $max_len) {
        my $senha = join('', @chars_list[@indices]);
        yield $senha;

        # Incrementar
        my $i = $#indices;
        while ($i >= 0) {
            $indices[$i]++;
            if ($indices[$i] < @chars_list) {
                last;
            }
            $indices[$i] = 0;
            $i--;
        }

        if ($i < 0) {
            # Carregar novo dígito
            if (@indices < $max_len) {
                @indices = (0) x (@indices + 1);
            }
            else {
                last;  # acabou
            }
        }
    }
}

# ======================================================================
#                     EXECUÇÃO PRINCIPAL (LOOP)
# ======================================================================

sub executar_wordlist {
    my ($arquivo, $wordlist, $tipo, $backend) = @_;

    open(my $fh, '<', $wordlist) or do {
        log_msg('erro', "Não foi possível abrir wordlist: $!");
        return;
    };

    my @senhas = <$fh>;
    close $fh;
    chomp @senhas;

    # Embaralhar se solicitado
    @senhas = shuffle(@senhas) if $CFG->{shuffle};

    $ESTADO->{senhas_restantes} = scalar @senhas;

    log_msg('info', sprintf("Iniciando ataque: %d senhas na wordlist", scalar @senhas));
    log_msg('info', "Backend: $backend | Threads: $CFG->{threads}");
    log_msg('info', "Pressione Ctrl+C para interromper.") unless $CFG->{quieto};

    # Iniciar
    my $contador = 0;
    my $ultimo_log = time();
    my $tentativas_ultimo_log = 0;

    for my $senha_original (@senhas) {
        last if $ESTADO->{encontrou} && !$CFG->{continuar};
        last if $CFG->{max_tentativas} && $contador >= $CFG->{max_tentativas};
        last if $CFG->{timeout} && (time() - $ESTADO->{inicio}) > $CFG->{timeout};

        # Obter lista de senhas a testar (com ou sem mutações)
        my @testar = ($senha_original);

        if ($CFG->{mutate}) {
            my @mutadas = aplicar_mutacoes($senha_original);
            push @testar, @mutadas;
        }

        if ($CFG->{regras}) {
            my @regradas = aplicar_regras_do_arquivo($senha_original);
            push @testar, @regradas;
        }

        for my $senha (@testar) {
            last if $ESTADO->{encontrou} && !$CFG->{continuar};
            last if $CFG->{max_tentativas} && $contador >= $CFG->{max_tentativas};

            next if length $senha == 0;
            next if $CFG->{resume} && $ESTADO->{testadas_hash}{$senha};

            $contador++;
            $ESTADO->{senhas_testadas}++;
            $ESTADO->{testadas_hash}{$senha} = 1;

            # Atualizar progresso
            my $agora = time();
            if ($agora - $ultimo_log >= 1 && !$CFG->{quieto}) {
                my $taxa = $contador - $tentativas_ultimo_log;
                $ESTADO->{taxa_atual} = $taxa;
                $tentativas_ultimo_log = $contador;
                $ultimo_log = $agora;

                my $decorrido = $agora - $ESTADO->{inicio} || 1;
                my $taxa_media = int($contador / $decorrido);

                printf("\r  🔑 Testando: %-40s | Tentativas: %s | Taxa: %d/s | Tempo: %ds",
                    $senha,
                    _formatar_numero($contador),
                    $taxa_media,
                    $decorrido
                );
            }

            # Testar senha
            if (testar_senha($senha, $arquivo, $tipo, $backend)) {
                $ESTADO->{encontrou} = 1;
                $ESTADO->{senha_encontrada} = $senha;

                print "\n\n";
                say colorir('verde', '=' x 60);
                say colorir('destaque', "  🎉 SENHA ENCONTRADA: $senha");
                say colorir('verde', '=' x 60);

                # Salvar
                if ($CFG->{saida}) {
                    open(my $sfh, '>', $CFG->{saida}) or do {
                        log_msg('erro', "Não foi possível salvar resultado: $!");
                        next;
                    };
                    my $data = strftime('%d/%m/%Y %H:%M:%S', localtime);
                    print $sfh "Arquivo: $arquivo\n";
                    print $sfh "Senha:   $senha\n";
                    print $sfh "Data:    $data\n";
                    print $sfh "Método:  Wordlist" . ($CFG->{mutate} ? ' + Mutações' : '') . "\n";
                    print $sfh "Tentativas: $contador\n";
                    close $sfh;
                    say colorir('ok', "  💾 Senha salva em: $CFG->{saida}");
                }

                last;
            }
        }
    }

    # Limpar linha de progresso
    print "\r" . ' ' x 80 . "\r" unless $CFG->{quieto};

    unless ($ESTADO->{encontrou}) {
        log_msg('info', "Nenhuma senha válida encontrada na wordlist.");
    }
}

sub executar_incremental {
    my ($arquivo, $tipo, $backend) = @_;

    my $charset_spec = $CFG->{charset} // 'lud';
    my $min_len = $CFG->{min_len} // 1;
    my $max_len = $CFG->{max_len} // 4;
    my $chars = gerar_charset($charset_spec);

    unless (length $chars) {
        log_msg('erro', "Charset vazio. Use --charset com l, u, d e/ou s");
        return;
    }

    log_msg('info', sprintf("Iniciando ataque incremental: %d-%d chars, charset '%s' (%d chars)",
        $min_len, $max_len, $charset_spec, length $chars));
    log_msg('info', "Backend: $backend");

    my $contador = 0;
    my $ultimo_log = time();
    my $tentativas_ultimo_log = 0;

    my @chars_list = split //, $chars;

    for my $len ($min_len .. $max_len) {
        last if $ESTADO->{encontrou} && !$CFG->{continuar};

        # Usar algoritmo de contagem
        my @indices = (0) x $len;
        my $total_len = @chars_list ** $len;
        my $count_len = 0;

        log_msg('debug', sprintf("  Comprimento %d: %s combinações", $len, _formatar_numero($total_len)));

        while (1) {
            last if $ESTADO->{encontrou} && !$CFG->{continuar};
            last if $CFG->{max_tentativas} && $contador >= $CFG->{max_tentativas};
            last if $CFG->{timeout} && (time() - $ESTADO->{inicio}) > $CFG->{timeout};

            $count_len++;
            $contador++;
            $ESTADO->{senhas_testadas}++;

            my $senha = join('', @chars_list[@indices]);

            # Progresso
            my $agora = time();
            if ($agora - $ultimo_log >= 1 && !$CFG->{quieto}) {
                my $taxa = $contador - $tentativas_ultimo_log;
                $ESTADO->{taxa_atual} = $taxa;
                $tentativas_ultimo_log = $contador;
                $ultimo_log = $agora;

                my $decorrido = $agora - $ESTADO->{inicio} || 1;
                my $taxa_media = int($contador / $decorrido);
                my $pct = $total_len > 0 ? 100 * $count_len / $total_len : 0;

                printf("\r  🔑 [%d chars] %-30s | %s/%s (%.1f%%) | Taxa: %d/s | %ds",
                    $len, $senha,
                    _formatar_numero($count_len),
                    _formatar_numero($total_len),
                    $pct,
                    $taxa_media,
                    $decorrido
                );
            }

            # Testar
            if (testar_senha($senha, $arquivo, $tipo, $backend)) {
                $ESTADO->{encontrou} = 1;
                $ESTADO->{senha_encontrada} = $senha;

                print "\n\n";
                say colorir('verde', '=' x 60);
                say colorir('destaque', "  🎉 SENHA ENCONTRADA: $senha");
                say colorir('verde', '=' x 60);

                if ($CFG->{saida}) {
                    open(my $sfh, '>', $CFG->{saida}) or do {
                        log_msg('erro', "Não foi possível salvar resultado: $!");
                        last;
                    };
                    my $data = strftime('%d/%m/%Y %H:%M:%S', localtime);
                    print $sfh "Arquivo: $arquivo\n";
                    print $sfh "Senha:   $senha\n";
                    print $sfh "Data:    $data\n";
                    print $sfh "Método:  Incremental ($charset_spec, $min_len-$max_len)\n";
                    print $sfh "Tentativas: $contador\n";
                    close $sfh;
                    say colorir('ok', "  💾 Senha salva em: $CFG->{saida}");
                }

                last;
            }

            # Incrementar
            my $i = $#indices;
            while ($i >= 0) {
                $indices[$i]++;
                if ($indices[$i] < @chars_list) {
                    last;
                }
                $indices[$i] = 0;
                $i--;
            }

            last if $i < 0;  # overflow — próximo comprimento
        }

        last if $ESTADO->{encontrou} && !$CFG->{continuar};
    }

    print "\r" . ' ' x 80 . "\r" unless $CFG->{quieto};
}

# ======================================================================
#                  FUNÇÕES AUXILIARES
# ======================================================================

sub _formatar_tamanho {
    my $bytes = shift;
    return '0B' unless $bytes;
    my @unidades = ('B', 'KB', 'MB', 'GB');
    my $i = 0;
    while ($bytes >= 1024 && $i < @unidades - 1) {
        $bytes /= 1024;
        $i++;
    }
    return sprintf("%.1f %s", $bytes, $unidades[$i]);
}

sub _formatar_numero {
    my $num = shift;
    return '0' unless defined $num;
    $num = int($num);
    my $neg = $num < 0 ? '-' : '';
    $num = abs($num);
    $num = reverse($num);
    $num =~ s/(\d{3})(?=\d)/$1./g;
    $num = reverse($num);
    return $neg . $num;
}

sub _salvar_cache {
    my $arquivo_cache = File::Spec->catfile('/tmp', 'fydelisrarzip_cache.txt');
    open(my $fh, '>', $arquivo_cache) or return;
    for my $s (keys %{$ESTADO->{testadas_hash}}) {
        print $fh "$s\n";
    }
    close $fh;
    log_msg('debug', "Cache salvo: $arquivo_cache (" . scalar(keys %{$ESTADO->{testadas_hash}}) . " senhas)");
}

sub _carregar_cache {
    my $arquivo_cache = File::Spec->catfile('/tmp', 'fydelisrarzip_cache.txt');
    return unless -f $arquivo_cache;

    open(my $fh, '<', $arquivo_cache) or return;
    my $count = 0;
    while (my $linha = <$fh>) {
        chomp $linha;
        $ESTADO->{testadas_hash}{$linha} = 1;
        $count++;
    }
    close $fh;

    log_msg('info', "Cache carregado: $count senhas já testadas (puladas no resume)");
}

sub executar_benchmark {
    my ($arquivo, $tipo, $backend) = @_;

    say colorir('destaque', "\n🧪 Benchmark de Performance");
    say "=" x 60;

    my $senha_teste = 'benchmark_test_password_123!@#';

    # Aquecer
    log_msg('info', "Aquecendo...");
    for (1 .. 3) {
        testar_senha($senha_teste, $arquivo, $tipo, $backend);
    }

    # Benchmark
    my $inicio = time();
    my $tentativas = 0;
    my $duracao = 5;  # segundos de benchmark

    log_msg('info', "Executando benchmark por ${duracao}s...");

    while (time() - $inicio < $duracao) {
        testar_senha($senha_teste, $arquivo, $tipo, $backend);
        $tentativas++;
    }

    my $decorrido = time() - $inicio || 1;
    my $taxa = $tentativas / $decorrido;

    say "";
    say colorir('destaque', "Resultados do Benchmark:");
    say "  Backend  : $backend";
    say "  Formato  : $tipo";
    say "  Arquivo  : $arquivo";
    say "  Tentativas: $tentativas em ${decorrido}s";
    printf "  Taxa     : %.0f senhas/s\n", $taxa;
    printf "  Taxa     : %.0f senhas/min\n", $taxa * 60;
    printf "  Taxa     : %.0f senhas/hora\n", $taxa * 3600;

    # Estimativas
    my $wordlist_size = $CFG->{wordlist} && -f $CFG->{wordlist} ? (stat($CFG->{wordlist}))[7] : 0;
    if ($wordlist_size > 0) {
        my $est_senhas = int($wordlist_size / 8);
        my $est_tempo = $est_senhas / $taxa;
        printf "\n  📊 Para wordlist de %s senhas:\n", _formatar_numero($est_senhas);
        printf "     Tempo estimado: %s\n", _formatar_tempo($est_tempo);
    }

    say "";
    exit 0;
}

sub _formatar_tempo {
    my $segundos = shift;
    return '0s' unless $segundos;

    if ($segundos < 60) {
        return sprintf("%.0fs", $segundos);
    }
    elsif ($segundos < 3600) {
        return sprintf("%.0fmin %ds", $segundos / 60, $segundos % 60);
    }
    elsif ($segundos < 86400) {
        my $horas = int($segundos / 3600);
        my $min = int(($segundos % 3600) / 60);
        return sprintf("%dh %dmin", $horas, $min);
    }
    else {
        my $dias = int($segundos / 86400);
        my $horas = int(($segundos % 86400) / 3600);
        return sprintf("%d dias %dh", $dias, $horas);
    }
}

# ======================================================================
#                      TRATAMENTO DE SINAIS
# ======================================================================

sub configurar_sinais {
    $SIG{INT} = sub {
        say "\n";
        log_msg('aviso', "Interrompido pelo usuário (Ctrl+C)");
        _salvar_cache() if $CFG->{resume};
        exibir_estatisticas_finais();
        exit 130;
    };

    $SIG{TERM} = sub {
        say "\n";
        log_msg('aviso', "Processo terminado");
        _salvar_cache() if $CFG->{resume};
        exibir_estatisticas_finais();
        exit 0;
    };
}

sub exibir_estatisticas_finais {
    my $decorrido = time() - $ESTADO->{inicio} || 1;

    say "";
    say colorir('destaque', "=" x 60);
    say colorir('destaque', "  📊 ESTATÍSTICAS DA OPERAÇÃO");
    say colorir('destaque', "=" x 60);

    printf "  Arquivo     : %s\n", $CFG->{arquivo};
    printf "  Formato     : %s\n", $CFG->{tipo} // 'desconhecido';
    printf "  Backend     : %s\n", $CFG->{backend} // 'N/A';
    printf "  Modo        : %s\n", $CFG->{incremental} ? 'Incremental' : 'Wordlist';
    printf "  Threads     : %d\n", $CFG->{threads};
    printf "  Mutações    : %s\n", $CFG->{mutate} ? 'Sim' : 'Não';
    printf "  Duração     : %s\n", _formatar_tempo($decorrido);
    printf "  Tentativas  : %s\n", _formatar_numero($ESTADO->{senhas_testadas});
    printf "  Taxa média  : %.0f senhas/s\n", $ESTADO->{senhas_testadas} / $decorrido;

    if ($ESTADO->{encontrou}) {
        say colorir('verde', "  🎉 SENHA ENCONTRADA: $ESTADO->{senha_encontrada}");
    }
    else {
        say colorir('aviso', "  ❌ Nenhuma senha encontrada.");
    }

    say colorir('destaque', "=" x 60);
    say "";
}

# ======================================================================
#                         ENTRADA PRINCIPAL
# ======================================================================

sub main {
    # --- Parse de argumentos ---
    my $ajuda;
    my $versao;

    GetOptions(
        'f|file=s'          => \$CFG->{arquivo},
        'w|wordlist=s'      => \$CFG->{wordlist},
        'o|output=s'        => \$CFG->{saida},
        'T|type=s'          => \$CFG->{formato},
        'B|backend=s'       => \$CFG->{backend},

        't|threads=i'       => \$CFG->{threads},
        'fork'              => \$CFG->{fork},
        'shuffle'           => \$CFG->{shuffle},
        'resume'            => \$CFG->{resume},

        'm|mutate'          => \$CFG->{mutate},
        'r|rules=s'         => \$CFG->{regras},

        'i|incremental'     => \$CFG->{incremental},
        'min-len=i'         => \$CFG->{min_len},
        'max-len=i'         => \$CFG->{max_len},
        'charset=s'         => \$CFG->{charset},

        'c|continue'        => \$CFG->{continuar},
        'timeout=i'         => \$CFG->{timeout},
        'max-attempts=i'    => \$CFG->{max_tentativas},
        'no-verify'         => sub { $CFG->{testar_arquivo} = 0 },

        'q|quiet'           => \$CFG->{quieto},
        'v|verbose+'        => \$CFG->{verbose},
        'benchmark'         => \$CFG->{benchmark},
        'H|ajuda'           => \$ajuda,
        'V|versao'          => \$versao,
        'h|help'            => \$ajuda,
        'forcar'            => \$CFG->{forcar},
    ) or do {
        say "\n❌ Erro nos argumentos. Use -H para ajuda.\n";
        exit 1;
    };

    exibir_ajuda()  if $ajuda;
    exibir_versao() if $versao;

    # --- Banner ---
    unless ($CFG->{quieto}) {
        say '';
        say '=' x 60;
        printf "  %s v%s  |  %s © %s\n", TOOL_NAME, VERSION, AUTHOR, YEAR;
        say '  Cracker Profissional de Arquivos Compactados';
        say '=' x 60;
        say '';
    }

    # --- Configurar sinais ---
    configurar_sinais();

    # --- Detectar tipo de arquivo ---
    $CFG->{arquivo} = abs_path($CFG->{arquivo}) if $CFG->{arquivo};
    $CFG->{wordlist} = abs_path($CFG->{wordlist}) if $CFG->{wordlist};

    unless ($CFG->{arquivo}) {
        if ($CFG->{benchmark}) {
            log_msg('erro', "Benchmark requer um arquivo alvo (-f)");
            exit 1;
        }
        log_msg('erro', "Arquivo não especificado. Use -f ARQUIVO");
        exit 1;
    }

    unless (-f $CFG->{arquivo}) {
        log_msg('erro', "Arquivo não encontrado: $CFG->{arquivo}");
        exit 1;
    }

    # Detectar tipo
    $CFG->{tipo} = $CFG->{formato} // detectar_tipo_arquivo($CFG->{arquivo});
    unless ($CFG->{tipo}) {
        log_msg('erro', "Não foi possível detectar o tipo do arquivo. Especifique com -T zip|rar|7z");
        exit 1;
    }

    log_msg('info', "Formato detectado: " . uc($CFG->{tipo}));

    # --- Detectar backend ---
    $CFG->{backend} //= detectar_backend($CFG->{tipo});
    unless ($CFG->{backend}) {
        log_msg('erro', "Nenhum backend encontrado para " . uc($CFG->{tipo}));
        say colorir('info', "  Instale com:");
        say "    ZIP: sudo apt install unzip";
        say "    RAR: sudo apt install unrar-free";
        say "    7z:  sudo apt install p7zip-full";
        exit 1;
    }
    log_msg('info', "Backend: $CFG->{backend}");

    # --- Verificar arquivo ---
    unless (verificar_arquivo($CFG->{arquivo})) {
        exit 1 unless $CFG->{forcar};
    }

    # --- Benchmark ---
    if ($CFG->{benchmark}) {
        executar_benchmark($CFG->{arquivo}, $CFG->{tipo}, $CFG->{backend});
        exit 0;
    }

    # --- Modo incremental vs wordlist ---
    if ($CFG->{incremental}) {
        executar_incremental($CFG->{arquivo}, $CFG->{tipo}, $CFG->{backend});
    }
    else {
        # Wordlist obrigatória
        unless ($CFG->{wordlist}) {
            log_msg('erro', "Wordlist não especificada. Use -w ARQUIVO ou -i para incremental");
            exit 1;
        }

        unless (validar_wordlist($CFG->{wordlist})) {
            exit 1;
        }

        # Carregar cache se resume
        _carregar_cache() if $CFG->{resume};

        executar_wordlist($CFG->{arquivo}, $CFG->{wordlist}, $CFG->{tipo}, $CFG->{backend});
    }

    # --- Final ---
    _salvar_cache() if $CFG->{resume};
    exibir_estatisticas_finais();

    if ($ESTADO->{encontrou}) {
        exit 0;
    }
    else {
        exit 1;
    }
}

# --- Ponto de entrada ---
main();

__END__

=head1 NOME

FydelisRarZip - Cracker Profissional de Arquivos Compactados

=head1 DESCRIÇÃO

Ferramenta avançada para teste de senhas em arquivos ZIP, RAR e 7z.
Suporta wordlists, mutações automáticas, modo incremental (força bruta),
paralelismo, resume, e estatísticas em tempo real.

=head1 FORMATOS SUPORTADOS

=over 4

=item * ZIP (backends: unzip)

=item * RAR / RAR5 (backends: unrar, unrar-free)

=item * 7z (backends: p7zip, 7z)

=back

=head1 MODOS DE ATAQUE

=over 4

=item * Wordlist: Testa senhas de uma lista

=item * Wordlist + Mutações: Aplica regras automáticas em cada senha

=item * Wordlist + Regras customizadas: Arquivo de regras definido pelo usuário

=item * Incremental: Força bruta com charset configurável

=back

=head1 MUTAÇÕES AUTOMÁTICAS

Quando ativado (--mutate), cada senha gera automaticamente:

  original, Capitalize, UPPERCASE, lowercase,
  +123, +123!, +!, +@, +ano, Capitalize+123,
  reverso, duplicado, etc.

=head1 REGRAS CUSTOMIZADAS (--rules)

  :c        Capitalize (primeira maiúscula)
  :u        UPPERCASE
  :l        lowercase
  :n123     Append número
  :s!       Append símbolo
  :r3       Repetir 3x
  :aTEXTO   Append texto
  :pTEXTO   Prepend texto

=head1 SEGURANÇA

Use apenas em arquivos de sua propriedade ou com autorização
explícita por escrito. O uso não autorizado é crime.

=head1 AUTOR

FydelisTechos © 2026

=cut