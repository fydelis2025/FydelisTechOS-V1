#include <iostream>
#include <string>
#include <chrono>
#include <thread>
#include <ctime>
#include <cstdlib>
#include <termios.h>
#include <unistd.h>
#include <fstream>   
#include "fydel_api.h"

// ===================== DEFINIÇÕES DE CORES =====================
#define COR_RESET       "\033[0m"
#define COR_FUNDO       "\033[48;2;8;12;32m"    
#define COR_BRANCO      "\033[38;2;245;248;255m"
#define COR_ROXO        "\033[38;2;120;90;255m" 
#define COR_AZUL        "\033[38;2;64;128;255m" 
#define COR_AMARELO     "\033[38;2;255;200;0m"
#define COR_VERDE       "\033[38;2;80;220;100m"
#define COR_VERMELHO    "\033[38;2;255;80;80m"
#define COR_CINZA       "\033[38;2;150;155;165m"

int fd_mestre = -1;
int fd_escravo = -1;

void limpar_tela() {
    std::cout << "\033[2J\033[H" << COR_FUNDO;
}

void exibir_boas_vindas() {
    limpar_tela();
    // Tenta carregar o banner oficial da ISO
    std::ifstream arquivo("/usr/share/fydel/telas/tela_boas_vindas.txt");
    if (arquivo.is_open()) {
        std::string linha;
        while (std::getline(arquivo, linha)) {
            std::cout << COR_BRANCO << linha << "\n";
        }
        arquivo.close();
    } else {
        // Fallback elegante se a ISO não tiver o arquivo no chroot
        std::cout << COR_VERDE << "========================================\n";
        std::cout << "         FYDELISTECH OS TERMINAL        \n";
        std::cout << "========================================\n" << COR_RESET;
    }
}

void exibir_dashboard() {
    limpar_tela();
    std::cout << COR_ROXO << "╔════════════════════════════════════════════════════════╗\n";
    std::cout << "║             📊 CORE PERFORMANCE DASHBOARD             ║\n";
    std::cout << "╚════════════════════════════════════════════════════════╝\n" << COR_RESET;

    std::cout << COR_AZUL << "  [+] CPU:    " << COR_AMARELO << obter_uso_cpu() << "%\n";
    std::cout << COR_AZUL << "  [+] RAM:    " << COR_AMARELO << obter_uso_ram() << "%\n";
    std::cout << COR_AZUL << "  [+] DISK:   " << COR_AMARELO << obter_uso_disco() << "%\n";
    std::cout << COR_AZUL << "  [+] NET:    " << COR_AMARELO << obter_velocidade_rede() << " Mbps\n\n" << COR_RESET;
}

void renderizar_menu() {
    exibir_boas_vindas();
    std::cout << COR_AZUL << "\n  [1] " << COR_BRANCO << "Abrir Shell Seguro (Bash PTY)\n";
    std::cout << COR_AZUL << "  [2] " << COR_BRANCO << "Verificar Saúde do Kernel / Sistema\n";
    std::cout << COR_AZUL << "  [3] " << COR_BRANCO << "Monitor de Recursos em Tempo Real\n";
    std::cout << COR_AZUL << "  [0] " << COR_VERMELHO << "Encerrar Sessão\n\n" << COR_RESET;
    std::cout << COR_ROXO << "  FydelisTechOS > " << COR_RESET;
}

void gerenciar_opcoes() {
    int opcao = -1;
    if (!(std::cin >> opcao)) {
        std::cin.clear();
        std::cin.ignore(10000, '\n');
        return;
    }

    switch (opcao) {
        case 1:
            limpar_tela();
            // Mensagem de impacto personalizada com as cores do seu sistema
            std::cout << COR_ROXO << "┌────────────────────────────────────────────────────────┐\n";
            std::cout << "│ " << COR_VERDE  << " ⚡ Você está utilizando o terminal da FydelisTechOS  " << COR_ROXO << "│\n";
            std::cout << "└────────────────────────────────────────────────────────┘\n\n" << COR_RESET;
            
            // Opcional: Uma pequena linha de status
            std::cout << COR_CINZA << "[+] Ambiente PTY seguro ativado. Digite 'exit' para retornar ao menu.\n\n" << COR_RESET;
            
            // Passa o controle para o bash interativo em Assembly
            pty_loop(fd_mestre);
            break;
        case 2:
            limpar_tela();
            std::cout << COR_ROXO << "--- DIAGNÓSTICO DE AMBIENTE ---\n" << COR_RESET;
            std::cout << " Drivers PTY:   " << (verificar_drivers() ? "🟢 OK" : "🔴 FALHA") << "\n";
            std::cout << " Montagem /pts: " << (verificar_montagem_pts() ? "🟢 OK" : "🔴 FALHA") << "\n";
            std::cout << " Permissões:    " << (verificar_permissoes() ? "🟢 OK" : "🔴 FALHA") << "\n";
            break;
        case 3:
            exibir_dashboard();
            break;
        case 0:
            std::cout << COR_VERDE << "\n👋 Encerrando sessão... Até logo!\n" << COR_RESET;
            std::this_thread::sleep_for(std::chrono::seconds(1));
            pty_fechar();
            exit(0);
        default:
            std::cout << COR_VERMELHO << "\n❌ Opção inválida!\n" << COR_RESET;
            break;
    }

    std::cout << "\n\n  " << COR_CINZA << "Pressione ENTER para voltar ao menu..." << COR_RESET;
    std::cin.ignore(10000, '\n'); std::cin.get();
}

int main() {
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

    while (true) {
        renderizar_menu();
        gerenciar_opcoes();
    }

    return 0;
}
