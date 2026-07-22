#!/bin/bash
set -e

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Por favor, execute este script como root ou usando sudo."
  exit 1
fi

echo "=========================================================="
echo "🛡️  Iniciando Compilação Local NATIVA do FydelisTechOS V1.0 🛡️"
echo "=========================================================="

# 1. Instalar dependências necessárias direto no seu host
echo "=== 1. Garantindo dependências do live-build no sistema ==="
apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap xorriso rsync wget ca-certificates gnupg2 \
  debian-archive-keyring debian-keyring curl findutils coreutils cpio nasm gcc g++ make git sassc

# 2. Sanitização de quebras de linha
echo "=== 2. Sanitizando quebras de linha (CRLF -> LF) ==="
find . -type f -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find . -type f -name "*.txt" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find . -type f -name "*.cpp" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find . -type f -name "*.py" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

# 3. Preparar variáveis do live-build
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_DIST=bookworm
export ARCH=amd64
export MIRROR=http://deb.debian.org/debian/
export SEC_MIRROR=http://deb.debian.org/debian-security/

echo "=== 3. Preparar lista de pacotes otimizada ==="
mkdir -p src/pacotes/
cat > src/pacotes/lista_completa.txt << 'EOF'
# Sistema base Debian e Inicialização Live USB
live-boot live-config live-config-systemd base-files base-passwd bash coreutils dash diffutils e2fsprogs findutils grep gzip hostname init-system-helpers libc6 login lsb-base mawk mount ncurses-base ncurses-bin perl-base sed tar util-linux debian-archive-keyring debian-keyring

# Servidor Gráfico e Interface Mínima (GNOME / X11)
xserver-xorg xserver-xorg-video-all xserver-xorg-input-all x11-xserver-utils gdm3 gnome-shell gnome-session nautilus gnome-terminal desktop-base gnome-shell-extension-prefs plymouth plymouth-themes

# Ferramentas básicas
nano vim htop ncdu lsof net-tools psmisc man-db bash-completion sudo wget curl rsync unzip bzip2 xz-utils git dconf-cli gettext yad zenity sassc conky-all gnome-tweaks

# Escritório e Multimídia
libreoffice libreoffice-l10n-pt-br evince gpicview
vlc vlc-l10n

# Áudio, Microfone e Som
pulseaudio pulseaudio-utils alsa-utils alsa-tools alsa-base pavucontrol pavucontrol-qt volumeicon-alsa

# Bluetooth
bluetooth bluez bluez-tools blueman

# Rede e Internet
firefox-esr network-manager network-manager-gnome wireless-tools wpasupplicant openssh-client openssh-server netcat-openbsd nmap traceroute mtr iproute2

# Discos e armazenamento
gparted parted dosfstools ntfs-3g exfatprogs btrfs-progs lvm2 gnome-disk-utility

# Segurança, Pentest e Frameworks
wireshark tshark tcpdump hydra john hashcat aircrack-ng reaver sqlmap nikto metasploit-framework binwalk foremost testdisk chkrootkit rkhunter

# Sistema, Painel de Controle e configuração
gnome-control-center system-config-printer hardinfo lm-sensors udisks2 openssl

# Python e Dependências para a FydelisTech-AI
python3 python3-pip python3-requests python3-setuptools python3-wheel

# Compilação
build-essential nasm gcc g++ make cmake
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
mkdir -p config/includes.chroot/usr/share/icons/fydel/
mkdir -p config/includes.chroot/etc/systemd/system/
mkdir -p config/includes.chroot/usr/share/doc/fydelistechos/
mkdir -p config/includes.chroot/opt/fydel/telas/
mkdir -p config/includes.chroot/opt/fydel/iso/

mkdir -p config/includes.chroot/opt/fydel/instalador/slides/
mkdir -p config/includes.chroot/usr/share/themes/CyberHack/gnome-shell/
mkdir -p config/includes.chroot/usr/share/backgrounds/fydel/

mkdir -p config/includes.chroot/usr/share/icons/fydel/branding/
mkdir -p config/includes.chroot/etc/skel/Desktop/

mkdir -p config/bootloaders/grub/
mkdir -p config/includes.binary/boot/grub/

# Copia as ferramentas customizadas Fydelis (FydelisAudit, FydelisDork, fydelisbrute, etc.)
if [ -d "src/ferramentas" ] && [ "$(ls -A src/ferramentas 2>/dev/null)" ]; then
  cp -r src/ferramentas/* config/includes.chroot/usr/local/bin/fydelis-tools/
fi

if [ -d "src/terminal" ] && [ "$(ls -A src/terminal 2>/dev/null)" ]; then
  cp -r src/terminal/* config/includes.chroot/usr/local/src/fydel-terminal/
fi

[ -f "src/sistema/fydel_ai.py" ] && cp src/sistema/fydel_ai.py config/includes.chroot/usr/local/bin/ || echo "f_ai missing"
[ -f "src/sistema/gerenciador_pacotes.sh" ] && cp src/sistema/gerenciador_pacotes.sh config/includes.chroot/usr/local/bin/ || echo "g_pkg missing"
[ -f "src/sistema/usuarios_permissoes.sh" ] && cp src/sistema/usuarios_permissoes.sh config/includes.chroot/usr/local/bin/ || echo "u_perm missing"
[ -f "src/instalador/fydel-install.sh" ] && cp src/instalador/fydel-install.sh config/includes.chroot/usr/local/bin/ || echo "inst missing"

if [ -d "src/instalador/slides" ] && [ "$(ls -A src/instalador/slides 2>/dev/null)" ]; then
  cp -r src/instalador/slides/* config/includes.chroot/opt/fydel/instalador/slides/
fi

if [ -f "./wallpaper.png" ]; then
  cp ./wallpaper.png config/includes.chroot/usr/share/backgrounds/fydel/wallpaper.png
else
  touch config/includes.chroot/usr/share/backgrounds/fydel/wallpaper.png
fi

if [ -f "./logo_menu.png" ]; then
  cp ./logo_menu.png config/includes.chroot/usr/share/icons/fydel/branding/logo_menu.png
else
  touch config/includes.chroot/usr/share/icons/fydel/branding/logo_menu.png
fi

[ -f "./theme.txt" ] && cp ./theme.txt config/includes.chroot/boot/grub/themes/grub-theme-fydel/
[ -f "./colors.txt" ] && cp ./colors.txt config/includes.chroot/boot/grub/themes/grub-theme-fydel/

GRUB_ASSETS="src/sistema/grub/grub-theme-fydel"
if [ -d "$GRUB_ASSETS" ]; then
  [ -f "$GRUB_ASSETS/background.png" ] && cp "$GRUB_ASSETS/background.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  [ -f "$GRUB_ASSETS/logo.png" ] && cp "$GRUB_ASSETS/logo.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  [ -f "$GRUB_ASSETS/splash.png" ] && cp "$GRUB_ASSETS/splash.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  [ -f "$GRUB_ASSETS/grub.png" ] && cp "$GRUB_ASSETS/grub.png" config/includes.chroot/boot/grub/themes/grub-theme-fydel/
  
  cp "$GRUB_ASSETS/splash.png" config/bootloaders/grub/splash.png
  cp "$GRUB_ASSETS/splash.png" config/includes.binary/boot/grub/splash.png
  mkdir -p config/includes.chroot/usr/share/plymouth/themes/fydel/
  cp "$GRUB_ASSETS/splash.png" config/includes.chroot/usr/share/plymouth/themes/fydel/background.png
fi

if [ -d "src/sistema/icones" ] && [ "$(ls -A src/sistema/icones 2>/dev/null)" ]; then
  cp -r src/sistema/icones/* config/includes.chroot/usr/share/icons/fydel/
fi

if [ -d "src/sistema/servicos_systemd" ] && [ "$(ls -A src/sistema/servicos_systemd 2>/dev/null)" ]; then
  cp -r src/sistema/servicos_systemd/* config/includes.chroot/etc/systemd/system/
fi

if [ -d "src/telas" ] && [ "$(ls -A src/telas 2>/dev/null)" ]; then
  cp -r src/telas/* config/includes.chroot/opt/fydel/telas/
fi

if [ -d "src/documentacao" ] && [ "$(ls -A src/documentacao 2>/dev/null)" ]; then
  cp -r src/documentacao/* config/includes.chroot/usr/share/doc/fydelistechos/
fi

chmod +x config/includes.chroot/usr/local/bin/*.sh 2>/dev/null || true
chmod +x config/includes.chroot/usr/local/bin/*.py 2>/dev/null || true

echo "=== 6. Criar Hooks internos ==="
mkdir -p config/hooks/normal
cat << 'EOF' > config/hooks/normal/0500-build-system.hook.chroot
#!/bin/bash
set -e

find /usr/local/bin/ -type f -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

echo "=== [Hook] Clonando e instalando o Tema CyberHack ==="
git clone https://git.disroot.org/eudaimon/CyberHack.git /tmp/CyberHack
mkdir -p /usr/share/themes/CyberHack
cp -r /tmp/CyberHack/gtk-2.0 /usr/share/themes/CyberHack/
cp -r /tmp/CyberHack/gtk-3.0 /usr/share/themes/CyberHack/
cp -r /tmp/CyberHack/xfwm4 /usr/share/themes/CyberHack/
cp -r /tmp/CyberHack/cinnamon /usr/share/themes/CyberHack/ 2>/dev/null || true
cp -r /tmp/CyberHack/metacity-1 /usr/share/themes/CyberHack/ 2>/dev/null || true
cp /tmp/CyberHack/index.theme /usr/share/themes/CyberHack/

mkdir -p /usr/share/Kvantum/CyberHack
if [ -d "/tmp/CyberHack/Kvantum" ]; then
    cp -r /tmp/CyberHack/Kvantum/* /usr/share/Kvantum/ 2>/dev/null || true
fi
rm -rf /tmp/CyberHack

echo "=== [Hook] Configurando Ferramentas Fydelis no PATH ==="
if [ -d /usr/local/bin/fydelis-tools ]; then
  chmod -R +x /usr/local/bin/fydelis-tools/ 2>/dev/null || true
fi

echo "=== [Hook] Instalando o Ollama ==="
curl -fsSL https://ollama.com/install.sh | sh || true

echo "=== [Hook] Inicializando o Ollama para baixar os modelos ==="
ollama serve &
sleep 15

echo "=== [Hook] Baixando Modelo Gemma 2B ==="
ollama pull gemma:2b-instruct-q4_K_M || true

echo "=== [Hook] Baixando Modelo Llama 3.2 3B ==="
ollama pull llama3.2:3b || true

pkill ollama || true
sleep 5

apt-get purge -y desktop-base || true

echo "=== [Hook] Configurando Plymouth ==="
if [ -d /usr/share/plymouth/themes/fydel ]; then
cat << 'PLY' > /usr/share/plymouth/themes/fydel/fydel.plymouth
[Plymouth Theme]
Name=FydelisTechOS Splash
Description=Custom splash screen for FydelisTechOS
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/fydel
ScriptFile=/usr/share/plymouth/themes/fydel/fydel.script
PLY

cat << 'SCR' > /usr/share/plymouth/themes/fydel/fydel.script
wallpaper_image = Image("background.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
resized_image = wallpaper_image.Scale(screen_width, screen_height);
wallpaper_sprite = Sprite(resized_image);
wallpaper_sprite.SetZ(-10);
SCR

plymouth-set-default-theme fydel || true
fi

echo "=== [Hook] Configurando GRUB ==="
if [ -f /etc/default/grub ]; then
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
  sed -i 's/#GRUB_GFXMODE=.*/GRUB_GFXMODE=1024x768,auto/' /etc/default/grub
  echo 'GRUB_THEME="/boot/grub/themes/grub-theme-fydel/theme.txt"' >> /etc/default/grub
  update-grub || true
fi

echo "=== [Hook] Compilando Terminal Híbrido Fydel ==="
if [ -d /usr/local/src/fydel-terminal ]; then
  cd /usr/local/src/fydel-terminal
  make clean && make && make install
fi

chmod +x /usr/local/bin/fydel_ai.py 2>/dev/null || true
chmod +x /usr/local/bin/gerenciador_pacotes.sh 2>/dev/null || true
chmod +x /usr/local/bin/usuarios_permissoes.sh 2>/dev/null || true
chmod +x /usr/local/bin/fydel-install.sh 2>/dev/null || true

ln -sf /usr/local/bin/gerenciador_pacotes.sh /usr/local/bin/fydel-pkg
ln -sf /usr/local/bin/fydel_ai.py /usr/local/bin/fydel-ai
ln -sf /usr/local/bin/fydel-install.sh /usr/local/bin/fydel-install

if [ -f /usr/local/bin/usuarios_permissoes.sh ]; then
  bash /usr/local/bin/usuarios_permissoes.sh
fi

if [ -f /etc/systemd/system/fydelterm.service ]; then
  systemctl daemon-reload
  systemctl enable fydelterm.service
fi

echo "=== [Hook] Injetando Estilização Estilo Cyberpunk/Glassmorphic (CyberHack) ==="
cat << 'CSS' > /usr/share/themes/CyberHack/gnome-shell/gnome-shell.css
#panel, .popup-menu-contents, .search-display, .window-picker, .dash-background {
    background-color: rgba(16, 22, 47, 0.45) !important;
    backdrop-filter: blur(25px) brightness(90%) !important;
    border: 1px solid rgba(34, 211, 238, 0.25) !important;
    border-radius: 20px !important;
    box-shadow: 0 16px 40px 0 rgba(0, 0, 0, 0.6) !important;
}

.show-apps .overview-icon {
    background-image: url("file:///usr/share/icons/fydel/branding/logo_menu.png") !important;
    background-size: contain !important;
    color: transparent !important;
}

.popup-menu-item:focused, .popup-menu-item:active {
    background-color: rgba(106, 17, 203, 0.6) !important;
    color: #ffffff !important;
}

.switch:checked {
    background-color: #3700b3 !important;
}

.window-close, .window-minimize, .window-maximize {
    background-color: rgba(255, 255, 255, 0.1) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    border-radius: 50% !important;
}
CSS

echo "=== [Hook] Compilando e instalando Extensões Visuais (Dock e Blur) ==="
cd /tmp
git clone https://github.com/micheleg/dash-to-dock.git
cd dash-to-dock && git checkout gnome-43 || true
mkdir -p /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com
make
cp -r * /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/
cd /tmp && rm -rf dash-to-dock

git clone https://github.com/aunetx/blur-my-shell.git
cd blur-my-shell && git checkout v43 || true
mkdir -p /usr/share/gnome-shell/extensions/blur-my-shell@aunetx
cp -r * /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/
cd /tmp && rm -rf blur-my-shell

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

echo "=== [Hook] Gerando Ícones e Atalhos para a fileira vertical Esquerda ==="
cat << 'DK' > /etc/skel/Desktop/code.desktop
[Desktop Entry]
Name=Code Editor
Exec=gedit %F
Icon=accessories-text-editor
Type=Application
Terminal=false
DK

cat << 'DK' > /etc/skel/Desktop/terminal.desktop
[Desktop Entry]
Name=Terminal
Exec=gnome-terminal
Icon=utilities-terminal
Type=Application
Terminal=false
DK

cat << 'DK' > /etc/skel/Desktop/git.desktop
[Desktop Entry]
Name=Git Tool
Exec=firefox-esr https://github.com
Icon=vcs-normal
Type=Application
Terminal=false
DK

cat << 'DK' > /etc/skel/Desktop/settings.desktop
[Desktop Entry]
Name=Settings
Exec=gnome-control-center
Icon=org.gnome.Settings
Type=Application
Terminal=false
DK

chmod +x /etc/skel/Desktop/*.desktop

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

echo "export TERM=linux" >> /root/.bashrc
echo -e "\nif [ -f /opt/fydel/telas/tela_boas_vindas.txt ]; then cat /opt/fydel/telas/tela_boas_vindas.txt; fi" >> /root/.bashrc
echo -e "echo -e '\\n\\033[1;35mPara instalar no disco rígido, digite: \\033[1;32mfydel-install\\033[0m\\n'" >> /root/.bashrc
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