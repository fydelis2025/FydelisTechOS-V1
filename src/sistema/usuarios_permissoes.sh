#!/bin/bash
set -e

echo "=== Configurando usuários e permissões Fydelistechos ==="

# Definir senhas criptografadas (SHA-512 robusto)
PASS_ADMIN=$(openssl passwd -6 "FydelAdmin2026!")
PASS_USUARIO=$(openssl passwd -6 "Usuario2026!")

# Criar grupos do sistema
groupadd -f fydel-admin
groupadd -f fydel-users

# Usuário ADMIN
if ! id -u admin &>/dev/null; then
    useradd -m -g fydel-admin -G sudo,adm,netdev,storage,video,audio,bluetooth \
        -c "Administrador Fydelistechos" -s /usr/local/bin/fydelterm \
        -p "$PASS_ADMIN" admin
    echo "✅ Usuário admin criado"
fi

# Usuário COMUM
if ! id -u usuario &>/dev/null; then
    useradd -m -g fydel-users -G users,audio,video,bluetooth \
        -c "Usuário Padrão Fydelistechos" -s /usr/local/bin/fydelterm \
        -p "$PASS_USUARIO" usuario
    echo "✅ Usuário usuario criado"
fi

# ==================== SUGERIDO / CORRIGIDO ====================
# Garante que o arquivo do terminal existe antes de aplicar as permissões
if [ -f /usr/local/bin/fydelterm ]; then
    # root:root garante propriedade segura de sistema
    chown root:root /usr/local/bin/fydelterm
    
    # 755 -> Dono (root) pode ler/escrever/executar. 
    # Grupos e Outros (admin e usuario) podem APENAS ler e EXECUTAR.
    chmod 755 /usr/local/bin/fydelterm
    echo "✅ Permissões seguras aplicadas ao fydelterm"
else
    echo "⚠️ Aviso: Binário /usr/local/bin/fydelterm não encontrado para aplicar permissões ainda."
fi
# ==============================================================

# Regras de sudo para o grupo fydel-admin
# Adicionado '\n' para garantir conformidade estrita com as regras do sudoers
echo -e "%fydel-admin ALL=(ALL:ALL) ALL\n" > /etc/sudoers.d/fydel-admin
chmod 440 /etc/sudoers.d/fydel-admin

echo "✅ Perfis e permissões configurados com sucesso!"
