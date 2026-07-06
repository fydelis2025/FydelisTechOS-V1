# FydelisTechOS-V1
# 📘 Guia do Usuário - FydelisTechOS v1.0

Bem-vindo ao manual oficial do **FydelisTechOS**, um sistema operacional seguro, leve e customizado construído sobre a arquitetura estável do Debian 12 Bookworm. Este guia foi projetado para orientar você desde o primeiro boot até a administração avançada do sistema.

---

## 🚀 1. Primeiro Boot e Inicialização

Ao ligar o computador com o FydelisTechOS, você passará pelas seguintes etapas visuais:

1. **Menu do GRUB**: Uma interface personalizada com fundo escuro (#080C20) e logotipo centralizado onde você pode escolher iniciar o sistema ou entrar direto no instalador.
2. **Tela Splash**: Uma animação em alta definição na cor roxa informando o carregamento dos módulos do sistema.
3. **Prompt de Autenticação**: O sistema solicitará as credenciais de acesso para garantir a segurança dos dados.

### 👥 Perfis de Usuário Padrão (Ambiente Live/Instalado)
* **Administrador (admin)**:
  * **Login**: `admin`
  * **Senha Padrão**: `FydelAdmin2026!`
  * **Privilégios**: Execução de comandos via `sudo`, gerenciamento de rede, discos e segurança.
* **Usuário Comum (usuario)**:
  * **Login**: `usuario`
  * **Senha Padrão**: `Usuario2026!`
  * **Privilégios**: Uso geral do sistema, internet, som e mídia. Não possui acesso de escrita a binários do sistema.

---

## 💻 2. Navegação na Interface Central (`fydelterm`)

O coração do FydelisTechOS é o seu terminal híbrido interativo executado no TTY1. Ele exibe o monitoramento de hardware em tempo real (CPU, RAM, Disco e Rede) e um menu numérico para disparar aplicações:

* `[1]` **LibreOffice**: Suíte completa de escritório (Textos, Planilhas e Apresentações).
* `[2]` **Firefox**: Navegador web oficial pré-configurado.
* `[3]` **GParted / Discos**: Ferramentas avançadas para análise e particionamento de armazenamento.
* `[4]` **Gerenciador de Redes**: Interface CLI/GUI para conexão a redes Wi-Fi e Ethernet.
* `[5]` **Painel de Controle**: Configurações de utilizadores, som, vídeo e hora.
* `[6]` **Gerenciador de Pacotes FYDEL**: Instalação e remoção de softwares.
* `[7]` **Ferramentas de Segurança**: Arsenal nativo de auditoria (Nmap, Wireshark, Metasploit, Hydra).
* `[8]` **Terminal de Comandos**: Abre um shell interativo Bash real clonado via pseudo-terminal (PTY) de baixo nível em Assembly.
* `[0]` **Sair da Sessão**: Encerra a sessão atual com segurança.

---

## 📦 3. Gerenciamento de Software (`fydel-pkg`)

O sistema conta com o utilitário personalizado `fydel-pkg` para envelopar o poder do ecossistema `apt` de forma visual. Para usá-lo, selecione a opção `6` no menu principal ou execute `fydel-pkg` no terminal como root.

### Comandos Rápidos dentro do Terminal Bash:
Se preferir utilizar a linha de comandos pura do terminal (Opção 8), você pode gerenciar o sistema usando as seguintes sintaxes:
```bash
# Atualizar as listas de repositórios oficiais
sudo fydel-pkg

# Instalar um novo software de segurança ou utilitário
sudo apt install nome_do_pacote

# Executar uma varredura de rede com o arsenal nativo
nmap -sV endereço_ip
