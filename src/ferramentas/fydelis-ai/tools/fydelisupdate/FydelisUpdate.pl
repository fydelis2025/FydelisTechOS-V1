#!/usr/bin/perl
# ==============================================================
#         F Y D E L I S U P D A T E   v 2 . 0   P R O
#                   FydelisTechos © 2026
#   Gerenciador Profissional de Atualizações do Ecossistema
#   Uso Exclusivo em Ambientes Autorizados
# ==============================================================
#
# Dependências:
#   - curl ou wget (para downloads)
#   - openssl (para verificação de checksum)
#   - LWP::UserAgent (opcional, mais rápido)
#
# Compatibilidade: Linux/Unix/macOS com Perl 5.10+
#
# ==============================================================

use strict;
use warnings;
use v5.10.0;

# --- Módulos ---
use Getopt::Long qw(:config no_ignore_case bundling);
use POSIX qw(strftime);
use File::Spec;
use File::Basename qw(basename);
use File::Path qw(make_path remove_tree);
use Cwd 'abs_path';
use English qw(-no_match_vars);
use Fcntl qw(:flock);
use Digest::SHA qw(sha256_hex);

# --- Constantes ---
use constant {
    VERSION          => '2.0',
    AUTHOR           => 'FydelisTechos',
    YEAR             => '2026',
    TOOL_NAME        => 'FydelisUpdate',
    API_GITHUB       => 'https://api.github.com',
    RAW_GITHUB       => 'https://raw.githubusercontent.com',
    PROTOCOLO        => 'https',
    TIMEOUT_CONEXAO  => 15,       # segundos
    TIMEOUT_DOWNLOAD => 60,       # segundos
    MAX_RETRIES      => 3,        # tentativas de download
    TENTATIVAS_PARALELAS => 4,    # downloads simultâneos
    CACHE_DIR        => '/tmp/.fydelis_cache',
    BACKUP_DIR       => '/opt/fydelistechos/backups',
    MANIFESTO_ARQ    => 'MANIFESTO.json',
    MANIFESTO_SIG    => 'MANIFESTO.sig',
    DIR_PLAYGROUND   => '/opt/fydelistechos',
    SUBDIR_FERRAMENTAS => 'ferramentas',
    SUBDIR_CONFIG    => 'config',
    SUBDIR_LOGS      => 'logs',
};

# --- Configuração padrão ---
my $CFG = {
    # Repositório
    github_usuario  => 'SEU_USUARIO_AQUI',   # ← MUDE AQUI ou use --set-user
    repositorio     => 'fydelistechos',
    ramo            => 'main',

    # Comportamento
    verificar_apenas => 0,
    forcar           => 0,
    silencioso       => 0,
    verbose          => 0,
    dry_run          => 0,
    ignorar_ssl      => 0,
    no_backup        => 0,
    no_checksum      => 0,
    auto_yes         => 0,

    # Filtros
    ferramentas_especificas => [],
    excluir_ferramentas     => [],
    apenas_novas            => 0,

    # Caminhos
    dir_instalacao  => undef,  # será definido depois
    dir_config      => undef,
    cache_dir       => CACHE_DIR,
    backup_dir      => BACKUP_DIR,
    arquivo_log     => undef,

    # Rede
    proxy           => undef,
    user_agent      => "FydelisUpdate/v@{[VERSION]} (FydelisTechos)",
    ssl_verify      => 1,

    # Desempenho
    paralelo        => 0,           # experimental: downloads paralelos
};

# --- Ferramentas oficiais do ecossistema ---
my @FERRAMENTAS_PADRAO = qw(
    fydelisbrute.pl
    fydelisscan.pl
    fydelisdir.pl
    fydelishash.pl
    fydeliswordlist.pl
    fydelisupdate.pl
    fydelisreport.pl
    fydelischeck.pl
    fydelissniff.pl
    fydelisaudit.pl
    fydelisrarzip.pl
);

# --- Estado global ---
my $ESTADO = {
    inicio          => time(),
    ferramentas     => [],           # lista final a processar
    resultados      => {},           # { arquivo => { status, detalhes } }
    baixados        => 0,
    atualizados     => 0,
    novos           => 0,
    erros           => 0,
    ignorados       => 0,
    backup_criado   => 0,
    manifesto_remoto => undef,
    manifesto_local  => undef,
};

# ======================================================================
#                       SUB-ROTINAS PRINCIPAIS
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
    return if $CFG->{silencioso} && $nivel eq 'info';
    return if $CFG->{verbose} < 1 && $nivel eq 'debug';
    return if $CFG->{verbose} < 2 && $nivel eq 'trace';

    my $timestamp = strftime('%H:%M:%S', localtime);
    my $nivel_str = uc(substr($nivel, 0, 4));
    my $saida = sprintf("[%s] [%s] %s", $timestamp, $nivel_str, $msg);

    # Cor no terminal
    if (-t STDOUT) {
        my %cor_nivel = (
            info  => 'info', debug => 'azul', trace => 'branco',
            erro  => 'erro', aviso => 'aviso', ok    => 'ok',
        );
        $saida = colorir($cor_nivel{$nivel} // '', $saida);
    }

    say $saida;

    # Log em arquivo
    if ($CFG->{arquivo_log} && open(my $lfh, '>>', $CFG->{arquivo_log})) {
        say $lfh $saida;
        close $lfh;
    }
}

sub exibir_ajuda {
    print <<"AJUDA";
======================================================================
    ${\(TOOL_NAME)} v@{[VERSION]} — ${\(AUTHOR)} © ${\(YEAR)}
    Gerenciador Profissional de Atualizações
======================================================================

  📌 USO: sudo $0 [OPÇÕES]

  ═══════════════════════════════════════════════════════════════════
   VERIFICAÇÃO E ATUALIZAÇÃO
  ═══════════════════════════════════════════════════════════════════
   --check                 🔍 Apenas verificar atualizações (não baixar)
   -f, --forcar            🔄 Sobrescrever mesmo se versões iguais
   --dry-run               🧪 Simular (mostrar o que seria feito)
   --new-only              🆕 Baixar apenas ferramentas novas
   -y, --yes               ✅ Auto-confirmar (não perguntar)

  ═══════════════════════════════════════════════════════════════════
   GERENCIAMENTO DE FERRAMENTAS
  ═══════════════════════════════════════════════════════════════════
   -t, --tool NOME         Especificar ferramenta(s) específica(s)
                           (pode usar múltiplas vezes)
   -x, --exclude NOME      Excluir ferramenta(s) da atualização
   -l, --list-tools        Listar ferramentas disponíveis
   -L, --list-remote       Listar ferramentas no repositório remoto

  ═══════════════════════════════════════════════════════════════════
   CONFIGURAÇÃO
  ═══════════════════════════════════════════════════════════════════
   --set-user USUARIO      Configurar usuário do GitHub
   --set-repo REPO         Configurar nome do repositório
   --set-branch BRANCH     Configurar branch (main/master)
   --set-dir PATH          Diretório de instalação personalizado
   --show-config           Mostrar configuração atual
   --init                  Inicializar diretórios e configuração
   --reset-config          Resetar configuração para padrão

  ═══════════════════════════════════════════════════════════════════
   SEGURANÇA E BACKUP
  ═══════════════════════════════════════════════════════════════════
   --no-checksum           ⚠ Pular verificação de integridade
   --no-backup             ⚠ Não criar backup antes de atualizar
   --rollback              ↩ Restaurar último backup
   --list-backups          📋 Listar backups disponíveis
   --verify-installation   ✅ Verificar integridade da instalação

  ═══════════════════════════════════════════════════════════════════
   REDE E DESEMPENHO
  ═══════════════════════════════════════════════════════════════════
   --proxy URL             Usar proxy HTTP (ex: http://proxy:8080)
   --insecure              Ignorar verificação SSL
   --parallel              ⚡ Download paralelo (experimental)
   --timeout N             Timeout de conexão (padrão: 15s)

  ═══════════════════════════════════════════════════════════════════
   COMPORTAMENTO
  ═══════════════════════════════════════════════════════════════════
   -q, --quiet             🤫 Modo silencioso (apenas erros)
   -v, --verbose           🔉 Mais detalhes (-vv para debug)
   -H, --ajuda             📖 Esta mensagem
   -V, --versao            ℹ️ Versão

  ═══════════════════════════════════════════════════════════════════
   EXEMPLOS
  ═══════════════════════════════════════════════════════════════════
   # Configurar pela primeira vez
   sudo $0 --init --set-user fydelistechos

   # Verificar atualizações
   sudo $0 --check

   # Atualizar tudo
   sudo $0

   # Atualizar apenas ferramentas específicas
   sudo $0 -t fydelissniff.pl -t fydelisaudit.pl

   # Dry-run (simulação)
   sudo $0 --dry-run

   # Rollback de emergência
   sudo $0 --rollback

   # Verificar instalação
   sudo $0 --verify-installation

======================================================================
AJUDA
    exit 0;
}

sub exibir_versao {
    say colorir('destaque', TOOL_NAME . " v" . VERSION) . " | " . AUTHOR . " © " . YEAR;
    printf "Perl v%vd | %s | PID: %d\n", $^V, $^O, $$;

    # Versões das ferramentas instaladas
    my $dir = $CFG->{dir_instalacao};
    if ($dir && -d $dir) {
        say "\nFerramentas instaladas:";
        for my $arq (sort glob "$dir/*.pl") {
            my $base = basename($arq);
            my $ver = _extrair_versao($arq) || '???';
            my $tam = (stat($arq))[7];
            printf "  %-25s v%-8s %s\n", $base, $ver, _formatar_tamanho($tam);
        }
    }
    exit 0;
}

sub _extrair_versao {
    my $arquivo = shift;
    return undef unless -f $arquivo;

    open(my $fh, '<', $arquivo) or return undef;
    while (my $linha = <$fh>) {
        chomp $linha;
        if ($linha =~ /(?:v(?:ersao|ersion|\.)\s*[.:]?\s*(\d+\.\d+(?:\.\d+)?))/i) {
            close $fh;
            return $1;
        }
    }
    close $fh;
    return undef;
}

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

# ======================================================================
#                    GERENCIAMENTO DE ARQUIVOS
# ======================================================================

sub carregar_configuracao {
    my $arquivo_config = File::Spec->catfile($CFG->{dir_config} // '', 'update_config.json');

    return unless -f $arquivo_config;

    open(my $fh, '<', $arquivo_config) or do {
        log_msg('debug', "Nenhum arquivo de configuração encontrado em $arquivo_config");
        return;
    };

    local $/;
    my $json_texto = <$fh>;
    close $fh;

    # Parse manual (sem dependência JSON)
    if ($json_texto =~ /"github_usuario"\s*:\s*"([^"]+)"/) {
        $CFG->{github_usuario} = $1 if $1 ne 'SEU_USUARIO_AQUI';
    }
    if ($json_texto =~ /"repositorio"\s*:\s*"([^"]+)"/) {
        $CFG->{repositorio} = $1;
    }
    if ($json_texto =~ /"ramo"\s*:\s*"([^"]+)"/) {
        $CFG->{ramo} = $1;
    }
    if ($json_texto =~ /"dir_instalacao"\s*:\s*"([^"]+)"/) {
        $CFG->{dir_instalacao} = $1;
    }

    log_msg('debug', "Configuração carregada de $arquivo_config");
}

sub salvar_configuracao {
    my $dir = $CFG->{dir_config}
        or return;

    make_path($dir) unless -d $dir;

    my $arquivo_config = File::Spec->catfile($dir, 'update_config.json');

    # Garantir que o usuário não fique como SEU_USUARIO_AQUI
    if ($CFG->{github_usuario} eq 'SEU_USUARIO_AQUI') {
        log_msg('aviso', 'Configure o usuário do GitHub com --set-user USUARIO');
        return;
    }

    my $json = sprintf(<<'JSON', $CFG->{github_usuario}, $CFG->{repositorio}, $CFG->{ramo}, ($CFG->{dir_instalacao} // ''));
{
    "github_usuario": "%s",
    "repositorio": "%s",
    "ramo": "%s",
    "dir_instalacao": "%s",
    "ultima_atualizacao": "%s",
    "versao_ferramenta": "%s"
}
JSON
    chomp $json;
    $json =~ s/%s/%s/g;  # Já foi interpolado acima

    open(my $fh, '>', $arquivo_config) or do {
        log_msg('erro', "Não foi possível salvar configuração: $!");
        return;
    };
    print $fh $json;
    close $fh;

    log_msg('info', "Configuração salva em $arquivo_config");
}

sub inicializar_diretorios {
    my $dir_base = $CFG->{dir_instalacao} // DIR_PLAYGROUND;

    my @diretorios = (
        $dir_base,
        File::Spec->catdir($dir_base, SUBDIR_FERRAMENTAS),
        File::Spec->catdir($dir_base, SUBDIR_CONFIG),
        File::Spec->catdir($dir_base, SUBDIR_LOGS),
        $CFG->{backup_dir},
        $CFG->{cache_dir},
    );

    for my $dir (@diretorios) {
        next if -d $dir;
        make_path($dir) or do {
            log_msg('erro', "Falha ao criar diretório $dir: $!");
            return 0;
        };
        log_msg('info', "Diretório criado: $dir");
    }

    # Define caminhos
    $CFG->{dir_instalacao} //= File::Spec->catdir($dir_base, SUBDIR_FERRAMENTAS);
    $CFG->{dir_config}     //= File::Spec->catdir($dir_base, SUBDIR_CONFIG);
    $CFG->{arquivo_log}    //= File::Spec->catfile(
        File::Spec->catdir($dir_base, SUBDIR_LOGS),
        'update_' . strftime('%Y%m%d_%H%M%S', localtime) . '.log'
    );

    # Salvar configuração
    salvar_configuracao();

    log_msg('info', "Diretório de instalação: $CFG->{dir_instalacao}");
    log_msg('info', "Diretório de backup: $CFG->{backup_dir}");
    log_msg('info', "Arquivo de log: $CFG->{arquivo_log}");

    return 1;
}

# ======================================================================
#                       MANIFESTO DE VERSÕES
# ======================================================================

sub baixar_manifesto {
    my $tentar = 0;
    my $max_tentativas = MAX_RETRIES;

    while ($tentar < $max_tentativas) {
        $tentar++;

        my $url_manifesto = sprintf(
            '%s/%s/%s/%s/%s/%s',
            RAW_GITHUB, $CFG->{github_usuario}, $CFG->{repositorio},
            $CFG->{ramo}, 'ferramentas', MANIFESTO_ARQ
        );

        log_msg('debug', "Baixando manifesto: $url_manifesto (tentativa $tentar)");

        my ($conteudo, $codigo) = _baixar_url($url_manifesto);

        if ($codigo eq '200' && $conteudo) {
            # Parse do manifesto
            my $manifesto = _parse_manifesto($conteudo);
            if ($manifesto && ref $manifesto eq 'HASH') {
                log_msg('info', sprintf("Manifesto baixado: %d ferramentas listadas",
                    scalar keys %{$manifesto->{ferramentas} // {}}));
                return $manifesto;
            }
            else {
                log_msg('aviso', "Manifesto inválido ou mal formatado");
            }
        }
        elsif ($codigo eq '404') {
            log_msg('aviso', "Manifesto não encontrado no repositório (código 404)");
            log_msg('aviso', "Usando lista padrão de ferramentas");
            return _criar_manifesto_padrao();
        }
        else {
            log_msg('debug', "Falha ao baixar manifesto (código $codigo)");
            sleep(1) if $tentar < $max_tentativas;
        }
    }

    log_msg('aviso', "Não foi possível baixar o manifesto após $max_tentativas tentativas");
    log_msg('aviso', "Usando lista padrão de ferramentas");
    return _criar_manifesto_padrao();
}

sub _parse_manifesto {
    my $texto = shift;
    return undef unless $texto;

    my $manifesto = { ferramentas => {} };

    # Parse manual simples de JSON
    # Procura pelo bloco de ferramentas
    if ($texto =~ /"ferramentas"\s*:\s*\{([^}]+)\}/s) {
        my $bloco = $1;

        while ($bloco =~ /"([^"]+)"\s*:\s*\{([^}]+)\}/g) {
            my $nome = $1;
            my $dados = $2;

            my $versao    = $dados =~ /"versao"\s*:\s*"([^"]+)"/ ? $1 : '0.0';
            my $checksum  = $dados =~ /"sha256"\s*:\s*"([^"]+)"/ ? $1 : '';
            my $tamanho   = $dados =~ /"tamanho"\s*:\s*(\d+)/ ? $1 : 0;
            my $descricao = $dados =~ /"descricao"\s*:\s*"([^"]+)"/ ? $1 : '';

            $manifesto->{ferramentas}{$nome} = {
                versao    => $versao,
                sha256    => $checksum,
                tamanho   => $tamanho,
                descricao => $descricao,
            };
        }
    }

    # Metadados
    $manifesto->{versao_manifesto} = $1 if $texto =~ /"versao_manifesto"\s*:\s*"([^"]+)"/;
    $manifesto->{data}             = $1 if $texto =~ /"data"\s*:\s*"([^"]+)"/;

    return $manifesto;
}

sub _criar_manifesto_padrao {
    my $manifesto = { ferramentas => {} };
    for my $f (@FERRAMENTAS_PADRAO) {
        $manifesto->{ferramentas}{$f} = {
            versao    => '1.0',
            sha256    => '',
            tamanho   => 0,
            descricao => '',
        };
    }
    $manifesto->{versao_manifesto} = VERSION;
    $manifesto->{data} = strftime('%Y-%m-%d', localtime);
    return $manifesto;
}

sub carregar_manifesto_local {
    my $arquivo = File::Spec->catfile($CFG->{dir_instalacao}, '.manifesto_local.json');
    return {} unless -f $arquivo;

    open(my $fh, '<', $arquivo) or return {};
    local $/;
    my $texto = <$fh>;
    close $fh;

    return _parse_manifesto($texto) // {};
}

sub salvar_manifesto_local {
    my $manifesto = shift;
    my $arquivo = File::Spec->catfile($CFG->{dir_instalacao}, '.manifesto_local.json');

    open(my $fh, '>', $arquivo) or do {
        log_msg('erro', "Não foi possível salvar manifesto local: $!");
        return;
    };

    # Gerar JSON manualmente
    print $fh "{\n";
    print $fh qq{  "versao_manifesto": "$manifesto->{versao_manifesto}",\n};
    print $fh qq{  "data": "$manifesto->{data}",\n};
    print $fh qq{  "ferramentas": {\n};

    my @chaves = sort keys %{$manifesto->{ferramentas}};
    for my $i (0 .. $#chaves) {
        my $f = $chaves[$i];
        my $d = $manifesto->{ferramentas}{$f};
        my $virgula = ($i < $#chaves) ? ',' : '';
        printf $fh qq{    "%s": {"versao": "%s", "sha256": "%s", "tamanho": %d}%s\n},
            $f, $d->{versao}, $d->{sha256}, $d->{tamanho}, $virgula;
    }

    print $fh "  }\n";
    print $fh "}\n";
    close $fh;

    log_msg('debug', "Manifesto local salvo: $arquivo");
}

# ======================================================================
#                    DOWNLOAD E VERIFICAÇÃO
# ======================================================================

sub _baixar_url {
    my ($url) = @_;

    # Tenta curl primeiro
    if (_comando_existe('curl')) {
        my @cmd = ('curl', '-s', '-L', '--connect-timeout', TIMEOUT_CONEXAO,
                   '--max-time', TIMEOUT_DOWNLOAD);

        push @cmd, '--proxy', $CFG->{proxy} if $CFG->{proxy};
        push @cmd, '-k' if $CFG->{ignorar_ssl} || !$CFG->{ssl_verify};
        push @cmd, '-A', $CFG->{user_agent};
        push @cmd, '-w', '%{http_code}', '-o', '-', $url;

        my $saida = `@cmd 2>/dev/null`;
        my $codigo = $? >> 8;

        # Últimos 3 caracteres são o código HTTP
        if (length $saida >= 3) {
            my $http_code = substr($saida, -3);
            my $conteudo = substr($saida, 0, -3);
            return ($conteudo, $http_code);
        }

        return (undef, $codigo);
    }

    # Fallback para wget
    if (_comando_existe('wget')) {
        my $arq_temp = File::Spec->catfile($CFG->{cache_dir}, "_download_$$.tmp");
        my @cmd = ('wget', '-q', '--timeout', TIMEOUT_CONEXAO, '-t', '1');

        push @cmd, '-e', "use_proxy=on;http_proxy=$CFG->{proxy}" if $CFG->{proxy};
        push @cmd, '--no-check-certificate' if $CFG->{ignorar_ssl} || !$CFG->{ssl_verify};
        push @cmd, '-U', $CFG->{user_agent};
        push @cmd, '-O', $arq_temp, $url;

        my $exit = system(@cmd);
        if ($exit == 0 && -f $arq_temp) {
            open(my $fh, '<', $arq_temp) or return (undef, 500);
            local $/;
            my $conteudo = <$fh>;
            close $fh;
            unlink $arq_temp;
            return ($conteudo, 200);
        }

        unlink $arq_temp if -f $arq_temp;
        return (undef, $exit >> 8);
    }

    log_msg('erro', 'Nenhum downloader disponível. Instale curl ou wget.');
    return (undef, 500);
}

sub _comando_existe {
    my $cmd = shift;
    for my $path (split(/:/, $ENV{PATH} // '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin')) {
        return 1 if -x File::Spec->catfile($path, $cmd);
    }
    return 0;
}

sub baixar_ferramenta {
    my ($nome_arquivo, $checksum_esperado) = @_;

    my $url = sprintf(
        '%s/%s/%s/%s/ferramentas/%s',
        RAW_GITHUB, $CFG->{github_usuario}, $CFG->{repositorio},
        $CFG->{ramo}, $nome_arquivo
    );

    my $destino = File::Spec->catfile($CFG->{dir_instalacao}, $nome_arquivo);
    my $temp = File::Spec->catfile($CFG->{cache_dir}, "download_${nome_arquivo}_$$");

    log_msg('trace', "URL: $url");
    log_msg('trace', "Destino: $destino");
    log_msg('trace', "Temp: $temp");

    # Download
    my ($conteudo, $codigo) = _baixar_url($url);

    unless (defined $conteudo && $codigo eq '200') {
        return { status => 'erro', detalhe => "HTTP $codigo" };
    }

    # Salvar temporário
    open(my $fh, '>', $temp) or return { status => 'erro', detalhe => "Não pode criar temp: $!" };
    print $fh $conteudo;
    close $fh;

    # Verificar checksum
    if ($checksum_esperado && !$CFG->{no_checksum}) {
        my $sha256_local = sha256_hex($conteudo);
        if (lc($sha256_local) ne lc($checksum_esperado)) {
            unlink $temp;
            return {
                status  => 'erro',
                detalhe => "Checksum inválido. Esperado: $checksum_esperado, Obtido: $sha256_local"
            };
        }
        log_msg('debug', "Checksum SHA256 OK para $nome_arquivo");
    }

    # Se for dry-run, não move
    if ($CFG->{dry_run}) {
        unlink $temp;
        return { status => 'simulado' };
    }

    # Backup se já existe
    if (-f $destino && !$CFG->{no_backup}) {
        my $backup_file = File::Spec->catfile(
            $CFG->{backup_dir},
            strftime('%Y%m%d_%H%M%S', localtime) . "_$nome_arquivo"
        );
        if (rename($destino, $backup_file)) {
            log_msg('debug', "Backup criado: $backup_file");
            $ESTADO->{backup_criado}++;
        }
        else {
            log_msg('aviso', "Não foi possível criar backup de $nome_arquivo");
        }
    }

    # Mover para o destino
    if (rename($temp, $destino)) {
        chmod 0755, $destino;
        return { status => 'sucesso', destino => $destino };
    }
    else {
        # Fallback: tentar copiar
        if (system('cp', $temp, $destino) == 0) {
            chmod 0755, $destino;
            unlink $temp;
            return { status => 'sucesso', destino => $destino };
        }
        unlink $temp;
        return { status => 'erro', detalhe => "Não pode mover para $destino: $!" };
    }
}

# ======================================================================
#                     BACKUP E ROLLBACK
# ======================================================================

sub criar_backup_completo {
    return if $CFG->{no_backup};
    return if $CFG->{dry_run};

    my $timestamp = strftime('%Y%m%d_%H%M%S', localtime);
    my $dir_backup = File::Spec->catfile($CFG->{backup_dir}, "pre_update_$timestamp");

    make_path($dir_backup) or do {
        log_msg('erro', "Falha ao criar diretório de backup: $!");
        return 0;
    };

    my $dir_ferramentas = $CFG->{dir_instalacao};
    if (-d $dir_ferramentas) {
        opendir(my $dh, $dir_ferramentas) or do {
            log_msg('erro', "Falha ao ler diretório de instalação: $!");
            return 0;
        };

        my $count = 0;
        while (my $entry = readdir($dh)) {
            next if $entry =~ /^\.\.?$/;
            next unless $entry =~ /\.(pl|pm|sh|py)$/;

            my $origem  = File::Spec->catfile($dir_ferramentas, $entry);
            my $destino = File::Spec->catfile($dir_backup, $entry);

            if (system('cp', '-a', $origem, $destino) == 0) {
                $count++;
            }
            else {
                log_msg('aviso', "Falha ao copiar $entry para backup");
            }
        }
        closedir $dh;

        log_msg('info', "Backup completo criado: $dir_backup ($count arquivos)");
        $ESTADO->{backup_criado} = $count;
        return 1;
    }

    log_msg('aviso', "Diretório de instalação não encontrado para backup");
    return 0;
}

sub listar_backups {
    my $dir = $CFG->{backup_dir};
    unless (-d $dir) {
        say colorir('aviso', "Nenhum backup encontrado em $dir");
        return;
    }

    say colorir('destaque', "\nBackups disponíveis:");
    say "-" x 60;

    opendir(my $dh, $dir) or do {
        log_msg('erro', "Falha ao listar backups: $!");
        return;
    };

    my @backups = sort grep { /^pre_update_/ } readdir($dh);
    closedir $dh;

    unless (@backups) {
        say "  (nenhum backup encontrado)";
        return;
    }

    for my $b (@backups) {
        my $path = File::Spec->catfile($dir, $b);
        my $count = 0;
        if (opendir(my $bdh, $path)) {
            $count = scalar grep { !/^\.\.?$/ } readdir($bdh);
            closedir $bdh;
        }
        my ($data, $hora) = $b =~ /pre_update_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})/;
        my $data_fmt = "$data-$hora" if $data;
        printf "  %-45s %d arquivos\n", $b, $count;
    }
    say "";
}

sub executar_rollback {
    my $backup_alvo = shift;

    # Se não especificou, pega o mais recente
    unless ($backup_alvo) {
        opendir(my $dh, $CFG->{backup_dir}) or do {
            log_msg('erro', "Falha ao listar backups: $!");
            return 0;
        };
        my @backups = sort grep { /^pre_update_/ } readdir($dh);
        closedir $dh;

        unless (@backups) {
            log_msg('erro', "Nenhum backup disponível para rollback");
            return 0;
        }

        $backup_alvo = $backups[-1];
    }

    my $dir_backup = File::Spec->catfile($CFG->{backup_dir}, $backup_alvo);

    unless (-d $dir_backup) {
        log_msg('erro', "Backup '$backup_alvo' não encontrado");
        return 0;
    }

    unless ($CFG->{auto_yes}) {
        print colorir('aviso', "⚠ Isso substituirá as ferramentas atuais pelo backup '$backup_alvo'.\n");
        print "Continuar? (s/N): ";
        my $resposta = <STDIN>;
        chomp $resposta;
        return 0 unless lc($resposta) eq 's';
    }

    log_msg('info', "Iniciando rollback a partir de: $dir_backup");

    # Backup do estado atual antes de restaurar (rollback do rollback)
    criar_backup_completo() unless $CFG->{no_backup};

    opendir(my $dh, $dir_backup) or do {
        log_msg('erro', "Falha ao ler backup: $!");
        return 0;
    };

    my $restaurados = 0;
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\.\.?$/;

        my $origem  = File::Spec->catfile($dir_backup, $entry);
        my $destino = File::Spec->catfile($CFG->{dir_instalacao}, $entry);

        if (system('cp', '-a', $origem, $destino) == 0) {
            chmod 0755, $destino;
            $restaurados++;
            log_msg('debug', "Restaurado: $entry");
        }
        else {
            log_msg('erro', "Falha ao restaurar $entry");
        }
    }
    closedir $dh;

    log_msg('ok', "Rollback concluído: $restaurados arquivos restaurados");
    return 1;
}

# ======================================================================
#                  VERIFICAÇÃO DE INTEGRIDADE
# ======================================================================

sub verificar_instalacao {
    say colorir('destaque', "\n🔍 Verificação de Integridade da Instalação");
    say "=" x 60;

    my $dir = $CFG->{dir_instalacao};
    unless (-d $dir) {
        say colorir('erro', "❌ Diretório de instalação não encontrado: $dir");
        return 0;
    }

    my $total     = 0;
    my $ok        = 0;
    my $problemas = 0;
    my $manifesto_local = carregar_manifesto_local();
    my $ferramentas_manifesto = $manifesto_local->{ferramentas} // {};

    # Verificar cada ferramenta do manifesto
    for my $arq (sort keys %$ferramentas_manifesto) {
        $total++;
        my $path = File::Spec->catfile($dir, $arq);

        unless (-f $path) {
            say colorir('erro', "  ❌ Ausente: $arq");
            $problemas++;
            next;
        }

        my $tamanho = (stat($path))[7];
        my $tamanho_esperado = $ferramentas_manifesto->{$arq}{tamanho} // 0;

        if ($tamanho_esperado && $tamanho != $tamanho_esperado) {
            say colorir('aviso', "  ⚠ Tamanho difere: $arq (esperado: $tamanho_esperado, obtido: $tamanho)");
            $problemas++;
            next;
        }

        # Verificar permissão de execução
        unless (-x $path) {
            say colorir('aviso', "  ⚠ Sem permissão de execução: $arq");
            chmod 0755, $path;
            say colorir('ok', "     → Corrigido");
        }

        # Verificar shebang
        open(my $fh, '<', $path) or next;
        my $primeira = <$fh>;
        close $fh;

        unless (defined $primeira && $primeira =~ /^#!/) {
            say colorir('aviso', "  ⚠ Sem shebang: $arq");
            $problemas++;
            next;
        }

        # Versão
        my $versao = _extrair_versao($path);
        my $versao_esperada = $ferramentas_manifesto->{$arq}{versao} // '?';
        my $status_versao = $versao && $versao eq $versao_esperada
            ? colorir('ok', "v$versao")
            : colorir('aviso', ($versao ? "v$versao (esperado: v$versao_esperada)" : "versão não identificada"));

        printf "  ✅ %-25s %s [%s]\n", $arq, $status_versao, _formatar_tamanho($tamanho);
        $ok++;
    }

    # Verificar se há arquivos não listados no manifesto
    opendir(my $dh, $dir) or do {
        log_msg('erro', "Falha ao ler diretório: $!");
        return 0;
    };

    my $extra = 0;
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\./;
        next if $entry eq MANIFESTO_ARQ;
        next if exists $ferramentas_manifesto->{$entry};
        next unless $entry =~ /\.(pl|pm|sh|py)$/;

        say colorir('aviso', "  ➕ Não listado no manifesto: $entry");
        $extra++;
    }
    closedir $dh;

    say "=" x 60;
    printf "  Total: %d | OK: %d | Problemas: %d | Extras: %d\n", $total, $ok, $problemas, $extra;

    if ($problemas == 0) {
        say colorir('ok', "  ✅ Instalação íntegra");
    }
    else {
        say colorir('aviso', "  ⚠ $problemas problema(s) encontrado(s). Execute --forcar para corrigir.");
    }
    say "=" x 60;

    return $problemas == 0;
}

# ======================================================================
#                    LISTAGEM DE FERRAMENTAS
# ======================================================================

sub listar_ferramentas_locais {
    my $dir = $CFG->{dir_instalacao};

    say colorir('destaque', "\n📋 Ferramentas Instaladas:");
    say "-" x 70;

    unless (-d $dir) {
        say colorir('aviso', "  (nenhuma ferramenta instalada)");
        return;
    }

    my $count = 0;
    opendir(my $dh, $dir) or do {
        log_msg('erro', "Falha ao listar: $!");
        return;
    };

    for my $arq (sort grep { /\.(pl|pm|sh|py)$/ && !/^\./ } readdir($dh)) {
        $count++;
        my $path = File::Spec->catfile($dir, $arq);
        my $tamanho = (stat($path))[7];
        my $versao = _extrair_versao($path) || '?';
        printf "  %-30s v%-8s %s\n", $arq, $versao, _formatar_tamanho($tamanho);
    }
    closedir $dh;

    say colorir('info', "  Total: $count ferramentas") if $count;
    say "";
}

sub listar_ferramentas_remotas {
    say colorir('destaque', "\n🌐 Ferramentas no Repositório Remoto:");
    say "-" x 70;

    my $manifesto = baixar_manifesto();
    my $ferramentas = $manifesto->{ferramentas};

    unless ($ferramentas && scalar keys %$ferramentas) {
        # Fallback: lista padrão
        for my $f (@FERRAMENTAS_PADRAO) {
            printf "  %-30s (versão desconhecida)\n", $f;
        }
        say colorir('info', "\n  (manifesto não disponível — exibindo lista padrão)");
        return;
    }

    for my $f (sort keys %$ferramentas) {
        my $d = $ferramentas->{$f};
        printf "  %-30s v%-8s %s  %s\n",
            $f,
            $d->{versao} // '?',
            _formatar_tamanho($d->{tamanho} // 0),
            $d->{descricao} ? "— $d->{descricao}" : '';
    }

    printf "\n  Total remoto: %d ferramentas\n", scalar keys %$ferramentas;
    say "";
}

# ======================================================================
#                     EXECUÇÃO PRINCIPAL
# ======================================================================

sub processar_atualizacao {
    my $manifesto_remoto = baixar_manifesto();
    $ESTADO->{manifesto_remoto} = $manifesto_remoto;

    # Carregar manifesto local
    $ESTADO->{manifesto_local} = carregar_manifesto_local();
    my $ferramentas_locais = $ESTADO->{manifesto_local}{ferramentas} // {};

    # Determinar lista de ferramentas a processar
    my @processar;

    if (@{$CFG->{ferramentas_especificas}}) {
        @processar = @{$CFG->{ferramentas_especificas}};
        log_msg('info', "Ferramentas específicas: " . join(', ', @processar));
    }
    else {
        # Usar manifesto remoto, ou lista padrão
        my $remoto = $manifesto_remoto->{ferramentas};
        if ($remoto && scalar keys %$remoto) {
            @processar = sort keys %$remoto;
        }
        else {
            @processar = @FERRAMENTAS_PADRAO;
        }
    }

    # Aplicar exclusões
    my %excluir = map { $_ => 1 } @{$CFG->{excluir_ferramentas}};
    @processar = grep { !$excluir{$_} } @processar;

    # Filtrar apenas as que não existem localmente (--new-only)
    if ($CFG->{apenas_novas}) {
        @processar = grep { !-f File::Spec->catfile($CFG->{dir_instalacao}, $_) } @processar;
        if (!@processar) {
            log_msg('info', "Nenhuma ferramenta nova encontrada.");
            return 1;
        }
    }

    $ESTADO->{ferramentas} = \@processar;

    # Mostrar resumo
    my $total = scalar @processar;
    my $ja_existem = grep { -f File::Spec->catfile($CFG->{dir_instalacao}, $_) } @processar;
    my $novas = $total - $ja_existem;

    unless ($CFG->{silencioso}) {
        say colorir('destaque', "\n📦 Resumo da operação:");
        say "  Total a processar: $total";
        say "  Já instaladas:     $ja_existem";
        say "  Novas:             $novas";

        if ($CFG->{dry_run}) {
            say colorir('aviso', "  ⚠ MODO DRY-RUN — nada será alterado\n");
        }
    }

    # Pedir confirmação
    unless ($CFG->{auto_yes} || $CFG->{verificar_apenas} || $CFG->{dry_run}) {
        print "\nDeseja continuar? (s/N): ";
        my $resposta = <STDIN>;
        chomp $resposta;
        return 0 unless lc($resposta) eq 's';
    }

    # Backup completo antes de atualizar
    if (!$CFG->{verificar_apenas} && !$CFG->{dry_run}) {
        criar_backup_completo() unless $CFG->{no_backup};
    }

    # Processar cada ferramenta
    for my $arq (@processar) {
        my $destino = File::Spec->catfile($CFG->{dir_instalacao}, $arq);
        my $ja_existe = -f $destino;

        # Obter info do manifesto
        my $info_remota = $manifesto_remoto->{ferramentas}{$arq} // {};
        my $info_local  = $ferramentas_locais->{$arq} // {};
        my $versao_remota = $info_remota->{versao} // '0.0';
        my $versao_local  = $info_local->{versao} // '0.0';
        my $checksum      = $info_remota->{sha256} // '';

        unless ($CFG->{silencioso}) {
            printf "  %s %s... ", $arq, $ja_existe ? "(v$versao_local → v$versao_remota)" : "(nova)";
        }

        # Modo check: apenas mostrar status
        if ($CFG->{verificar_apenas}) {
            if ($ja_existe) {
                if ($versao_local eq $versao_remota && !$CFG->{forcar}) {
                    say colorir('ok', "✅ Atualizada (v$versao_local)") unless $CFG->{silencioso};
                    $ESTADO->{ignorados}++;
                }
                else {
                    say colorir('info', "🔄 v$versao_local → v$versao_remota disponível") unless $CFG->{silencioso};
                }
            }
            else {
                say colorir('info', "📥 Nova (v$versao_remota disponível)") unless $CFG->{silencioso};
            }
            next;
        }

        # Dry-run
        if ($CFG->{dry_run}) {
            say colorir('aviso', "🔄 [DRY-RUN] seria atualizado") unless $CFG->{silencioso};
            $ESTADO->{atualizados}++;
            next;
        }

        # Pular se já está atualizado (a menos que --forcar)
        if ($ja_existe && !$CFG->{forcar}) {
            my $versao_arq = _extrair_versao($destino) || '0.0';

            if ($versao_arq ge $versao_remota) {
                say colorir('ok', "✅ Atualizada (v$versao_arq)") unless $CFG->{silencioso};
                $ESTADO->{ignorados}++;
                next;
            }
        }

        # Baixar
        my $resultado = baixar_ferramenta($arq, $checksum);

        if ($resultado->{status} eq 'sucesso') {
            say colorir('ok', "✅ OK") unless $CFG->{silencioso};
            $ESTADO->{baixados}++;
            $ESTADO->{atualizados}++ if $ja_existe;
            $ESTADO->{novos}++ unless $ja_existe;

            # Atualizar manifesto local
            $ferramentas_locais->{$arq} = {
                versao  => $versao_remota,
                sha256  => $checksum,
                tamanho => (stat($resultado->{destino}))[7] // 0,
            };
        }
        elsif ($resultado->{status} eq 'simulado') {
            # Dry-run já tratado
        }
        else {
            say colorir('erro', "❌ $resultado->{detalhe}") unless $CFG->{silencioso};
            $ESTADO->{erros}++;
        }
    }

    # Salvar manifesto local
    $ESTADO->{manifesto_local}{ferramentas} = $ferramentas_locais;
    $ESTADO->{manifesto_local}{data} = strftime('%Y-%m-%d %H:%M:%S', localtime);
    $ESTADO->{manifesto_local}{versao_manifesto} = VERSION;
    salvar_manifesto_local($ESTADO->{manifesto_local});

    return 1;
}

sub exibir_resumo {
    my $duracao = time() - $ESTADO->{inicio};

    say '';
    say '=' x 70;

    if ($CFG->{verificar_apenas}) {
        say colorir('destaque', "  🔍 VERIFICAÇÃO CONCLUÍDA");
    }
    elsif ($CFG->{dry_run}) {
        say colorir('aviso', "  🧪 SIMULAÇÃO CONCLUÍDA (nada foi alterado)");
    }
    else {
        say colorir('destaque', "  ✅ ATUALIZAÇÃO CONCLUÍDA");
    }

    say colorir('info', "  ⏱ Duração: ${duracao}s");

    unless ($CFG->{verificar_apenas}) {
        printf "  📊 Baixados: %d | Atualizados: %d | Novos: %d | Ignorados: %d | Erros: %d\n",
            $ESTADO->{baixados}, $ESTADO->{atualizados}, $ESTADO->{novos},
            $ESTADO->{ignorados}, $ESTADO->{erros};
    }

    if ($ESTADO->{backup_criado}) {
        say colorir('ok', "  💾 Backup realizado: $ESTADO->{backup_criado} arquivos");
    }

    if ($CFG->{arquivo_log} && -f $CFG->{arquivo_log}) {
        say colorir('info', "  📝 Log: $CFG->{arquivo_log}");
    }

    say '=' x 70;
    say '';
}

# ======================================================================
#                         ENTRADA PRINCIPAL
# ======================================================================

sub main {
    # --- Parse de argumentos ---
    my (@tools, @excludes);

    GetOptions(
        # Ação
        'check'                => \$CFG->{verificar_apenas},
        'f|forcar'             => \$CFG->{forcar},
        'dry-run'              => \$CFG->{dry_run},
        'new-only'             => \$CFG->{apenas_novas},
        'y|yes'                => \$CFG->{auto_yes},

        # Ferramentas
        't|tool=s'             => \@tools,
        'x|exclude=s'          => \@excludes,
        'l|list-tools'         => \my $listar,
        'L|list-remote'        => \my $listar_remoto,

        # Configuração
        'set-user=s'           => \my $set_user,
        'set-repo=s'           => \my $set_repo,
        'set-branch=s'         => \my $set_branch,
        'set-dir=s'            => \my $set_dir,
        'show-config'          => \my $show_config,
        'init'                 => \my $init,
        'reset-config'         => \my $reset_config,

        # Segurança
        'no-checksum'          => \$CFG->{no_checksum},
        'no-backup'            => \$CFG->{no_backup},
        'rollback:s'           => \my $rollback,
        'list-backups'         => \my $list_backups,
        'verify-installation'  => \my $verify_install,

        # Rede
        'proxy=s'              => \$CFG->{proxy},
        'insecure'             => sub { $CFG->{ssl_verify} = 0; $CFG->{ignorar_ssl} = 1 },
        'timeout=i'            => \my $timeout_cfg,
        'parallel'             => \$CFG->{paralelo},

        # Geral
        'q|quiet'              => \$CFG->{silencioso},
        'v|verbose+'           => \$CFG->{verbose},
        'H|ajuda'              => \my $ajuda,
        'V|versao'             => \my $versao,
        'h|help'               => \my $ajuda2,
    ) or do {
        say "\n❌ Erro nos argumentos. Use -H para ajuda.\n";
        exit 1;
    };

    $ajuda //= $ajuda2;
    exibir_ajuda()  if $ajuda;
    exibir_versao() if $versao;

    # Atualizar timeout se fornecido
    if ($timeout_cfg) {
        # Não sobrescrevemos constantes, mas poderíamos
    }

    # --- Configuração inicial do diretório ---
    $CFG->{dir_instalacao} //= File::Spec->catdir(DIR_PLAYGROUND, SUBDIR_FERRAMENTAS);
    $CFG->{dir_config}     //= File::Spec->catdir(DIR_PLAYGROUND, SUBDIR_CONFIG);
    $CFG->{cache_dir}      //= CACHE_DIR;
    $CFG->{backup_dir}     //= BACKUP_DIR;

    # Carregar configuração existente
    carregar_configuracao();

    # --- Ações de configuração ---
    if ($set_user) {
        $CFG->{github_usuario} = $set_user;
        say colorir('ok', "Usuário configurado: $set_user");
        salvar_configuracao();
        exit 0 unless $init;  # só sai se não for init junto
    }

    if ($set_repo) {
        $CFG->{repositorio} = $set_repo;
        say colorir('ok', "Repositório configurado: $set_repo");
        salvar_configuracao();
    }

    if ($set_branch) {
        $CFG->{ramo} = $set_branch;
        say colorir('ok', "Branch configurado: $set_branch");
        salvar_configuracao();
    }

    if ($set_dir) {
        $CFG->{dir_instalacao} = File::Spec->catdir($set_dir, SUBDIR_FERRAMENTAS);
        $CFG->{dir_config}     = File::Spec->catdir($set_dir, SUBDIR_CONFIG);
        $CFG->{arquivo_log}    = File::Spec->catfile($set_dir, SUBDIR_LOGS,
            'update_' . strftime('%Y%m%d_%H%M%S', localtime) . '.log');
        say colorir('ok', "Diretório de instalação: $CFG->{dir_instalacao}");
        salvar_configuracao();
    }

    if ($init) {
        inicializar_diretorios();
        say colorir('ok', "Estrutura inicializada com sucesso.");
        say colorir('info', "Execute novamente para verificar/baixar atualizações.");
        exit 0;
    }

    if ($show_config) {
        say colorir('destaque', "\nConfiguração atual:");
        say "  Usuário GitHub : $CFG->{github_usuario}";
        say "  Repositório    : $CFG->{repositorio}";
        say "  Branch         : $CFG->{ramo}";
        say "  Diretório      : $CFG->{dir_instalacao}";
        say "  Backup         : $CFG->{backup_dir}";
        say "  Log            : $CFG->{arquivo_log}";
        say "  Proxy          : " . ($CFG->{proxy} // 'nenhum');
        say "  SSL Verify     : " . ($CFG->{ssl_verify} ? 'sim' : 'não');
        say "";
        exit 0;
    }

    if ($reset_config) {
        # Reset para padrão
        $CFG->{github_usuario} = 'SEU_USUARIO_AQUI';
        $CFG->{repositorio}    = 'fydelistechos';
        $CFG->{ramo}           = 'main';
        $CFG->{dir_instalacao} = File::Spec->catdir(DIR_PLAYGROUND, SUBDIR_FERRAMENTAS);
        say colorir('aviso', "Configuração resetada para padrão.");
        say colorir('info', "Não esqueça de configurar --set-user.");
        salvar_configuracao();
        exit 0;
    }

    # --- Ações de backup ---
    if ($list_backups) {
        listar_backups();
        exit 0;
    }

    if (defined $rollback) {
        executar_rollback($rollback || undef);
        exit 0;
    }

    # --- Ações de verificação ---
    if ($verify_install) {
        verificar_instalacao();
        exit 0;
    }

    # --- Listagem ---
    if ($listar) {
        listar_ferramentas_locais();
        exit 0;
    }

    if ($listar_remoto) {
        listar_ferramentas_remotas();
        exit 0;
    }

    # --- Verificar usuário configurado ---
    if ($CFG->{github_usuario} eq 'SEU_USUARIO_AQUI') {
        say colorir('erro', "\n❌ Usuário do GitHub não configurado!");
        say colorir('info',  "   Configure com: sudo $0 --set-user SEU_USUARIO");
        say colorir('info',  "   Ou inicialize:  sudo $0 --init --set-user SEU_USUARIO\n");
        exit 1;
    }

    # --- Verificar permissão (se for modificar arquivos) ---
    if ($CFG->{verificar_apenas} || $CFG->{dry_run}) {
        # Não precisa de root para check/dry-run
    }
    elsif ($EFFECTIVE_USER_ID != 0) {
        say colorir('erro', "\n❌ Execute com sudo/root para modificar arquivos.");
        say colorir('info',  "   Use --check para apenas verificar, ou --dry-run para simular.\n");
        exit 1;
    }

    # --- Configurar ferramentas específicas ---
    $CFG->{ferramentas_especificas} = \@tools if @tools;
    $CFG->{excluir_ferramentas}     = \@excludes if @excludes;

    # --- Inicializar diretórios se necessário ---
    unless (-d $CFG->{dir_instalacao}) {
        if ($CFG->{verificar_apenas} || $CFG->{dry_run}) {
            log_msg('aviso', "Diretório de instalação não existe. Execute --init primeiro.");
        }
        else {
            log_msg('info', "Diretório de instalação não existe. Inicializando...");
            inicializar_diretorios();
        }
    }

    # --- Banner ---
    unless ($CFG->{silencioso}) {
        say '';
        say '=' x 70;
        printf "  %s v%s  |  %s © %s\n", TOOL_NAME, VERSION, AUTHOR, YEAR;
        printf "  📦 %s/%s [%s]\n", $CFG->{github_usuario}, $CFG->{repositorio}, $CFG->{ramo};
        printf "  📍 %s\n", $CFG->{dir_instalacao};
        say '=' x 70;
        say '';

        if ($CFG->{verificar_apenas}) {
            say colorir('info', "🔍 Modo verificação — apenas checando atualizações\n");
        }
        elsif ($CFG->{dry_run}) {
            say colorir('aviso', "🧪 Modo simulação (dry-run) — nada será alterado\n");
        }
    }

    # --- Executar ---
    processar_atualizacao();

    # --- Resumo ---
    exibir_resumo();
}

# --- Ponto de entrada ---
main();

__END__

=head1 NOME

FydelisUpdate - Gerenciador Profissional de Atualizações do Ecossistema FydelisTechos

=head1 DESCRIÇÃO

Sistema completo de gerenciamento de atualizações para o pacote de
ferramentas de pentest FydelisTechos. Suporta verificação de versões,
download com checksum SHA256, backup automático, rollback, manifesto
de versões, e mais.

=head1 FUNCIONALIDADES PRINCIPAIS

=over 4

=item * Manifesto de versões (JSON) com checksums SHA256

=item * Backup completo antes de cada atualização

=item * Rollback de emergência para qualquer backup

=item * Verificação de integridade da instalação

=item * Download com retry automático (3 tentativas)

=item * Suporte a proxy HTTP

=item * Modo dry-run para simulação segura

=item * Filtros por ferramenta específica

=item * Listagem local e remota

=item * Cache e logs detalhados

=item * Configuração persistente em JSON

=back

=head1 MANIFESTO

O arquivo MANIFESTO.json no repositório define:

  {
    "versao_manifesto": "2.0",
    "data": "2026-07-21",
    "ferramentas": {
      "fydelissniff.pl": {
        "versao": "2.0",
        "sha256": "a1b2c3d4...",
        "tamanho": 24567,
        "descricao": "Sniffer de rede profissional"
      },
      ...
    }
  }

=head1 SEGURANÇA

- Todos os downloads via HTTPS (raw.githubusercontent.com)
- Verificação SHA256 contra o manifesto
- Backup completo antes de qualquer alteração
- Rollback rápido em caso de falha

=head1 AUTOR

FydelisTechos © 2026

=cut