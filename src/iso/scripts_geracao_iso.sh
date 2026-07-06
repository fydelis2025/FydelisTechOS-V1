#!/bin/bash
set -e

# Garantir privilégios de root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[1;31m❌ Execute este construtor de ISO como ROOT (sudo)!\033[0m"
    exit 1
fi

echo -e "\033[1;35m==================================================\033[0m"
echo -e "\033[1;35m    CONSTRUTOR LIVE-BUILD: FYDELISTECHOS OS       \033[0m"
echo -e "\033[1;35m==================================================\033[0m"

# 1. Instalar dependências necessárias no sistema host
if ! command -v lb &> /dev/null; then
    echo "⚙️ Instalando live-build e ferramentas de empacotamento..."
    apt update && apt install -y live-build debootstrap xorriso syslinux-utils rsync build-essential nasm g++ gcc make libutil-dev
fi

# Mapear o diretório real onde o projeto está guardado (evita o erro do ~/)
DIRETORIO_RAIZ="$(pwd)"

# Criar e acessar o diretório isolado de compilação da ISO
mkdir -p /opt/fydel-iso
cd /opt/fydel-iso

# Limpar configurações de builds anteriores para evitar conflitos
echo "🧹 Limpando ambiente de build anterior..."
lb clean --purge || true

# 2. Inicializar a estrutura oficial do live-build para Debian 12 Bookworm
echo "🏗️  Inicializando árvore do live-build para Debian 12 (64-bit)..."
lb config \
    --distribution bookworm \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --iso-application "Fydelistechos OS" \
    --iso-publisher "Fydelistechos" \
    --iso-volume "FYDEL_OS_1_0" \
    --bootloaders grub-pc \
    --archive-areas "main contrib non-free non-free-firmware"

# 3. Mapear e injetar todos os pacotes da sua lista_completa.txt
echo "📦 Importando lista_completa.txt para o Live-CD..."
if [ -f "$DIRETORIO_RAIZ/pacotes/lista_completa.txt" ]; then
    # Remove comentários e linhas vazias, transformando em lista limpa para o live-build
    grep -v '^#' "$DIRETORIO_RAIZ/pacotes/lista_completa.txt" | tr '\n' ' ' > config/package-lists/fydel.list.chroot
else
    # Fallback de segurança caso o arquivo não esteja no local correto
    echo "libreoffice firefox-esr gparted network-manager nmap metasploit-framework htop nano vim" > config/package-lists/fydel.list.chroot
fi

# 4. Estruturar a inclusão de arquivos customizados dentro do sistema (chroot)
echo "🚚 Injetando códigos-fonte, instalador e telas na árvore da ISO..."
MNT_CHROOT="config/includes.chroot"
mkdir -p "$MNT_CHROOT/opt/fydel"
mkdir -p "$MNT_CHROOT/usr/share/fydel/telas"
mkdir -p "$MNT_CHROOT/usr/local/bin"
mkdir -p "$MNT_CHROOT/etc/systemd/system"

# Copia os fontes do terminal para compilação posterior interna
rsync -a "$DIRETORIO_RAIZ/src/terminal/" "$MNT_CHROOT/opt/fydel/src/terminal/"
# Copia o script de permissões e gerenciador de pacotes
rsync -a "$DIRETORIO_RAIZ/src/sistema/" "$MNT_CHROOT/opt/fydel/src/sistema/"
# Copia as telas ASCII (Boas-vindas)
if [ -f "$DIRETORIO_RAIZ/src/telas/tela_boas_vindas.txt" ]; then
    cp "$DIRETORIO_RAIZ/src/telas/tela_boas_vindas.txt" "$MNT_CHROOT/usr/share/fydel/telas/"
fi
# Copia o instalador automático para a pasta de executáveis globais
if [ -f "$DIRETORIO_RAIZ/instalador/fydel-install.sh" ]; then
    cp "$DIRETORIO_RAIZ/instalador/fydel-install.sh" "$MNT_CHROOT/usr/local/bin/fydel-install"
    chmod +x "$MNT_CHROOT/usr/local/bin/fydel-install"
fi

# 5. Criar o Hook de compilação nativa (Roda dentro da criação do Debian)
echo "🔧 Criando script automatizado de pós-instalação (Chroot Hook)..."
mkdir -p config/hooks/normal
cat <<'EOF' > config/hooks/normal/0500-compilar-fydelterm.hook.chroot
#!/bin/bash
set -e

echo "=== Executando Hook Interno: Compilando Terminal Híbrido ==="
cd /opt/fydel/src/terminal/
make clean && make
make install # Instala em /usr/local/bin/fydelterm

echo "=== Configurando perfis de utilizadores e permissões ==="
chmod +x /opt/fydel/src/sistema/usuarios_permissoes.sh
/opt/fydel/src/sistema/usuarios_permissoes.sh

echo "=== Ativando o Gestor de Pacotes fydel-pkg ==="
chmod +x /opt/fydel/src/sistema/gerenciador_pacotes.sh
ln -sf /opt/fydel/src/sistema/gerenciador_pacotes.sh /usr/local/bin/fydel-pkg

echo "=== Ativando o fydelterm.service no TTY1 ==="
if [ -f /opt/fydel/src/sistema/servicos_systemd/fydelterm.service ]; then
    cp /opt/fydel/src/sistema/servicos_systemd/fydelterm.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable fydelterm.service
fi

echo "=== Configurando Tema do GRUB ==="
mkdir -p /boot/grub/themes/grub-theme-fydel
if [ -d /opt/fydel/src/sistema/grub/grub-theme-fydel ]; then
    cp -r /opt/fydel/src/sistema/grub/grub-theme-fydel/* /boot/grub/themes/grub-theme-fydel/
    sed -i 's/#GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080,1280x720,auto/' /etc/default/grub
    echo 'GRUB_THEME="/boot/grub/themes/grub-theme-fydel/theme.txt"' >> /etc/default/grub
fi

# Adicionar instrução de ajuda no terminal padrão do usuário root no Live-CD
echo -e "\nif [ -f /usr/share/fydel/telas/tela_boas_vindas.txt ]; then cat /usr/share/fydel/telas/tela_boas_vindas.txt; fi" >> /root/.bashrc
echo -e "echo -e '\\n\\033[1;35mPara instalar o FydelisTechOS no disco rígido, digite: \\033[1;32mfydel-install\\033[0m\\n'" >> /root/.bashrc
EOF

chmod +x config/hooks/normal/0500-compilar-fydelterm.hook.chroot

# 6. EXECUTAR O BUILD ABSOLUTO DA ISO
echo -e "\n\033[1;32m🚀 Iniciando processo de compilação em massa da ISO (Aguarde)...\033[0m"
lb build

# 7. Coletar o resultado final
if [ -f live-image-amd64.hybrid.iso ]; then
    mv live-image-amd64.hybrid.iso "$DIRETORIO_RAIZ/fydelistechos.iso"
    echo -e "\n\033[1;32m🎉 SUCESSO ABSOLUTO!\033[0m"
    echo -e "A imagem oficial foi gerada em: \033[1;36m$DIRETORIO_RAIZ/fydelistechos.iso\033[0m"
else
    echo -e "\n\033[1;31m❌ Erro: O arquivo ISO final não pôde ser gerado pelo live-build.\033[0m"
    exit 1
fi