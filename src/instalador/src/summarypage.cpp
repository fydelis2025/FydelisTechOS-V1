#include "summarypage.h"

SummaryPage::SummaryPage(QWidget *parent)
    : QWidget(parent)
{
    setupUI();
}

void SummaryPage::setupUI() {
    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setAlignment(Qt::AlignCenter);
    layout->setContentsMargins(40, 40, 40, 40);
    layout->setSpacing(20);

    // Ícone grande
    m_iconLabel = new QLabel;
    m_iconLabel->setAlignment(Qt::AlignCenter);
    m_iconLabel->setStyleSheet("font-size: 72px;");
    layout->addWidget(m_iconLabel);

    // Título
    m_titleLabel = new QLabel;
    m_titleLabel->setAlignment(Qt::AlignCenter);
    m_titleLabel->setStyleSheet("font-size: 28px; font-weight: bold;");
    m_titleLabel->setWordWrap(true);
    layout->addWidget(m_titleLabel);

    // Resumo detalhado
    m_summaryText = new QTextEdit;
    m_summaryText->setReadOnly(true);
    m_summaryText->setMaximumHeight(300);
    m_summaryText->setStyleSheet(
        "QTextEdit {"
        "  background-color: #0a0a1a;"
        "  color: #e0e0e0;"
        "  border: 1px solid #16213e;"
        "  border-radius: 8px;"
        "  font-size: 13px;"
        "  padding: 15px;"
        "}"
    );
    layout->addWidget(m_summaryText);

    layout->addStretch();
}

void SummaryPage::setResult(bool success, const QString &summary) {
    if (success) {
        m_iconLabel->setText("✅");
        m_titleLabel->setText("Instalação Concluída com Sucesso!");
        m_titleLabel->setStyleSheet("font-size: 28px; font-weight: bold; color: #00c853;");
    } else {
        m_iconLabel->setText("❌");
        m_titleLabel->setText("Instalação Interrompida");
        m_titleLabel->setStyleSheet("font-size: 28px; font-weight: bold; color: #ff5252;");
    }

    // Criamos uma cópia local da string para permitir a alteração das quebras de linha
    QString modSummary = summary;
    m_summaryText->setHtml(modSummary.replace("\n", "<br>"));
}