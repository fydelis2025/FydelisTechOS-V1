#!/bin/bash
set -e

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Por favor, execute este script como root ou usando sudo."
  exit 1
fi

PROJECT_DIR="/home/fydelis/Downloads/FydelisTechOS"
cd "$PROJECT_DIR"

echo "=========================================================="
echo "🛡️  Iniciando Compilação Local NATIVA do FydelisTechOS (KDE) 🛡️"
echo "=========================================================="

# 1. Instalar dependências necessárias direto no seu host
echo "=== 1. Garantindo dependências do live-build no sistema ==="
apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap xorriso rsync wget ca-certificates gnupg2 \
  debian-archive-keyring debian-keyring curl findutils coreutils cpio nasm gcc g++ make git sassc cmake \
  qtbase5-dev pkg-config libqt5widgets5

# 2. Sanitização de quebras de linha
echo "=== 2. Sanitizando quebras de linha (CRLF -> LF) ==="
find . -type f -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find . -type f -name "*.txt" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find . -type f -name "*.cpp" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find . -type f -name "*.py" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

# 3. Preparar variáveis do live-build (Espelho do Brasil para estabilidade)
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_DIST=bookworm
export ARCH=amd64
export MIRROR=http://ftp.br.debian.org/debian/
export SEC_MIRROR=http://ftp.br.debian.org/debian-security/

echo "=== 3. Preparar lista de pacotes otimizada ==="
mkdir -p src/pacotes/
cat > src/pacotes/lista_completa.txt << 'EOF'
live-boot live-config live-config-systemd base-files base-passwd bash coreutils dash diffutils e2fsprogs findutils grep gzip hostname init-system-helpers libc6 login lsb-base mawk mount ncurses-base ncurses-bin perl-base sed tar util-linux debian-archive-keyring debian-keyring
xserver-xorg xserver-xorg-video-all xserver-xorg-input-all x11-xserver-utils sddm kde-plasma-desktop plasma-workspace dolphin konsole kate desktop-base plymouth plymouth-themes
nano vim htop ncdu lsof net-tools psmisc man-db bash-completion sudo wget curl rsync unzip bzip2 xz-utils git dconf-cli gettext yad zenity sassc conky-all
libreoffice libreoffice-l10n-pt-br evince gpicview vlc vlc-l10n
pulseaudio pulseaudio-utils alsa-utils alsa-tools pavucontrol pavucontrol-qt volumeicon-alsa
bluetooth bluez bluez-tools blueman
firefox-esr network-manager network-manager-gnome wireless-tools wpasupplicant openssh-client openssh-server netcat-openbsd nmap traceroute mtr iproute2
gparted parted dosfstools ntfs-3g exfatprogs btrfs-progs lvm2
wireshark tshark tcpdump hydra john hashcat aircrack-ng reaver sqlmap binwalk foremost testdisk chkrootkit rkhunter
system-config-printer hardinfo lm-sensors udisks2 openssl
python3 python3-pip python3-requests python3-setuptools python3-wheel python3-pyqt5 python3-psutil
build-essential nasm gcc g++ make cmake qt6-base-dev libqt6core6 libqt6gui6 libqt6widgets6 qtbase5-dev pkg-config libqt5widgets5
EOF

echo "=== 4. Configurar Live Build ==="
lb clean --purge || true
rm -rf auto config || true

lb config \
  --distribution "${DEBIAN_DIST}" \
  --architectures "${ARCH}" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --mirror-bootstrap "${MIRROR}" \
  --mirror-chroot "${MIRROR}" \
  --mirror-chroot-security "${SEC_MIRROR}" \
  --mirror-binary "${MIRROR}" \
  --mirror-binary-security "${SEC_MIRROR}" \
  --iso-application "FydelisTechOS" \
  --iso-publisher "FydelisTech" \
  --iso-volume "FYDELIS_V1" \
  --binary-images iso-hybrid \
  --debian-installer false \
  --cache-packages false \
  --apt-source-archives false

echo "=== 5. Estruturar Diretórios do Chroot e Binary ==="
mkdir -p config/package-lists/
cp src/pacotes/lista_completa.txt config/package-lists/fydelis.list.chroot

mkdir -p config/includes.chroot/usr/local/bin/
mkdir -p config/includes.chroot/usr/local/bin/fydelis-tools/
mkdir -p config/includes.chroot/usr/local/src/fydel-terminal/
mkdir -p config/includes.chroot/boot/grub/themes/grub-theme-fydel/
mkdir -p config/includes.chroot/usr/share/icons/fydel/branding/
mkdir -p config/includes.chroot/etc/systemd/system/
mkdir -p config/includes.chroot/usr/share/doc/fydelistechos/
mkdir -p config/includes.chroot/opt/fydel/telas/
mkdir -p config/includes.chroot/opt/fydel/iso/

mkdir -p config/includes.chroot/opt/fydelislab/
mkdir -p config/includes.chroot/opt/fydelislab/bancos/
mkdir -p config/includes.chroot/opt/fydelislab/certificados/
mkdir -p config/includes.chroot/opt/fydelislab/scripts/
mkdir -p config/includes.chroot/opt/fydelislab/docs/
mkdir -p config/includes.chroot/opt/fydelislab/backgrounds/

mkdir -p config/includes.chroot/opt/fydel/instalador/slides/
mkdir -p config/includes.chroot/usr/share/backgrounds/fydel/
mkdir -p config/includes.chroot/etc/skel/Desktop/
mkdir -p config/includes.chroot/etc/skel/.config/autostart/

mkdir -p config/bootloaders/grub-pc/
mkdir -p config/bootloaders/grub-efi/
mkdir -p config/bootloaders/grub/
mkdir -p config/includes.binary/boot/grub/

# === Preparar código fonte do Instalador para ser compilado no Chroot ===
if [ -d "src/instalador" ]; then
    echo "=== Copiando fonte do instalador para dentro do chroot ==="
    mkdir -p config/includes.chroot/usr/local/src/fydel-installer/
    cp -r src/instalador/* config/includes.chroot/usr/local/src/fydel-installer/

    if [ -d "src/instalador/slide" ]; then
        cp -r src/instalador/slide/* config/includes.chroot/opt/fydel/instalador/slides/ 2>/dev/null || true
    elif [ -d "src/instalador/slides" ]; then
        cp -r src/instalador/slides/* config/includes.chroot/opt/fydel/instalador/slides/ 2>/dev/null || true
    fi

    cat << 'EOF' > config/includes.chroot/usr/local/bin/fydel-install
#!/bin/bash
cd /opt/fydel/instalador
./fydelistechos-installer "$@"
EOF
    chmod +x config/includes.chroot/usr/local/bin/fydel-install
fi

# === Preparar código fonte da Tela de Boas-Vindas para compilação no Chroot ===
if [ -d "src/bem-vindo" ]; then
    echo "=== Copiando fonte da Tela de Boas-Vindas para o chroot ==="
    mkdir -p config/includes.chroot/usr/local/src/fydel-welcome/
    cp -r src/bem-vindo/* config/includes.chroot/usr/local/src/fydel-welcome/
fi

# Atalho de inicialização automática da tela de boas-vindas
cat << 'EOF' > config/includes.chroot/etc/skel/.config/autostart/fydelis-welcome.desktop
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/fydelis-welcome
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=FydelisTechOS Welcome
Comment=Tela de Boas-Vindas do FydelisTechOS
EOF

# === Copiando FydelisLab ===
if [ -d "src/sistema/FydelisLab" ]; then
    cp -r src/sistema/FydelisLab/* config/includes.chroot/opt/fydelislab/
    chmod +x config/includes.chroot/opt/fydelislab/*.py 2>/dev/null || true
    chmod -R 777 config/includes.chroot/opt/fydelislab/bancos/
    chmod -R 777 config/includes.chroot/opt/fydelislab/certificados/
    chmod -R 777 config/includes.chroot/opt/fydelislab/scripts/
    chmod -R 777 config/includes.chroot/opt/fydelislab/docs/
    chmod -R 777 config/includes.chroot/opt/fydelislab/backgrounds/
fi

# === Copiando FydelisAI e Ferramentas ===
if [ -d "src/ferramentas/fydelis-ai" ]; then
  mkdir -p config/includes.chroot/opt/fydelis-ai/
  cp -r src/ferramentas/fydelis-ai/* config/includes.chroot/opt/fydelis-ai/
  if [ -f config/includes.chroot/opt/fydelis-ai/fydelis-ai.pl ]; then
    ln -sf /opt/fydelis-ai/fydelis-ai.pl config/includes.chroot/usr/local/bin/fydelis-ai
    chmod +x config/includes.chroot/opt/fydelis-ai/fydelis-ai.pl
  fi
fi

if [ -d "src/ferramentas/fydelis-ai/tools" ] && [ "$(ls -A src/ferramentas/fydelis-ai/tools 2>/dev/null)" ]; then
  cp -r src/ferramentas/fydelis-ai/tools/* config/includes.chroot/usr/local/bin/fydelis-tools/
  chmod -R +x config/includes.chroot/usr/local/bin/fydelis-tools/ 2>/dev/null || true
fi

# === Copiando Utilitários Python da pasta src/sistema/ ===
[ -f "src/sistema/FydelisSynaptic.py" ] && cp src/sistema/FydelisSynaptic.py config/includes.chroot/usr/local/bin/fydel-synaptic.py
[ -f "src/sistema/FydelisPackage.py" ] && cp src/sistema/FydelisPackage.py config/includes.chroot/usr/local/bin/fydel-package.py
[ -f "src/sistema/fydel_ai.py" ] && cp src/sistema/fydel_ai.py config/includes.chroot/usr/local/bin/fydel_ai.py
[ -f "src/sistema/FydelisControl.py" ] && cp src/sistema/FydelisControl.py config/includes.chroot/usr/local/bin/fydelis-control.py

chmod +x config/includes.chroot/usr/local/bin/*.sh 2>/dev/null || true
chmod +x config/includes.chroot/usr/local/bin/*.py 2>/dev/null || true

ln -sf /usr/local/bin/fydel-synaptic.py config/includes.chroot/usr/local/bin/fydel-synaptic
ln -sf /usr/local/bin/fydel_ai.py config/includes.chroot/usr/local/bin/fydel-ai
ln -sf /usr/local/bin/fydelis-control.py config/includes.chroot/usr/local/bin/fydel-control

echo "=== Criando Lançadores de Aplicativos, Menus e Logo ==="
mkdir -p config/includes.chroot/usr/share/applications/

if [ -f "./logo_menu.png" ]; then
  cp ./logo_menu.png config/includes.chroot/usr/share/icons/fydel/branding/logo_menu.png
fi

cat << 'EOF' > config/includes.chroot/usr/share/applications/fydel-install.desktop
[Desktop Entry]
Name=Instalar FydelisTechOS
Comment=Instalar o sistema operacional no disco rígido
Exec=konsole --hold -e /usr/local/bin/fydel-install
Icon=/usr/share/icons/fydel/branding/logo_menu.png
Terminal=false
Type=Application
Categories=System;
StartupNotify=true
EOF

mkdir -p config/includes.chroot/etc/skel/Desktop/
cp config/includes.chroot/usr/share/applications/fydel-install.desktop config/includes.chroot/etc/skel/Desktop/
chmod +x config/includes.chroot/etc/skel/Desktop/fydel-install.desktop

cat << 'EOF' > config/includes.chroot/usr/share/applications/fydel-synaptic.desktop
[Desktop Entry]
Name=Gerenciador de Pacotes Fydelis
Comment=Gerenciar pacotes APT com interface gráfica avançada
Exec=python3 /usr/local/bin/fydel-synaptic.py
Icon=/usr/share/icons/fydel/branding/logo_menu.png
Terminal=false
Type=Application
Categories=System;Settings;
StartupNotify=true
EOF

cat << 'EOF' > config/includes.chroot/usr/share/applications/fydel-control.desktop
[Desktop Entry]
Name=Painel de Controle Fydelis
Comment=Gerenciador e Painel de Controle do FydelisTechOS
Exec=python3 /usr/local/bin/fydelis-control.py
Icon=/usr/share/icons/fydel/branding/logo_menu.png
Terminal=false
Type=Application
Categories=System;Settings;
StartupNotify=true
EOF

if [ -d "src/terminal" ] && [ "$(ls -A src/terminal 2>/dev/null)" ]; then
  cp -r src/terminal/* config/includes.chroot/usr/local/src/fydel-terminal/
fi

if [ -f "./wallpaper.png" ]; then
  mkdir -p config/includes.chroot/usr/share/wallpapers/FydelisTechOS/contents/images/
  cp ./wallpaper.png config/includes.chroot/usr/share/wallpapers/FydelisTechOS/contents/images/background.png
  cp ./wallpaper.png config/includes.chroot/usr/share/backgrounds/fydel/wallpaper.png
else
  mkdir -p config/includes.chroot/usr/share/backgrounds/fydel/
  touch config/includes.chroot/usr/share/backgrounds/fydel/wallpaper.png
fi

GRUB_ASSETS="src/sistema/grub/grub-theme-fydel"
if [ -d "$GRUB_ASSETS" ]; then
  [ -f "$GRUB_ASSETS/background.png" ] && cp "$GRUB_ASSETS/background.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  [ -f "$GRUB_ASSETS/logo.png" ] && cp "$GRUB_ASSETS/logo.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  [ -f "$GRUB_ASSETS/splash.png" ] && cp "$GRUB_ASSETS/splash.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  [ -f "$GRUB_ASSETS/grub.png" ] && cp "$GRUB_ASSETS/grub.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  
  cp "$GRUB_ASSETS/splash.png" config/bootloaders/grub/splash.png 2>/dev/null || true
  cp "$GRUB_ASSETS/splash.png" config/includes.binary/boot/grub/splash.png 2>/dev/null || true
  mkdir -p config/includes.chroot/usr/share/plymouth/themes/fydel/
  cp "$GRUB_ASSETS/splash.png" config/includes.chroot/usr/share/plymouth/themes/fydel/background.png 2>/dev/null || true
fi

# Configuração de Boot Dual (UEFI + Legacy BIOS) com GRUB
echo "=== Configurando bootloaders para UEFI e Legacy ==="
cat << 'EOF' > config/bootloaders/grub-pc/grub.cfg
if loadfont /boot/grub/font.pf2 ; then
    set gfxmode=auto
    insmod efi_gop
    insmod efi_uga
    terminal_output gfxterm
fi

set theme=/boot/grub/themes/grub-theme-fydel/theme.txt
export theme

set menu_color_normal=cyan/blue
set menu_color_highlight=white/cyan

menuentry "🛡️ FydelisTechOS - Testar (Modo Live)" {
    linux /live/vmlinuz boot=live components quiet splash locales=pt_BR.UTF-8 keyboard-layout=br
    initrd /live/initrd.img
}
menuentry "🚀 FydelisTechOS - Instalar no Disco Rígido" {
    linux /live/vmlinuz boot=live components quiet splash fydel_install=true locales=pt_BR.UTF-8 keyboard-layout=br
    initrd /live/initrd.img
}
EOF

cp config/bootloaders/grub-pc/grub.cfg config/bootloaders/grub-efi/grub.cfg

echo "=== 6. Criando Hooks internos (Compilação Nativa + Tema CyberHack) ==="
mkdir -p config/hooks/normal
cat << 'EOF' > config/hooks/normal/0500-build-system.hook.chroot
#!/bin/bash
set -e

find /usr/local/bin/ -type f -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

echo "=== [Hook] Compilando o Instalador Qt6 dentro do Chroot ==="
if [ -d /usr/local/src/fydel-installer ]; then
    cd /usr/local/src/fydel-installer
    rm -rf build
    mkdir build
    cd build
    cmake ..
    cmake --build . --config Release
    
    mkdir -p /opt/fydel/instalador/
    if [ -f fydelistechos-installer ]; then
        cp fydelistechos-installer /opt/fydel/instalador/
    elif [ -f bin/fydelistechos-installer ]; then
        cp bin/fydelistechos-installer /opt/fydel/instalador/
    fi
    chmod +x /opt/fydel/instalador/fydelistechos-installer
fi

echo "=== [Hook] Compilando a Tela de Boas-Vindas Qt6 ==="
if [ -d /usr/local/src/fydel-welcome ]; then
    cd /usr/local/src/fydel-welcome
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build --config Release
    
    if [ -f build/fydelis-welcome ]; then
        cp build/fydelis-welcome /usr/local/bin/fydelis-welcome
    elif [ -f build/bin/fydelis-welcome ]; then
        cp build/bin/fydelis-welcome /usr/local/bin/fydelis-welcome
    fi
    chmod +x /usr/local/bin/fydelis-welcome
fi

echo "=== [Hook] Clonando e instalando o Tema CyberHack ==="
git clone https://git.disroot.org/eudaimon/CyberHack.git /tmp/CyberHack || true
if [ -d /tmp/CyberHack ]; then
    mkdir -p /usr/share/themes/CyberHack
    cp -r /tmp/CyberHack/gtk-2.0 /usr/share/themes/CyberHack/ 2>/dev/null || true
    cp -r /tmp/CyberHack/gtk-3.0 /usr/share/themes/CyberHack/ 2>/dev/null || true
    cp /tmp/CyberHack/index.theme /usr/share/themes/CyberHack/ 2>/dev/null || true
    rm -rf /tmp/CyberHack
fi

echo "=== [Hook] Configurando Ferramentas Fydelis no PATH ==="
if [ -d /usr/local/bin/fydelis-tools ]; then
  chmod -R +x /usr/local/bin/fydelis-tools/ 2>/dev/null || true
fi

apt-get purge -y desktop-base || true

echo "=== [Hook] Compilando Terminal Híbrido Fydel ==="
if [ -d /usr/local/src/fydel-terminal ]; then
  cd /usr/local/src/fydel-terminal
  make clean && make && make install
fi

chmod +x /usr/local/bin/fydel_ai.py 2>/dev/null || true
ln -sf /usr/local/bin/fydel_ai.py /usr/local/bin/fydel-ai

echo "=== [Hook] Compilando e instalando Extensões Visuais (Dock e Blur) ==="
cd /tmp
git clone https://github.com/micheleg/dash-to-dock.git || true
if [ -d dash-to-dock ]; then
    cd dash-to-dock && git checkout gnome-43 || true
    mkdir -p /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com
    make || true
    cp -r * /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/ 2>/dev/null || true
    cd /tmp && rm -rf dash-to-dock
fi

git clone https://github.com/aunetx/blur-my-shell.git || true
if [ -d blur-my-shell ]; then
    cd blur-my-shell && git checkout v43 || true
    mkdir -p /usr/share/gnome-shell/extensions/blur-my-shell@aunetx
    cp -r * /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/ 2>/dev/null || true
    cd /tmp && rm -rf blur-my-shell
fi

echo "=== [Hook] Injetando Configurações do Conky (Gráficos Laterais e Bloco de Código) ==="
mkdir -p /etc/conky/
cat << 'CONKY_SYS' > /etc/conky/conky_system.conf
conky.config = {
    alignment = 'top_right',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = '#94A3B8',
    default_outline_color = 'white',
    default_shade_color = 'white',
    double_buffer = true,
    draw_borders = true,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    extra_button_menu = false,
    gap_x = 40,
    gap_y = 60,
    minimum_height = 600,
    minimum_width = 240,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'desktop',
    own_window_transparent = false,
    own_window_argb_visual = true,
    own_window_argb_value = 115,
    own_window_colour = '10162F',
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    show_graph_scale = false,
    show_graph_range = false,
    use_xft = true,
    font = 'Sans:size=10',
    border_inner_margin = 20,
    border_outer_margin = 0,
    draw_blended_borders = true,
    default_bar_width = 0,
    default_bar_height = 0,
};

conky.text = [[
${color #F8FAFC}${font Urbanist:size=12:bold}SYSTEM${font}${hr 1}
${offset 0}${color #94A3B8}CPU ${alignr}${color #22D3EE}${cpu}%
${color #6366F1}${cpugraph 40,200 6a11cb 22d3ee -t}
${offset 0}${color #94A3B8}RAM ${alignr}${color #22D3EE}${memperc}%
${color #6366F1}${memgraph 40,200 6a11cb 22d3ee -t}
${offset 0}${color #94A3B8}DISK ${alignr}${color #22D3EE}${fs_used_perc /}%
${color #6366F1}${diskiograph 40,200 6a11cb 22d3ee -t}
${offset 0}${color #94A3B8}NETWORK ${alignr}${color #22D3EE}${downspeed eth0}
${color #6366F1}${downspeedgraph eth0 40,200 6a11cb 22d3ee -t}
]];
CONKY_SYS

cat << 'CONKY_CODE' > /etc/conky/conky_code.conf
conky.config = {
    alignment = 'bottom_right',
    background = false,
    double_buffer = true,
    gap_x = 40,
    gap_y = 40,
    minimum_height = 200,
    minimum_width = 400,
    own_window = true,
    own_window_type = 'desktop',
    own_window_argb_visual = true,
    own_window_argb_value = 115,
    own_window_colour = '10162F',
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    use_xft = true,
    font = 'Monospace:size=11',
    border_inner_margin = 25,
};

conky.text = [[
${color #6366F1}01  // Keep building
02  ${color #6a11cb}function ${color #22D3EE}buildFuture() {
${color #6366F1}03      ${color #6a11cb}const ${color #F8FAFC}mindset = ${color #22D3EE}'growth';
04      ${color #6a11cb}const ${color #F8FAFC}code = ${color #22D3EE}'impact';
05      ${color #6a11cb}return ${color #F8FAFC}mindset + code;
06  }
07  
08  ${color #22D3EE}buildFuture();
]];
CONKY_CODE

mkdir -p /etc/skel/.config/autostart/
cat << 'AUTO' > /etc/skel/.config/autostart/conky.desktop
[Desktop Entry]
Type=Application
Exec=sh -c "conky --daemonize --config=/etc/conky/conky_system.conf && conky --daemonize --config=/etc/conky/conky_code.conf"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=FydelisWidgets
Description=Inicia os widgets glassmorphic do FydelisTechOS
AUTO

echo "=== [Hook] Estruturando Esquema de Configurações Padrão (GSettings GLib com CyberHack) ==="
mkdir -p /usr/share/glib-2.0/schemas/
cat << 'GS' > /usr/share/glib-2.0/schemas/99_fydelistechos_visual.gschema.override
[org.gnome.desktop.interface]
gtk-theme='CyberHack'
icon-theme='Adwaita'
font-name='Sans 11'

[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/fydel/wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/fydel/wallpaper.png'
picture-options='zoom'

[org.gnome.shell]
enabled-extensions=['dash-to-dock@micxgx.gmail.com', 'blur-my-shell@aunetx']
development-tools=false

[org.gnome.shell.extensions.dash-to-dock]
dock-position='BOTTOM'
extend-height=false
dock-fixed=true
dash-max-icon-size=48
custom-theme-shrink=true
background-opacity=0.45
custom-background-color=true
background-color='rgb(16,22,47)'
click-action='focus-or-previews'
hot-keys=false
show-apps-at-top=false
GS

glib-compile-schemas /usr/share/glib-2.0/schemas/ || true

echo "=== [Hook] Customizando strings de inicialização para FydelisTechOS ==="
if [ -d /boot/grub ]; then
    find /boot/grub/ -type f -name "*.cfg" -exec sed -i 's/Debian GNU\/Linux/FydelisTechOS/g' {} + || true
    find /boot/grub/ -type f -name "*.cfg" -exec sed -i 's/Live System/Modo Live/g' {} + || true
fi
EOF
chmod +x config/hooks/normal/0500-build-system.hook.chroot

echo "=== 7. Executando o lb build Nativo ==="
lb build --verbose 2>&1

echo "=== 8. Tratando imagem ISO resultante ==="
if [ -f live-image-amd64.hybrid.iso ]; then
  mv live-image-amd64.hybrid.iso FydelisTechOS-V1.0.iso
  echo "🏆 SUCESSO! ISO gerada localmente: FydelisTechOS-V1.0.iso"
elif [ -f binary.iso ]; then
  mv binary.iso FydelisTechOS-V1.0.iso
  echo "🏆 SUCESSO! ISO gerada localmente: FydelisTechOS-V1.0.iso"
else
  echo "❌ Erro: ISO final não encontrada."
  exit 1
fi
