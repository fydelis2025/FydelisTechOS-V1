#include "installwizard.h"
#include "assistantintro.h"
#include <QApplication>
#include <QStyleFactory>
#include <QMessageBox>
#include <QPalette>
#include <QFont>
#include <QDir>
#include <QStyle>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    app.setApplicationName("FydelisTechOS Installer");
    app.setApplicationVersion("1.0.0 Demo");
    app.setOrganizationName("FydelisTechOS");

    // ─── Tema Fusion escuro ────────────────────────────────────────
    app.setStyle(QStyleFactory::create("Fusion"));

    QPalette darkPalette;
    darkPalette.setColor(QPalette::Window, QColor(26, 26, 46));
    darkPalette.setColor(QPalette::WindowText, QColor(224, 224, 224));
    darkPalette.setColor(QPalette::Base, QColor(10, 10, 26));
    darkPalette.setColor(QPalette::AlternateBase, QColor(18, 18, 42));
    darkPalette.setColor(QPalette::ToolTipBase, QColor(15, 52, 96));
    darkPalette.setColor(QPalette::ToolTipText, QColor(224, 224, 224));
    darkPalette.setColor(QPalette::Text, QColor(224, 224, 224));
    darkPalette.setColor(QPalette::Button, QColor(15, 52, 96));
    darkPalette.setColor(QPalette::ButtonText, QColor(224, 224, 224));
    darkPalette.setColor(QPalette::BrightText, QColor(255, 82, 82));
    darkPalette.setColor(QPalette::Link, QColor(0, 212, 255));
    darkPalette.setColor(QPalette::Highlight, QColor(0, 200, 83));
    darkPalette.setColor(QPalette::HighlightedText, QColor(255, 255, 255));
    app.setPalette(darkPalette);

    // ─── Fonte global ──────────────────────────────────────────────
    QFont defaultFont = app.font();
#ifdef Q_OS_WIN
    defaultFont.setFamily("Segoe UI, Consolas, Courier New");
    defaultFont.setPointSize(10);
#else
    defaultFont.setFamily("DejaVu Sans, Ubuntu, Noto Sans, sans-serif");
    defaultFont.setPointSize(10);
#endif
    app.setFont(defaultFont);

    // ─── Aviso para Windows ────────────────────────────────────────
#ifdef Q_OS_WIN
    QMessageBox::information(nullptr, "🔧 Modo Demonstração",
        "<h2 style='color:#00d4ff;'>FydelisTechOS Installer — Windows Demo</h2>"
        "<p style='color:#e0e0e0;'>"
        "Você está executando no <b>Windows</b>.<br><br>"
        "🖥️ A <b>interface gráfica completa</b> funciona normalmente:<br>"
        "   • Wizard de 6 etapas<br>"
        "   • Gerenciador de partição visual<br>"
        "   • Slideshow com imagens<br>"
        "   • Seleção de ferramentas<br>"
        "   • Barra de progresso e logs<br><br>"
        "⚠️ A instalação real (apt-get, parted) é apenas simulada.<br>"
        "   Para instalação real, execute no Linux/Kali/Ubuntu.<br><br>"
        "🎯 Use este modo para <b>testar e validar a interface</b>."
        "</p>");
#endif

    // ─── Instancia o Assistente de Boas-Vindas ─────────────────────
    AssistantIntro assistantWindow;
    assistantWindow.setWindowTitle("FydelisTechOS — Assistente IA");
    assistantWindow.resize(600, 400);

    // ─── Instancia o Wizard Principal (mas deixa oculto inicialmente) ──
    InstallWizard wizard;
    wizard.setWindowTitle("FydelisTechOS Lite Installer v1.0 Demo");
    wizard.resize(1024, 700);

    // Quando o usuário clicar em "Iniciar" na assistente, fecha ela e exibe o Wizard
    QObject::connect(&assistantWindow, &AssistantIntro::assistantFinished, [&]() {
        assistantWindow.close();
        wizard.show();
    });

    // Exibe primeiro a assistente IA
    assistantWindow.show();

    return app.exec();
}