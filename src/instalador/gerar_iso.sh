#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute como root!"
    exit 1
fi

echo "=== Gerando ISO Fydelistechos OS v1.0 ==="

apt update && apt install -y live-build debootstrap xorriso rsync

mkdir -p /tmp/fydel-iso
cd /tmp/fydel-iso

lb config --distribution bookworm --architectures amd64 --archive-areas "main contrib non-free non-free-firmware"

cp -r /caminho/para/seu/projeto/fydelistechos-os/* config/includes.chroot/opt/fydel/

lb build

mv live-image-amd64.hybrid.iso ~/Fydelistechos-OS-v1.0.iso

echo "✅ ISO gerada com sucesso: ~/Fydelistechos-OS-v1.0.iso"