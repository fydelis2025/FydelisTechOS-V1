#!/bin/bash
set -e

# 🎨 Cores
AZUL="\033[1;34m"
ROXO="\033[1;35m"
VERDE="\033[1;32m"
VERMELHO="\033[1;31m"
RESET="\033[0m"

limpar_tela() { clear; }

menu_principal() {
    limpar_tela
    echo -e "${ROXO}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${ROXO}║        GERENCIADOR DE PACOTES FYDEL       ║${RESET}"
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
            apt update
            ;;
        2)
            read -p "Digite o nome do pacote: " pacote
            echo -e "\n${VERDE}📥 Instalando $pacote...${RESET}"
            apt install -y "$pacote"
            ;;
        3)
            read -p "Digite o nome do pacote: " pacote
            echo -e "\n${VERMELHO}🗑️ Removendo $pacote...${RESET}"
            apt remove -y "$pacote"
            ;;
        4)
            echo -e "\n${VERDE}⬆️ Atualizando sistema completo...${RESET}"
            apt full-upgrade -y
            ;;
        5)
            read -p "Digite termo para busca: " termo
            echo -e "\n${AZUL}🔍 Resultados da busca:${RESET}"
            apt search "$termo"
            ;;
        6)
            echo -e "\n${AZUL}📋 Pacotes instalados:${RESET}"
            dpkg -l | less
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "\n${VERMELHO}❌ Opção inválida!${RESET}"
            sleep 1
            ;;
    esac
    echo -e "\nPressione ENTER para continuar..."
    read -r
done