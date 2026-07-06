#include <iostream>
#include <string>
#include <chrono>
#include <thread>
#include <ctime>
#include <cstdlib>
#include <termios.h>
#include <unistd.h>
#include <fstream>   // Corrigido: Include essencial para leitura de arquivos de texto
#include "fydel_api.h"

// ===================== DEFINIÇÕES DE CORES =====================
#define COR_RESET       "\033[0m"
#define COR_FUNDO       "\033[48;2;8;12;32m"    // #080C20
#define COR_BRANCO      "\033[38;2;245;248;255m"// #F5F8FF
#define COR_ROXO        "\033[38;2;120;90;255m" // #785AFF
#define COR_AZUL        "\033[38;2;64;128;255m" // #4080FF
#define COR_AMARELO     "\033[38;2;255;200;0m"
#define COR_VERDE       "\033[38;2;80;220;100m"
#define COR_VERMELHO    "\033[38;2;255;80;80m"
#define COR_CINZA       "\033[38;2;180;180;200m"

// ===================== VARIÁVEIS GLOBAIS =====================
int fd_mestre = -1;
int fd_escravo = -1;

// Declaração avançada para evitar problemas de escopo
void tela_principal();

// ===================== FUNÇÕES AUXILIARES =====================
void limpar_tela() {
    std::cout << "\033[H\033[J";
}

void modo_texto() {
    struct termios t;
    tcgetattr(STDIN_FILENO, &t);
    t.c_lflag |= ICANON | ECHO;
    tcsetattr(STDIN_FILENO, TCSANOW, &t);
}

void modo_cru() {
    struct termios t;
    tcgetattr(STDIN_FILENO, &t);
    t.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &t);
}

std::string barra(int valor) {
    const int tam = 20;
    int preenchido = (valor * tam) / 100;
    std::string b = "[";
    for (int i = 0; i < tam; i++) {
        // Corrigido: Conversão explícita para std::string evita o erro do operador+ binário
        if (i < preenchido) b += std::string(COR_ROXO) + "■" + COR_BRANCO;
        else b += std::string(COR_CINZA) + "□" + COR_BRANCO;
    }
    b += "] " + std::to_string(valor) + "%";
    return b;
}

// ===================== TELAS DO SISTEMA =====================

// 🚀 Tela de Inicialização / Splash
void tela_splash() {
    limpar_tela();
    std::cout << COR_FUNDO << COR_BRANCO;
    std::cout << "\n\n\n\n";

    std::cout << "            " << COR_ROXO << "███████╗██╗   ██╗██████╗ ██████╗ ██╗     ██╗███████╗████████╗" << COR_BRANCO << "\n";
    std::cout << "            " << COR_ROXO << "██╔════╝╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██║██╔════╝╚══██╔══╝" << COR_BRANCO << "\n";
    std::cout << "            " << COR_ROXO << "█████╗   ╚████╔╝ ██████╔╝██║  ██║██║     ██║█████╗     ██║   " << COR_BRANCO << "\n";
    std::cout << "            " << COR_ROXO << "██╔══╝    ╚██╔╝  ██╔══██╗██║  ██║██║     ██║██╔══╝     ██║   " << COR_BRANCO << "\n";
    std::cout << "            " << COR_ROXO << "██║         ██║   ██║  ██║██████╔╝███████╗██║██║         ██║   " << COR_BRANCO << "\n";
    std::cout << "            " << COR_ROXO << "╚═╝         ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝╚═╝         ╚═╝   " << COR_BRANCO << "\n";

    std::cout << "\n\n";
    std::cout << "                    " << COR_AZUL << "Sistema Operacional Fydelistech v1.0" << COR_BRANCO << "\n";
    std::cout << "                " << COR_CINZA << "Carregando módulos e programas..." << COR_BRANCO << "\n";
    std::cout << "\n";
    std::cout << "                [■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■] 100%\n";
    std::cout << COR_RESET;

    std::this_thread::sleep_for(std::chrono::seconds(2));
}

// ℹ️ Tela Boas Vindas o Fydelistechos
void exibir_boas_vindas() {
    limpar_tela();
    // Procura o arquivo no local onde a ISO o vai instalar
    std::ifstream arquivo("/usr/share/fydel/telas/tela_boas_vindas.txt");
    
    if (arquivo.is_open()) {
        std::string linha;
        std::cout << COR_FUNDO << COR_BRANCO;
        while (getline(arquivo, linha)) {
            std::cout << "  " << linha << "\n";
        }
        arquivo.close();
    } else {
        // Fallback caso o arquivo não seja encontrado
        std::cout << COR_VERDE << "\n🚀 BEM-VINDO AO FYDELISTECHOS OS v1.0\n" << COR_RESET;
    }

    std::cout << "\n  " << COR_CINZA << "Pressione ENTER para entrar no sistema..." << COR_RESET;
    std::cin.ignore(10000, '\n'); std::cin.get();
}

// ℹ️ Tela Sobre o Fydelistechos
void tela_sobre() {
    limpar_tela();
    std::cout << COR_FUNDO << COR_BRANCO << "\n\n";

    std::cout << "  " << COR_ROXO << "╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "  ║                    🚀 FYDELISTECHOS OS v1.0              ║\n";
    std::cout << "  ╠════════════════════════════════════════════════════════════╣\n";
    std::cout << "  ║                                                            ║\n";
    std::cout << "  ║  Desenvolvido por: Fydelistechos Tecnologia                ║\n";
    std::cout << "  ║  Base: Debian GNU/Linux 12 (Bookworm) estável              ║\n";
    std::cout << "  ║  Versão: 1.0 - Julho/2026                                  ║\n";
    std::cout << "  ║  Licença: GPL v3 - Código aberto e livre                   ║\n";
    std::cout << "  ║                                                            ║\n";
    std::cout << "  ║  🎯 Objetivo: Sistema seguro, leve e personalizado,        ║\n";
    std::cout << "  ║  com foco em desempenho e facilidade de uso.               ║\n";
    std::cout << "  ║                                                            ║\n";
    std::cout << "  ║  ✨ Características:                                       ║\n";
    std::cout << "  ║  • Terminal próprio desenvolvido em Assembly + C/C++      ║\n";
    std::cout << "  ║  • Gerenciador de pacotes compatível com repositórios      ║\n";
    std::cout << "  ║  • Interface personalizada e intuitiva                     ║\n";
    std::cout << "  ║  • Ferramentas completas para uso diário e segurança       ║\n";
    std::cout << "  ║                                                            ║\n";
    std::cout << "  📧 Contato: suporte@fydelistechos.com.br                     ║\n";
    std::cout << "  🌐 Site: https://fydelistechos.com.br                        ║\n";
    std::cout << "  ║                                                            ║\n";
    std::cout << "  ╚════════════════════════════════════════════════════════════╝\n";

    std::cout << "\n  " << COR_CINZA << "Pressione ENTER para voltar ao menu principal..." << COR_RESET;
    std::cin.ignore(10000, '\n'); std::cin.get();
}

// ⚙️ Painel de Controle do Sistema
void tela_painel_controle() {
    while (true) {
        limpar_tela();
        std::cout << COR_FUNDO << COR_BRANCO << "\n\n";

        std::cout << "  " << COR_ROXO << "╔════════════════════════════════════════════════════════════╗\n";
        std::cout << "  ║                  ⚙️ PAINEL DE CONTROLE                    ║\n";
        std::cout << "  ╠════════════════════════════════════════════════════════════╣\n";
        std::cout << "  ║                                                            ║\n";
        std::cout << "  ║  Escolha uma opção de configuração:                        ║\n";
        std::cout << "  ║                                                            ║\n";
        std::cout << "  ║  " << COR_AMARELO << "[1]" << COR_BRANCO << " 👤 Gerenciar usuários e senhas                 ║\n";
        std::cout << "  ║  " << COR_AMARELO << "[2]" << COR_BRANCO << " 🌐 Configurações de rede e internet           ║\n";
        std::cout << "  ║  " << COR_AMARELO << "[3]" << COR_BRANCO << " 🔊 Configurações de som e vídeo                ║\n";
        std::cout << "  ║  " << COR_AMARELO << "[4]" << COR_BRANCO << " 📅 Data, hora e fuso horário                  ║\n";
        std::cout << "  ║  " << COR_AMARELO << "[5]" << COR_BRANCO << " 🔄 Atualizações e manutenção do sistema        ║\n";
        std::cout << "  ║  " << COR_AMARELO << "[6]" << COR_BRANCO << " ℹ️ Sobre o Fydelistechos OS                    ║\n";
        std::cout << "  ║  " << COR_AMARELO << "[0]" << COR_BRANCO << " ⬅️ Voltar ao menu principal                    ║\n";
        std::cout << "  ║                                                            ║\n";
        std::cout << "  ╚════════════════════════════════════════════════════════════╝\n";

        std::cout << "\n  Digite a opção desejada: ";
        char op;
        std::cin >> op;

        if (op == '0') {
            return; 
        }

        switch(op) {
            case '1':
                limpar_tela();
                std::cout << COR_VERDE << "\n👤 Abrindo gerenciamento de usuários...\n" << COR_RESET;
                system("gnome-control-center user-accounts &>/dev/null &");
                break;
            case '2':
                limpar_tela();
                std::cout << COR_VERDE << "\n🌐 Abrindo configurações de rede...\n" << COR_RESET;
                system("nm-connection-editor &>/dev/null &");
                break;
            case '3':
                limpar_tela();
                std::cout << COR_VERDE << "\n🔊 Abrindo configurações de áudio e vídeo...\n" << COR_RESET;
                system("gnome-control-center sound &>/dev/null &");
                break;
            case '4':
                limpar_tela();
                std::cout << COR_VERDE << "\n📅 Abrindo configurações de data e hora...\n" << COR_RESET;
                system("gnome-control-center datetime &>/dev/null &");
                break;
            case '5':
                limpar_tela();
                std::cout << COR_VERDE << "\n🔄 Abrindo gerenciador de pacotes para atualizações...\n" << COR_RESET;
                system("fydel-pkg");
                break;
            case '6':
                tela_sobre();
                continue;
            default:
                std::cout << COR_VERMELHO << "\n❌ Opção inválida! Digite um número entre 0 e 6.\n" << COR_RESET;
                break;
        }

        std::cout << "\n\n  " << COR_CINZA << "Pressione ENTER para continuar..." << COR_RESET;
        std::cin.ignore(10000, '\n'); std::cin.get();
    }
}

// 📋 Menu Principal
void tela_principal() {
    limpar_tela();
    std::cout << COR_FUNDO << COR_BRANCO;

    time_t agora = time(nullptr);
    struct tm *t = localtime(&agora);
    const char *dias[] = {"Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"};
    std::string saudacao = "ÓTIMA " + std::string(dias[t->tm_wday]) + "!";

    std::cout << "\n  " << COR_ROXO << "fydelistechos v1.0" << COR_BRANCO << " | Base Debian GNU/Linux 12\n\n";
    std::cout << "  ┌─────────────────────────────────────────────────────────────────────┐\n";
    std::cout << "  │                                                                     │\n";
    std::cout << "  │                    " << saudacao << "                                    │\n";
    std::cout << "  │                                                                     │\n";
    std::cout << "  └─────────────────────────────────────────────────────────────────────┘\n\n";

    std::cout << "  " << COR_AZUL << "📂 MÓDULOS E PROGRAMAS" << COR_BRANCO << "                      " << COR_AZUL << "📊 MONITORAMENTO" << COR_BRANCO << "\n";
    std::cout << "  ───────────────────────────────────────────────────────────────────────────────────\n";

    std::cout << "  " << COR_AMARELO << "[1]" << COR_ROXO << " 📄 " << COR_BRANCO << "LibreOffice (Escritório)          " << COR_AZUL << "CPU:  " << COR_BRANCO << barra(obter_uso_cpu()) << "\n";
    std::cout << "  " << COR_AMARELO << "[2]" << COR_ROXO << " 🌐 " << COR_BRANCO << "Firefox (Navegador Web)            " << COR_AZUL << "RAM:  " << COR_BRANCO << barra(obter_uso_ram()) << "\n";
    std::cout << "  " << COR_AMARELO << "[3]" << COR_ROXO << " 💾 " << COR_BRANCO << "GParted / Discos                   " << COR_AZUL << "DISCO:" << COR_BRANCO << barra(obter_uso_disco()) << "\n";
    std::cout << "  " << COR_AMARELO << "[4]" << COR_ROXO << " 📶 " << COR_BRANCO << "Gerenciador de Redes               " << COR_AZUL << "REDE: " << COR_BRANCO << obter_velocidade_rede() / 1000.0 << " KB/s\n";
    std::cout << "  " << COR_AMARELO << "[5]" << COR_ROXO << " ⚙️ " << COR_BRANCO << "Painel de Controle do Sistema\n";
    std::cout << "  " << COR_AMARELO << "[6]" << COR_ROXO << " 📦 " << COR_BRANCO << "Gerenciador de Pacotes FYDEL\n";
    std::cout << "  " << COR_AMARELO << "[7]" << COR_ROXO << " 🔒 " << COR_BRANCO << "Ferramentas de Segurança\n";
    std::cout << "  " << COR_AMARELO << "[8]" << COR_ROXO << " 💻 " << COR_BRANCO << "Terminal de Comandos\n";
    std::cout << "  " << COR_AMARELO << "[9]" << COR_ROXO << " 🤖 " << COR_BRANCO << "Assistente FydelisTech-AI\n";
    std::cout << "  " << COR_AMARELO << "[0]" << COR_ROXO << " 🚪 " << COR_BRANCO << "Sair da Sessão\n\n";

    std::cout << "  ───────────────────────────────────────────────────────────────────────────────────\n";
    std::cout << "  Escolha uma opção: ";
    std::cout << COR_RESET;
}

// 🚀 Executar ações e programas
void executar_opcao(int opcao) {
    modo_texto();
    limpar_tela();
    std::cout << COR_FUNDO << COR_BRANCO << "\n🔄 Carregando...\n";

    switch(opcao) {
        case 1:
            std::cout << COR_VERDE << "\n📄 Abrindo LibreOffice...\n" << COR_RESET;
            system("libreoffice &>/dev/null &");
            break;
        case 2:
            std::cout << COR_VERDE << "\n🌐 Abrindo Firefox...\n" << COR_RESET;
            system("firefox &>/dev/null &");
            break;
        case 3:
            std::cout << COR_VERDE << "\n💾 Abrindo Gerenciador de Discos...\n" << COR_RESET;
            system("gparted &>/dev/null &");
            break;
        case 4:
            std::cout << COR_VERDE << "\n📶 Abrindo Configurações de Rede...\n" << COR_RESET;
            system("nm-connection-editor &>/dev/null &");
            break;
        case 5:
            tela_painel_controle();
            return; 
        case 6:
            std::cout << COR_VERDE << "\n📦 Abrindo Gerenciador de Pacotes...\n" << COR_RESET;
            system("fydel-pkg");
            break;
        case 7:
            std::cout << COR_VERDE << "\n🔒 Ferramentas de Segurança disponíveis:\n";
            std::cout << "→ nmap, wireshark, metasploit, sqlmap, aircrack-ng, hydra, john\n";
            break;
        case 8:
            std::cout << COR_VERDE << "\n💻 Iniciando Terminal Interativo...\n" << COR_RESET;
            modo_cru();
            pty_loop(fd_mestre);
            return;
        case 9:
           std::cout << COR_VERDE << "\n🤖 Conectando ao núcleo FydelisTech-AI...\n" << COR_RESET;
            modo_texto(); 
            
            // Executa o link simbólico diretamente instalado no sistema
            system("/usr/local/bin/fydel-ai"); 
            
            // Garante que o terminal pause ao sair da IA para não quebrar o layout do menu
            std::cout << "\n\n  " << COR_CINZA << "Sessão IA encerrada. Pressione ENTER para retornar ao menu..." << COR_RESET;
            std::cin.ignore(10000, '\n'); std::cin.get();
            return;
        case 0:
            std::cout << COR_VERDE << "\n👋 Encerrando sessão... Até logo!\n" << COR_RESET;
            std::this_thread::sleep_for(std::chrono::seconds(1));
            pty_fechar();
            exit(0);
        default:
            // Corrigido: Texto ajustado para incluir a opção 9 no escopo de opções válidas
            std::cout << COR_VERMELHO << "\n❌ Opção inválida! Escolha um número de 0 a 9.\n" << COR_RESET;
            break;
    }

    std::cout << "\n\n  " << COR_CINZA << "Pressione ENTER para voltar ao menu..." << COR_RESET;
    std::cin.ignore(10000, '\n'); std::cin.get();
}

// ===================== FUNÇÃO PRINCIPAL =====================
int main() {
    // Inicializar PTY
    if (pty_iniciar(&fd_mestre, &fd_escravo) != 0) {
        std::cerr << COR_VERMELHO << "❌ Erro ao iniciar o terminal PTY!\n" << COR_RESET;
        return 1;
    }

    // Verificar sistema
    if (!verificar_drivers() || !verificar_montagem_pts() || !verificar_permissoes()) {
        std::cerr << COR_VERMELHO << "❌ Verificação do sistema falhou!\n" << COR_RESET;
        return 1;
    }

    // Fluxo principal controlado por loop iterativo
    tela_splash();

    char opcao;
    while (true) {
        tela_principal();
        std::cin >> opcao;
        executar_opcao(opcao - '0');
    }

    return 0;
}
