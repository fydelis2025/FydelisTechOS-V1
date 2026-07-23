# 🛡️ FydelisTechOS V1.0

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Debian](https://img.shields.io/badge/Debian-Bookworm-A81D13?logo=debian)](https://www.debian.org/)
[![XFCE](https://img.shields.io/badge/Desktop-XFCE-0066CC?logo=xfce)](https://www.xfce.org/)
[![Tools](https://img.shields.io/badge/Tools-161%2B-FF6B6B)](./config/package-lists/fydelistechos.list.chroot)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)](https://github.com/fydelistech/fydelistechos)

> **Cyber Warfare Interface & Custom Linux Distribution**

O **FydelisTechOS** é um sistema operacional GNU/Linux customizado e focado em **Cibersegurança, Ethical Hacking, Análise de Redes e Inteligência Artificial**, desenvolvido de forma independente para servir como ambiente operacional autossuficiente e laboratório prático de estudos.

---

## 📸 Interface do Sistema

<p align="center">
  <img src="https://github.com/fydelis2025/FydelisTechOS-V1/blob/main/background.png" alt="FydelisTechOS Dashboard" width="100%">
</p>

## 🚀 Arquitetura e Principais Recursos

O ecossistema do FydelisTechOS integra ferramentas nativas de ponta para operadores de segurança e entusiastas de tecnologia:

*   🎓 **FydelisLab (Cyber Lab Interativo):** Um laboratório de progressão baseado em terminal integrado diretamente ao sistema. O usuário avança de nível (Básico, Intermediário, Avançado), acumula XP, resolve desafios reais de linha de comando, gera certificados em imagem customizados e compartilha suas conquistas diretamente nas redes sociais.
  
*   🤖 **Fydelis-AI:** Assistente de inteligência artificial integrada ao sistema para suporte técnico, análise de comandos, automação e consultas offline utilizando modelos avançados (como Llama e Gemma via Ollama).
  
*   🛠️ **Arsenal de Pentest Nativo:** Conjunto completo de ferramentas de segurança pré-instaladas e estruturadas para auditoria, varredura, análise de vulnerabilidades e testes de intrusão.
  
*   🎛️ **Painel de Controle e Utilitários:** Ferramentas gráficas customizadas em PyQt5 (Gerenciador de Pacotes Fydelis, Painel de Controle e Terminal Híbrido) com identidade visual Cyberpunk/Glassmorphic (*CyberHack*).
  

---

## 🎓 Sobre o FydelisLab (Laboratório de Treinamento)

O FydelisLab foi desenvolvido para transformar o aprendizado de comandos Linux e metodologias de pentest em uma experiência gamificada (Hands-on).

Progresso Persistente: O sistema utiliza SQLite para salvar automaticamente o nível, os exercícios concluídos e o XP do operador, mesmo se a aplicação for fechada.

Certificação Automatizada: Ao concluir um ciclo completo, o sistema gera dinamicamente uma imagem de certificado oficial e facilita a exportação/compartilhamento da conquista.

## 📜 Licença e Propriedade Intelectual

Este projeto é distribuído sob os termos da licença especificada no repositório. Desenvolvido por Adiel Santos Fontes (FydelisTech).

### Por que essa documentação se encaixa perfeitamente no seu projeto?

* **Valoriza o seu trabalho técnico:** Explica de forma clara que o projeto não é apenas uma distro comum, mas um ecossistema educacional completo.
* 
* **Organização Profissional:** Facilita para qualquer desenvolvedor ou recrutador que acesse o seu GitHub entender rapidamente para que serve cada pasta (`sistema/`, `ferramentas/`, `build_local.sh`).
  

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



