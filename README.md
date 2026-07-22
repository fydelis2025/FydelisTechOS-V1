# 🛡️ FydelisTechOS V1.0

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Debian](https://img.shields.io/badge/Debian-Bookworm-A81D13?logo=debian)](https://www.debian.org/)
[![XFCE](https://img.shields.io/badge/Desktop-XFCE-0066CC?logo=xfce)](https://www.xfce.org/)
[![Tools](https://img.shields.io/badge/Tools-161%2B-FF6B6B)](./config/package-lists/fydelistechos.list.chroot)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)](https://github.com/fydelistech/fydelistechos)

> **Cyber Warfare Interface & Custom Linux Distribution**

O **FydelisTechOS** é um sistema operacional GNU/Linux customizado e focado em **Cibersegurança, Ethical Hacking, Análise de Redes e Inteligência Artificial**, desenvolvido de forma independente para servir como ambiente operacional autossuficiente e laboratório prático de estudos.

---

## 🚀 Arquitetura e Principais Recursos

O ecossistema do FydelisTechOS integra ferramentas nativas de ponta para operadores de segurança e entusiastas de tecnologia:

*   🎓 **FydelisLab (Cyber Lab Interativo):** Um laboratório de progressão baseado em terminal integrado diretamente ao sistema. O usuário avança de nível (Básico, Intermediário, Avançado), acumula XP, resolve desafios reais de linha de comando, gera certificados em imagem customizados e compartilha suas conquistas diretamente nas redes sociais.
*   🤖 **Fydelis-AI:** Assistente de inteligência artificial integrada ao sistema para suporte técnico, análise de comandos, automação e consultas offline utilizando modelos avançados (como Llama e Gemma via Ollama).
*   🛠️ **Arsenal de Pentest Nativo:** Conjunto completo de ferramentas de segurança pré-instaladas e estruturadas para auditoria, varredura, análise de vulnerabilidades e testes de intrusão.
*   🎛️ **Painel de Controle e Utilitários:** Ferramentas gráficas customizadas em PyQt5 (Gerenciador de Pacotes Fydelis, Painel de Controle e Terminal Híbrido) com identidade visual Cyberpunk/Glassmorphic (*CyberHack*).

---

## 📂 Estrutura do Repositório

```text
FydelisTechOS-V1/
├── build_local.sh           # Script de compilação nativa da ISO (Live-Build)
├── sistema/
│   ├── FydelisLab/          # Ecossistema do laboratório de cibersegurança
│   │   ├── FyderlisLab.py   # Script principal do laboratório (Python + SQLite)
│   │   ├── bancos/          # Banco de dados local para progresso do operador
│   │   └── certificados/    # Gerador de certificados PNG automatizados
│   ├── FydelisControl.py    # Painel de controle gráfico do sistema
│   ├── FydelisSynaptic.py   # Gerenciador de pacotes customizado
│   └── fydel_ai.py          # Interface da Fydelis-AI
├── ferramentas/
│   └── fydelis-ai/          # Módulos de IA e scripts de suporte
└── src/                     # Assets de instalação, temas GRUB e Plymouth
