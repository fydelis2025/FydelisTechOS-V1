#!/bin/bash
# =========================================================================
# FydelisTechOS - Instalador Automatizado com Suporte a Tema GRUB Customizado
# v1.0.0 - Blindado contra travamentos em CI (GitHub Actions)
# =========================================================================
set -euo pipefail

# 1. Verificar privilégios de root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[1;31m❌ Erro: Execute este instalador com privilégios de root (sudo)!\033[0m"
    exit 1
fi

echo -e "\033[1;35m==================================================\033[0m"
echo -e "\033[1;35m    INSTALADOR OFICIAL FYDELISTECHOS OS v1.0     \033[0m"
echo -e "\033[1;35m==================================================\033[0m"
echo ""

# 2. Instalar dependências necessárias no host
echo -e "\033[1;34m🔍 Verificando e instalando ferramentas no ambiente host...\033[0m"
apt update -qq
apt install -y -qq debootstrap dosfstools e2fsprogs grub-efi-amd64 grub-pc parted rsync build-essential nasm g++ gcc make debian-archive-keyring > /dev/null

# 3. Mapeamento de Discos
echo -e "\n\033[1;36m📀 Discos disponíveis no sistema:\033[0m"
lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk || true
echo ""

read -p "Digite o caminho do disco para instalar (ex: /dev/sda): " DISCO

if [ ! -b "$DISCO" ]; then
    echo -e "\033[1;31m❌ Dispositivo de bloco $DISCO não existe!\033[0m"
    exit 1
fi

echo -e "\n\033[1;31m⚠️ ATENÇÃO: Todos os dados em $DISCO serão destruídos!\033[0m"
read -p "Tem certeza que deseja continuar? (s/N): " CONFIRMA
if [[ ! "$CONFIRMA" =~ ^[sS]$ ]]; then
    echo "Instalação abortada."
    exit 0
fi

# 4. Particionamento GPT Inteligente
echo -e "\n\033[1;32m🧹 Limpando tabela de partição antiga...\033[0m"
dd if=/dev/zero of="$DISCO" bs=512 count=2048 status=none
parted "$DISCO" mklabel gpt

echo -e "\033[1;32m📦 Criando novas partições (EFI e RAIZ)...\033[0m"
parted "$DISCO" mkpart primary fat32 1MiB 513MiB
parted "$DISCO" set 1 esp on
parted "$DISCO" mkpart primary ext4 513MiB 100%

# Identificar partições de forma dinâmica (suporta NVMe, MMC e SATA)
if [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]]; then
    PART_EFI="${DISCO}p1"
    PART_RAIZ="${DISCO}p2"
else
    PART_EFI="${DISCO}1"
    PART_RAIZ="${DISCO}2"
fi

echo -e "\033[1;32m🎨 Formatando partições em baixo nível...\033[0m"
mkfs.vfat -F32 "$PART_EFI" > /dev/null
mkfs.ext4 -F "$PART_RAIZ" > /dev/null

echo -e "\033[1;32m📂 Montando estrutura de diretórios em /mnt/fydel...\033[0m"
mkdir -p /mnt/fydel
mount "$PART_RAIZ" /mnt/fydel
mkdir -p /mnt/fydel/boot/efi
mount "$PART_EFI" /mnt/fydel/boot/efi

# 5. Bootstrap da Imagem Base
echo -e "\n\033[1;34m📥 Executando Debootstrap (Instalando base do Debian 12 Bookworm)...\033[0m"
debootstrap --arch=amd64 bookworm /mnt/fydel http://deb.debian.org/debian/

# =========================================================================
# INJEÇÃO CRUCIAL: Preparando ambiente ANTES de trancar a jaula chroot
# =========================================================================
echo -e "\n\033[1;34m⚙️ Injetando arquivos de configuração do FydelisTechOS no chroot...\033[0m"
mkdir -p /mnt/fydel/opt/fydel/
mkdir -p /mnt/fydel/lib/systemd/system/

# Copia os scripts operacionais
[ -f ./usuarios_permissoes.sh ] && cp ./usuarios_permissoes.sh /mnt/fydel/opt/fydel/
[ -f ./gerenciador_pacotes.sh ] && cp ./gerenciador_pacotes.sh /mnt/fydel/opt/fydel/
[ -f ./fydelterm.service ] && cp ./fydelterm.service /mnt/fydel/lib/systemd/system/

# --- AUTOMAÇÃO DO TEMA DO GRUB ---
echo -e "\033[1;34m🎨 Preparando e injetando o tema visual do GRUB...\033[0m"
mkdir -p /mnt/fydel/boot/grub/themes/grub-theme-fydel/

[ -f ./theme.txt ] && cp ./theme.txt /mnt/fydel/boot/grub/themes/grub-theme-fydel/
[ -f ./colors.txt ] && cp ./colors.txt /mnt/fydel/boot/grub/themes/grub-theme-fydel/

# Copia a estrutura de assets do subdiretório de design do sistema
GRUB_ASSETS_DIR="./sistema/grub/grub-theme-fydel"
if [ -d "$GRUB_ASSETS_DIR" ]; then
    [ -f "$GRUB_ASSETS_DIR/background.png" ] && cp "$GRUB_ASSETS_DIR/background.png" /mnt/fydel/boot/grub/themes/grub-theme-fydel/
    [ -f "$GRUB_ASSETS_DIR/logo.png" ] && cp "$GRUB_ASSETS_DIR/logo.png" /mnt/fydel/boot/grub/themes/grub-theme-fydel/
    [ -f "$GRUB_ASSETS_DIR/splash.png" ] && cp "$GRUB_ASSETS_DIR/splash.png" /mnt/fydel/boot/grub/themes/grub-theme-fydel/
    [ -f "$GRUB_ASSETS_DIR/grub.png" ] && cp "$GRUB_ASSETS_DIR/grub.png" /mnt/fydel/boot/grub/themes/grub-theme-fydel/
fi

# Vincula os barramentos de hardware reais da VM do GitHub Actions para a Jaula
mount --bind /dev /mnt/fydel/dev
mount --bind /dev/pts /mnt/fydel/dev/pts
mount -t proc proc /mnt/fydel/proc
mount -t sysfs sys /mnt/fydel/sys

# Gerar arquivo fstab estático para montagem no boot real
echo -e "\n\033[1;34m📝 Gerando tabela fstab para estabilidade dos discos...\033[0m"
UUID_RAIZ=$(blkid -s UUID -o value "$PART_RAIZ")
UUID_EFI=$(blkid -s UUID -o value "$PART_EFI")
echo -e "UUID=$UUID_RAIZ\t/\text4\terrors=remount-ro\t0\t1" > /mnt/fydel/etc/fstab
echo -e "UUID=$UUID_EFI\t/boot/efi\tvfat\tumask=0077\t0\t2" >> /mnt/fydel/etc/fstab

# =========================================================================
# CONFIGURAÇÃO INTERNA (Roda no contexto isolado do CHROOT)
# =========================================================================
cat << 'EOF' > /mnt/fydel/configurar_sistema.sh
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Atualizando espelhos APT do chroot..."
apt update -qq

echo "Instalando Kernel, Firmware de Rede e Core do Systemd..."
apt install -y -qq linux-image-amd64 linux-headers-amd64 grub-efi-amd64 grub-pc systemd systemd-sysv openssl sudo network-manager > /dev/null

# Aplicar scripts operacionais e privilégios de TTY
if [ -f /opt/fydel/usuarios_permissoes.sh ]; then
    echo "Configurando árvore de usuários, senhas e chroot..."
    bash /opt/fydel/usuarios_permissoes.sh
fi

# Ativar Terminal em Modo Quiosque na TTY1
if [ -f /lib/systemd/system/fydelterm.service ]; then
    echo "Habilitando fydelterm.service como TTY principal..."
    systemctl enable fydelterm.service
fi

# --- ATIVAÇÃO INTERNA DO TEMA GRUB ---
if [ -f /etc/default/grub ]; then
    echo "Aplicando estilos visuais no arquivo mestre do GRUB..."
    # Configura resolução genérica para não esticar o background
    sed -i 's/#GRUB_GFXMODE=640x480/GRUB_GFXMODE=1024x768,auto/' /etc/default/grub
    
    # Injeta a linha do tema se o arquivo theme.txt existir
    if [ -f /boot/grub/themes/grub-theme-fydel/theme.txt ]; then
        sed -i '/GRUB_THEME=/d' /etc/default/grub
        echo 'GRUB_THEME="/boot/grub/themes/grub-theme-fydel/theme.txt"' >> /etc/etc/default/grub
    fi

    # Fallback de splash gráfico
    if [ -f /boot/grub/themes/grub-theme-fydel/splash.png ]; then
        sed -i '/GRUB_BACKGROUND=/d' /etc/default/grub
        echo 'GRUB_BACKGROUND="/boot/grub/themes/grub-theme-fydel/splash.png"' >> /etc/default/grub
    fi
fi

echo "Gravando Bootloader na trilha MBR/EFI..."
if [ -d /sys/firmware/efi ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=FydelisTechOS --recheck --no-nvram
else
    DISCO_ALVO=$(mount | grep 'on / ' | awk '{print $1}' | sed 's/[0-9]*//g' | sed 's/p[0-9]*//g' || echo "/dev/sda")
    grub-install --target=i386-pc "$DISCO_ALVO" --recheck
fi

echo "Compilando arquivo final grub.cfg..."
update-grub -q

echo "Selando parâmetros de identificação de rede..."
echo "fydelistechos-os" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n127.0.1.1\tfydelistechos-os" > /etc/hosts

echo "✅ Configuração interna selada sem erros!"
EOF

chmod +x /mnt/fydel/configurar_sistema.sh

# 6. Execução da Jaula
echo -e "\n\033[1;32m🚀 Disparando sub-processador Chroot no FydelisTechOS...\033[0m"
chroot /mnt/fydel /bin/bash /configurar_sistema.sh

# 7. Limpeza e Desmontagem Segura e Forçada
rm -f /mnt/fydel/configurar_sistema.sh
echo -e "\n\033[1;34m🧹 Desalocando pontos de montagem virtuais de forma segura...\033[0m"
umount -lf /mnt/fydel/boot/efi || true
umount -lf /mnt/fydel/dev/pts || true
umount -lf /mnt/fydel/dev || true
umount -lf /mnt/fydel/proc || true
umount -lf /mnt/fydel/sys || true
umount -lf /mnt/fydel || true

echo -e "\n\033[1;32m🎉 INSTALAÇÃO DO FYDELISTECHOS COMPLETA E COM TEMA CONFIGURADO! 🎉\033[0m"
