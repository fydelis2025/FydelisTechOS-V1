#!/bin/bash
set -euo pipefail

# Verificar permissão de root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[1;31m❌ Execute este instalador com privilégios de root!\033[0m"
    exit 1
fi

echo -e "\033[1;35m==================================================\033[0m"
echo -e "\033[1;35m    INSTALADOR OFICIAL FYDELISTECHOS OS v1.0     \033[0m"
echo -e "\033[1;35m==================================================\033[0m"
echo ""

# Verificar e instalar ferramentas necessárias no ambiente Live-CD hospedeiro
echo -e "\033[1;34m🔍 Verificando ferramentas no ambiente host...\033[0m"
apt update -qq
apt install -y -qq debootstrap dosfstools e2fsprogs grub-efi-amd64 grub-pc parted rsync build-essential nasm g++ gcc make > /dev/null

# Listar discos disponíveis
echo -e "\n\033[1;36m📀 Discos disponíveis no sistema:\033[0m"
lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk || true
echo ""

read -p "Digite o caminho do disco para instalar (ex: /dev/sda): " DISCO

# Validação básica do disco
if [ ! -b "$DISCO" ]; then
    echo -e "\033[1;31m❌ Erro: O dispositivo $DISCO não é um bloco válido!\033[0m"
    exit 1
fi

echo -e "\n\033[1;31m⚠️ ATENÇÃO: TODOS OS DADOS EM $DISCO SERÃO APAGADOS!\033[0m"
read -p "Tem certeza que deseja continuar? (s/N): " CONFIRMA
if [[ ! "$CONFIRMA" =~ ^[sS]$ ]]; then
    echo "Instalação abortada."
    exit 0
fi

echo -e "\n\033[1;32m🏗️  Limpando tabela de partição e criando novo layout...\033[0m"
# Criar tabela GPT
parted -s "$DISCO" mklabel gpt

# Criar partições (EFI: 512MB, ROOT: Restante do disco)
parted -s "$DISCO" mkpart primary fat32 1MiB 513MiB
parted -s "$DISCO" set 1 esp on
parted -s "$DISCO" mkpart primary ext4 513MiB 100%

# Identificar partições geradas
if [[ "$DISCO" =~ "nvme" || "$DISCO" =~ "mmcblk" ]]; then
    PART_EFI="${DISCO}p1"
    PART_ROOT="${DISCO}p2"
else
    PART_EFI="${DISCO}1"
    PART_ROOT="${DISCO}2"
fi

echo -e "Formatando partição EFI ($PART_EFI)..."
mkfs.vfat -F 32 "$PART_EFI" > /dev/null

echo -e "Formatando partição ROOT ($PART_ROOT)..."
mkfs.ext4 -F "$PART_ROOT" > /dev/null

# Montagem do ambiente alvo
echo -e "\n\033[1;34m📂 Montando diretórios para o debootstrap...\033[0m"
mkdir -p /mnt/fydel
mount "$PART_ROOT" /mnt/fydel
mkdir -p /mnt/fydel/boot/efi
mount "$PART_EFI" /mnt/fydel/boot/efi

# ================= NOVO / ADICIONADO PARA DUAL BOOT =================
echo "📝 Gerando o arquivo /etc/fstab para montagem automática..."
mkdir -p /mnt/fydel/etc
UUID_ROOT=$(blkid -s UUID -o value "$PART_ROOT")
UUID_EFI=$(blkid -s UUID -o value "$PART_EFI")

cat <<FSTAB > /mnt/fydel/etc/fstab
# <file system>             <mount point>   <type>  <options>                  <dump>  <pass>
UUID=$UUID_ROOT             /               ext4    errors=remount-ro          0       1
UUID=$UUID_EFI              /boot/efi       vfat    umask=0077                 0       2
FSTAB
# ====================================================================

# Executar debootstrap (Instalar base estável do Debian 12 Bookworm)
echo -e "\n\033[1;32m📦 Executando debootstrap (Isso pode demorar alguns minutos)...\033[0m"
debootstrap --arch=amd64 bookworm /mnt/fydel http://deb.debian.org/debian/

# Montar sistemas virtuais necessários para o chroot e grub-install
echo -e "Montando sistemas de arquivos virtuais..."
for i in /dev /dev/pts /proc /sys /run; do mount -B "$i" "/mnt/fydel$i"; done

# Preparar repositórios APT oficiais no sistema instalado
echo -e "Configurando sources.list do sistema alvo..."
cat <<EOF > /mnt/fydel/etc/apt/sources.list
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF

# Estruturar os fontes do FydelisTechOS dentro do diretório /opt/do sistema alvo
echo -e "\n\033[1;34m🚚 Copiando arquivos e scripts do FydelisTechOS para o sistema...\033[0m"
mkdir -p /mnt/fydel/opt/fydel
# Copia toda a árvore de desenvolvimento local para o ambiente instalado
rsync -a --exclude='iso' . /mnt/fydel/opt/fydel/

# Criar script de configuração interna que rodará dentro do CHROOT
cat <<'EOF' > /mnt/fydel/configurar_sistema.sh
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "Atualizando base de dados do APT dentro do chroot..."
apt-get update -qq

echo "Instalando compiladores e ferramentas essenciais do sistema..."
apt-get install -y -qq build-essential nasm g++ gcc make sudo locales grub-efi-amd64 grub-pc libutil-dev os-prober > /dev/null

# Gerar locales adequados
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen > /dev/null

# Ler e instalar todos os pacotes customizados da sua lista_completa.txt
echo "Instalando lista completa de pacotes do FydelisTechOS..."
if [ -f /opt/fydel/pacotes/lista_completa.txt ]; then
    PACOTES=$(grep -v '^#' /opt/fydel/pacotes/lista_completa.txt | tr '\n' ' ')
    apt-get install -y $PACOTES
fi

# ================= CONFIGURAÇÃO DA FYDELISTECH-AI (OLLAMA) =================
echo "🤖 Instalando o motor FydelisTech-AI (Ollama)..."
# Baixa e instala o binário oficial do Ollama de forma silenciosa
curl -fsSL https://ollama.com/install.sh | sh

echo "⚙️ Inicializando o serviço do Ollama temporariamente para baixar o modelo..."
# Inicia o servidor do Ollama em segundo plano para podermos baixar o modelo dentro do chroot
ollama serve &
PID_OLLAMA=$!

# Aguarda 5 segundos para garantir que o serviço subiu
sleep 5

echo "🧠 Baixando o modelo de linguagem (Llama3) para a FydelisTech-AI..."
# Você pode substituir 'llama3' por 'gemma' ou outro modelo leve de sua preferência
ollama pull llama3

# Desliga o servidor temporário do Ollama de forma limpa
kill $PID_OLLAMA
echo "✅ Motor FydelisTech-AI configurado com sucesso!"
# ===========================================================================

# ================= INTEGRADO / NOVO =================
echo "Compilando e instalando o Terminal Híbrido (fydelterm)..."
cd /opt/fydel/src/terminal/
make clean && make
make install # Move para /usr/local/bin/fydelterm

echo "Instalando telas do sistema (Boas-vindas)..."
mkdir -p /usr/share/fydel/telas/
if [ -f /opt/fydel/src/telas/tela_boas_vindas.txt ]; then
    cp /opt/fydel/src/telas/tela_boas_vindas.txt /usr/share/fydel/telas/
fi

echo "Executando o script oficial de usuários e permissões..."
chmod +x /opt/fydel/src/sistema/usuarios_permissoes.sh
/opt/fydel/src/sistema/usuarios_permissoes.sh

echo "Instalando o Gerenciador de Pacotes personalizado (fydel-pkg)..."
chmod +x /opt/fydel/src/sistema/gerenciador_pacotes.sh
ln -sf /opt/fydel/src/sistema/gerenciador_pacotes.sh /usr/local/bin/fydel-pkg

echo "Instalando e ativando o serviço fydelterm.service no TTY1..."
cp /opt/fydel/src/sistema/servicos_systemd/fydelterm.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable fydelterm.service

echo "Instalando o Tema Personalizado do GRUB..."
mkdir -p /boot/grub/themes/grub-theme-fydel
cp -r /opt/fydel/src/sistema/grub/grub-theme-fydel/* /boot/grub/themes/grub-theme-fydel/

# Ajustar /etc/default/grub para carregar o tema e ativar o os-prober para dual boot
sed -i 's/#GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080,1280x720,auto/' /etc/default/grub
if grep -q "GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
    sed -i 's|GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub
else
    echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
fi

if grep -q "GRUB_THEME=" /etc/default/grub; then
    sed -i 's|GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/grub-theme-fydel/theme.txt"|' /etc/default/grub
else
    echo 'GRUB_THEME="/boot/grub/themes/grub-theme-fydel/theme.txt"' >> /etc/default/grub
fi
# ====================================================

echo "Instalando o gerenciador de boot GRUB..."
if [ -d /sys/firmware/efi ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=FYDEL --recheck
else
    DISCO_ALVO=$(mount | grep 'on / ' | awk '{print $1}' | sed 's/[0-9]*//g' | sed 's/p[0-9]*//g')
    grub-install --target=i386-pc "$DISCO_ALVO" --recheck
fi
update-grub

echo "Configurando identificação de rede do sistema..."
echo "fydelistechos-os" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n127.0.1.1\tfydelistechos-os" > /etc/hosts

echo "✅ Configuração interna concluída com sucesso!"
EOF

chmod +x /mnt/fydel/configurar_sistema.sh

# Executar a jaula chroot para processar toda a instalação interna do Debian + Fydel
echo -e "\n\033[1;32m🚀 Entrando no ambiente chroot para finalizar o FydelisTechOS...\033[0m"
chroot /mnt/fydel /bin/bash /configurar_sistema.sh

# Limpeza pós-instalação
rm -f /mnt/fydel/configurar_sistema.sh

echo -e "\n\033[1;34m🎨 Instalando recursos de ícones globais...\033[0m"
mkdir -p /mnt/fydel/usr/share/icons/fydel
if [ -d /mnt/fydel/opt/fydel/src/sistema/icones ]; then
    cp -r /mnt/fydel/opt/fydel/src/sistema/icones/* /mnt/fydel/usr/share/icons/fydel/
fi

# Desmontar de forma segura o ambiente alvo
echo -e "\n\033[1;33m🧹 Desmontando partições e finalizando...\033[0m"
umount -l /mnt/fydel/boot/efi || true
for i in /dev/pts /dev /proc /sys /run; do umount -l "/mnt/fydel$i" || true; done
umount -l /mnt/fydel

echo -e "\n\033[1;32m🎉 PROCESSO CONCLUÍDO! O FydelisTechOS foi instalado com sucesso em $DISCO.\033[0m"
echo "Remova o instalador/mídia Live e reinicie o computador para entrar no seu novo sistema!"