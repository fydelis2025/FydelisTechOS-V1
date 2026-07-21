#include <iostream>
#include <string>
#include <chrono>
#include <thread>
#include <ctime>
#include <cstdlib>
#include <termios.h>
#include <unistd.h>
#include <signal.h>
#include <fstream>    
#include "fydel_api.h"

// ===================== DEFINIÇÕES DE CORES (ESTILO HACKER) =====================
#define COR_RESET       "\033[0m"
#define COR_FUNDO       "\033[40m"            // Preto absoluto
#define COR_VERDE_CLI   "\033[38;2;0;255;0m"    // Verde Hacker Neon Brilhante
#define COR_ROXO        "\033[38;2;120;90;255m" 
#define COR_CINZA       "\033[38;2;150;155;165m"
#define COR_VERMELHO    "\033[38;2;255;80;80m"

int fd_mestre = -1;
int fd_escravo = -1;

// Tratamento de sinais para fechamento limpo em caso de interrupção (Ctrl+C)
void sinal_handler(int sig) {
    std::cout << COR_RESET << "\n[!] Interrupção detectada. Fechando sessão...\n";
    pty_fechar();
    exit(0);
}

void limpar_tela() {
    // Sequência ANSI robusta para limpar buffer, resetar o terminal e aplicar fundo preto
    std::cout << "\033[H\033[2J\033[3J" << COR_FUNDO << COR_VERDE_CLI;
    std::cout << std::flush;
}

void exibir_boas_vindas() {
    limpar_tela();
    // Tenta carregar o banner oficial da ISO
    std::ifstream arquivo("/usr/share/fydel/telas/tela_boas_vindas.txt");
    if (arquivo.is_open()) {
        std::string linha;
        while (std::getline(arquivo, linha)) {
            std::cout << COR_VERDE_CLI << linha << "\n";
        }
        arquivo.close();
    } else {
        // Fallback elegante
        std::cout << COR_VERDE_CLI << "========================================================\n";
        std::cout << "           FYDELISTECHOS — SECURE TERMINAL v1.0         \n";
        std::cout << "========================================================\n\n";
    }
}

int main() {
    // Registra os sinais de interrupção para segurança do terminal
    signal(SIGINT, sinal_handler);
    signal(SIGTERM, sinal_handler);

    // Inicializar PTY via Assembly de Baixo Nível
    if (pty_iniciar(&fd_mestre, &fd_escravo) != 0) {
        std::cerr << COR_VERMELHO << "❌ Erro ao iniciar o terminal PTY nativo!\n" << COR_RESET;
        return 1;
    }

    // Validação robusta de ambiente
    if (!verificar_drivers() || !verificar_montagem_pts() || !verificar_permissoes()) {
        std::cerr << COR_VERMELHO << "❌ Verificação do ecossistema falhou! Abortando por segurança.\n" << COR_RESET;
        pty_fechar();
        return 1;
    }

    // Exibe banner de boas-vindas estilo hacker
    exibir_boas_vindas();

    // Mensagem de boas-vindas ao terminal direto
    std::cout << COR_ROXO << "┌────────────────────────────────────────────────────────┐\n";
    std::cout << "│ " << COR_VERDE_CLI << "  FydelisTechOS Terminal Ativo & Seguro (PTY)        " << COR_ROXO << "│\n";
    std::cout << "└────────────────────────────────────────────────────────┘\n\n" << COR_RESET;
    
    std::cout << COR_CINZA << "[+] Ambiente pronto. Digite 'exit' para encerrar a sessão.\n\n" << COR_RESET;

    // Garante que o verde hacker continue ativo antes de passar o controle
    std::cout << COR_VERDE_CLI;

    // Configura o TERM para o clear funcionar perfeitamente no bash interno
    write(fd_mestre, "export TERM=xterm-256color\n", 28);
    
    // Passa o controle imediatamente para o bash interativo em Assembly (Direto ao PTY)
    pty_loop(fd_mestre);

    // Encerramento limpo ao sair do shell
    pty_fechar();
    std::cout << COR_VERDE_CLI << "\n[+] Sessão segura encerrada. Até logo, operador!\n" << COR_RESET;
    std::cout << COR_RESET;
    return 0;
}
