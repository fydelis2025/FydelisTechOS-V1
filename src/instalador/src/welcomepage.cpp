#include "welcomepage.h"

WelcomePage::WelcomePage(QWidget *parent)
    : QWidget(parent)
{
    setupUI();
}

void WelcomePage::setupUI() {
    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setAlignment(Qt::AlignCenter);
    layout->setContentsMargins(50, 40, 50, 40);
    layout->setSpacing(20);

    // Banner ASCII
    QLabel *banner = new QLabel(
        "  ______ _           _ _ _           _____ _           _   ___  ____  \n"
        " |  ____| |         | | | |         |_   _| |         | | / _ \\/ ___| \n"
        " | |__  | |_   _  __| | | | ___ _ __  | | | |__   ___ | |/ / _\\` \\___ \\ \n"
        " |  __| | | | | |/ _` | | |/ _ \\ '__| | | | '_ \\ / _ \\| | | (_| |___) |\n"
        " | |    | | |_| | (_| | | |  __/ |    _| |_| | | | (_) | | \\__,_|____/ \n"
        " |_|    |_|\\__, |\\__,_|_|_|\\___|_|   |_____|_|_| \\___/|_|      |_|   \n"
        "            __/ |                                                      \n"
        "           |___/                                                       "
    );
    banner->setAlignment(Qt::AlignCenter);
    banner->setStyleSheet("color: #00d4ff; font-size: 11px; font-family: monospace;");
    layout->addWidget(banner);

    // Título
    QLabel *title = new QLabel(
        "<h1 style='color:#fff; text-align:center;'>FydelisTechOS Lite</h1>"
        "<h2 style='color:#00d4ff; text-align:center;'>Instalador — Ambiente de Segurança Ofensiva</h2>"
    );
    title->setAlignment(Qt::AlignCenter);
    layout->addWidget(title);

    // Descrição
    QLabel *desc = new QLabel(
        "<p style='color:#aaa; font-size:14px; text-align:center;'>"
        "Este instalador irá transformar seu sistema em uma estação completa de pentest.<br>"
        "Baseado no material educacional <b>FydelisTechOS</b> — segurança ofensiva do zero ao avançado."
        "</p>"
    );
    desc->setAlignment(Qt::AlignCenter);
    desc->setWordWrap(true);
    layout->addWidget(desc);

    // Seletor de idioma
    QLabel *langLabel = new QLabel("<b style='color:#e0e0e0;'>🌐 Idioma / Language:</b>");
    layout->addWidget(langLabel);

    m_langCombo = new QComboBox;
    m_langCombo->addItem("🇧🇷  Português (Brasil)", "pt_BR");
    m_langCombo->addItem("🇺🇸  English (US)", "en_US");
    m_langCombo->addItem("🇪🇸  Español", "es_ES");
    m_langCombo->setStyleSheet(
        "QComboBox { background-color: #0f3460; color: #e0e0e0; border: 1px solid #16213e; "
        "border-radius: 4px; padding: 8px; font-size: 13px; }"
        "QComboBox::drop-down { border: none; }"
        "QComboBox QAbstractItemView { background-color: #0f3460; color: #e0e0e0; selection-background-color: #16213e; }"
    );
    m_langCombo->setFixedWidth(300);
    layout->addWidget(m_langCombo);

    layout->addStretch();
}

QString WelcomePage::selectedLanguage() const {
    return m_langCombo->currentData().toString();
}