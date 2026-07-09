#!/bin/bash
set -e

# 🎨 Cores
AZUL="\033[1;34m"
ROXO="\033[1;35m"
VERDE="\033[1;32m"
VERMELHO="\033[1;31m"
RESET="\033[0m"

# 🛡️ Garantir que comandos do APT rodem sem travar a TTY em prompts visuais
EXPORT_APT="DEBIAN_FRONTEND=noninteractive"

limpar_tela() { clear; }

# VALIDAÇÃO DE PRIVILÉGIOS (Essencial para não falhar os comandos do APT)
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Erro: Este gerenciador de pacotes precisa ser executado como ROOT (Sudo).${RESET}"
    exit 1
fi

menu_principal() {
    limpar_tela
    echo -e "${ROXO}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${ROXO}║        GERENCIADOR DE PACOTES FYDELIS      ║${RESET}"
    echo -e "${ROXO}╚════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${AZUL} 1${RESET} → Atualizar lista de pacotes"
    echo -e "${AZUL} 2${RESET} → Instalar pacote"
    echo -e "${AZUL} 3${RESET} → Remover pacote"
    echo -e "${AZUL} 4${RESET} → Atualizar sistema completo"
    echo -e "${AZUL} 5${RESET} → Procurar pacote"
    echo -e "${AZUL} 6${RESET} → Verificar pacotes instalados"
    echo -e "${AZUL} 0${RESET} → Voltar ao menu principal"
    echo ""
    read -p "Escolha uma opção: " opcao
}

while true; do
    menu_principal
    case $opcao in
        1)
            echo -e "\n${VERDE}🔄 Atualizando lista de pacotes...${RESET}"
            env $EXPORT_APT apt update
            ;;
        2)
            read -p "Digite o nome do pacote: " pacote
            if [ -z "$pacote" ]; then continue; fi
            echo -e "\n${VERDE}📥 Instalando $pacote de forma segura...${RESET}"
            env $EXPORT_APT apt install -y "$pacote"
            ;;
        3)
            read -p "Digite o nome do pacote: " pacote
            if [ -z "$pacote" ]; then continue; fi
            echo -e "\n${VERMELHO}🗑️ Removendo $pacote...${RESET}"
            env $EXPORT_APT apt remove -y "$pacote"
            ;;
        4)
            echo -e "\n${VERDE}⬆️ Atualizando sistema completo...${RESET}"
            env $EXPORT_APT apt full-upgrade -y
            ;;
        5)
            read -p "Digite termo para busca: " termo
            if [ -z "$termo" ]; then continue; fi
            echo -e "\n${AZUL}🔍 Resultados da busca:${RESET}"
            apt search "$termo"
            ;;
        6)
            echo -e "\n${AZUL}📋 Pacotes instalados no FydelisTechOS:${RESET}"
            apt list --installed
            ;;
        0)
            echo -e "\n${AZUL}Voltando ao menu operacional...${RESET}"
            exit 0
            ;;
        *)
            echo -e "\n${VERMELHO}❌ Opção inválida!${RESET}"
            ;;
    esac
    echo ""
    read -p "Pressione [ENTER] para continuar..." continua
done
