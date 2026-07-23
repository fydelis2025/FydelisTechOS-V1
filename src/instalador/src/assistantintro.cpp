#include "assistantintro.h"
#include <QGraphicsDropShadowEffect>

AssistantIntro::AssistantIntro(QWidget *parent)
    : QWidget(parent)
    , m_index(0)
{
    // Texto imersivo da assistente do FydelisTechOS
    m_fullText = "Olá, operador! Sou a IA assistente do FydelisTechOS.\n"
                 "Estou aqui para guiar você na configuração e implantação\n"
                 "do seu ambiente de segurança ofensiva.\n\n"
                 "Tudo pronto para iniciarmos a missão?";

    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setAlignment(Qt::AlignCenter);
    layout->setSpacing(20);

    // Ícone / Avatar da IA (estilizado)
    m_avatarLabel = new QLabel(this);
    m_avatarLabel->setAlignment(Qt::AlignCenter);
    m_avatarLabel->setText("🛡️ [ Fydelis AI ]");
    m_avatarLabel->setStyleSheet("color: #22D3EE; font-size: 20pt; font-weight: bold; font-family: 'Monospace';");
    
    // Caixa de diálogo com efeito Glassmorphic / Cyberpunk
    m_textLabel = new QLabel(this);
    m_textLabel->setAlignment(Qt::AlignLeft | Qt::AlignVCenter);
    m_textLabel->setMinimumSize(450, 140);
    m_textLabel->setStyleSheet(
        "color: #F8FAFC; "
        "font-family: 'Monospace'; "
        "font-size: 13pt; "
        "background: rgba(16, 22, 47, 0.85); "
        "border: 1px solid rgba(34, 211, 238, 0.4); "
        "border-radius: 15px; "
        "padding: 20px;"
    );

    // Botão de Avançar (inicialmente oculto ou desativado até terminar de digitar)
    m_nextButton = new QPushButton("Iniciar Configuração →", this);
    m_nextButton->setCursor(Qt::PointingHandCursor);
    m_nextButton->setEnabled(false);
    m_nextButton->setStyleSheet(
        "QPushButton {"
        "  background-color: #6A11CB;"
        "  color: white;"
        "  font-size: 12pt;"
        "  font-weight: bold;"
        "  padding: 12px 24px;"
        "  border-radius: 8px;"
        "  border: 1px solid #22D3EE;"
        "}"
        "QPushButton:enabled:hover {"
        "  background-color: #22D3EE;"
        "  color: #0F172A;"
        "}"
        "QPushButton:disabled {"
        "  background-color: #1E293B;"
        "  color: #64748B;"
        "  border: 1px solid #334155;"
        "}"
    );

    connect(m_nextButton, &QPushButton::clicked, this, &AssistantIntro::assistantFinished);

    layout->addWidget(m_avatarLabel);
    layout->addWidget(m_textLabel);
    layout->addWidget(m_nextButton, 0, Qt::AlignCenter);

    // Configuração do Timer para o efeito de digitação (*typewriter*)
    m_timer = new QTimer(this);
    connect(m_timer, &QTimer::timeout, this, &AssistantIntro::typeText);
    m_timer->start(30); // Velocidade de digitação em milissegundos
}

void AssistantIntro::typeText() {
    if (m_index <= m_fullText.size()) {
        m_textLabel->setText(m_fullText.left(m_index));
        m_index++;
    } else {
        m_timer->stop();
        m_nextButton->setEnabled(true); // Libera o botão após terminar a fala
    }
}