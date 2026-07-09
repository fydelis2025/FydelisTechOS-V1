#!/bin/bash
set -e

echo "=== Configurando usuários e permissões Fydelistechos ==="

# Definir senhas criptografadas (SHA-512 robusto)
PASS_ADMIN=$(openssl passwd -6 "FydelAdmin2026!")
PASS_USUARIO=$(openssl passwd -6 "Usuario2026!")

# Criar grupos do sistema
groupadd -f fydel-admin
groupadd -f fydel-users

# Usuário ADMIN (Corrigido: Adicionado grupo tty e corrigido storage para plugdev)
if ! id -u admin &>/dev/null; then
    useradd -m -g fydel-admin -G sudo,adm,tty,netdev,plugdev,video,audio,bluetooth \
        -c "Administrador Fydelistechos" -s /usr/local/bin/fydelterm \
        -p "$PASS_ADMIN" admin
    echo "✅ Usuário admin criado e associado ao grupo TTY"
fi

# Usuário COMUM (Corrigido: Adicionado grupo tty para não quebrar o fydelterm.service)
if ! id -u usuario &>/dev/null; then
    useradd -m -g fydel-users -G users,tty,audio,video,bluetooth \
        -c "Usuário Padrão Fydelistechos" -s /usr/local/bin/fydelterm \
        -p "$PASS_USUARIO" usuario
    echo "✅ Usuário usuario criado e associado ao grupo TTY"
fi

# ==================== CONTROLO DE PERMISSÕES DO BINÁRIO ====================
if [ -f /usr/local/bin/fydelterm ]; then
    chown root:root /usr/local/bin/fydelterm
    chmod 755 /usr/local/bin/fydelterm
    echo "✅ Permissões seguras aplicadas ao fydelterm"
else
    echo "⚠️ Aviso: Binário /usr/local/bin/fydelterm não encontrado para aplicar permissões."
fi
