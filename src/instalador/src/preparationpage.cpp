#include "preparationpage.h"

PreparationPage::PreparationPage(QWidget *parent)
    : QWidget(parent)
{
    setupUI();
}

void PreparationPage::setupUI() {
    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setContentsMargins(40, 30, 40, 30);
    layout->setSpacing(20);

    QLabel *title = new QLabel("<h1 style='color:#fff;'>🔧 Preparação</h1>");
    layout->addWidget(title);

    QLabel *subtitle = new QLabel(
        "<p style='color:#aaa; font-size:13px;'>"
        "Configure as opções básicas antes da instalação.</p>"
    );
    layout->addWidget(subtitle);

    // Layout do teclado
    QGroupBox *kbdGroup = new QGroupBox("⌨️ Layout do Teclado");
    kbdGroup->setStyleSheet(
        "QGroupBox { color: #00d4ff; font-weight: bold; border: 1px solid #16213e; "
        "border-radius: 6px; margin-top: 15px; padding: 15px; }"
    );
    QVBoxLayout *kbdLayout = new QVBoxLayout(kbdGroup);

    m_keyboardCombo = new QComboBox;
    m_keyboardCombo->addItem("Português (Brasil) — ABNT2", "br");
    m_keyboardCombo->addItem("English (US)", "us");
    m_keyboardCombo->addItem("Español (Latinoamérica)", "latam");
    m_keyboardCombo->addItem("Français (AZERTY)", "fr");
    m_keyboardCombo->addItem("Deutsch (QWERTZ)", "de");
    m_keyboardCombo->setStyleSheet(
        "QComboBox { background-color: #0f3460; color: #e0e0e0; border: 1px solid #16213e; "
        "border-radius: 4px; padding: 8px; font-size: 13px; }"
        "QComboBox::drop-down { border: none; }"
        "QComboBox QAbstractItemView { background-color: #0f3460; color: #e0e0e0; }"
    );
    kbdLayout->addWidget(m_keyboardCombo);
    layout->addWidget(kbdGroup);

    // Opções
    QGroupBox *optGroup = new QGroupBox("⚙️ Opções Adicionais");
    optGroup->setStyleSheet(
        "QGroupBox { color: #00d4ff; font-weight: bold; border: 1px solid #16213e; "
        "border-radius: 6px; margin-top: 15px; padding: 15px; }"
        "QCheckBox { color: #e0e0e0; font-size: 13px; padding: 6px; }"
        "QCheckBox::indicator { width: 18px; height: 18px; border: 2px solid #00d4ff; "
        "border-radius: 3px; background-color: #0a0a1a; }"
        "QCheckBox::indicator:checked { background-color: #00c853; border-color: #00c853; }"
    );
    QVBoxLayout *optLayout = new QVBoxLayout(optGroup);

    m_updateCheck = new QCheckBox("📥 Instalar atualizações mais recentes durante a instalação");
    m_updateCheck->setChecked(true);
    optLayout->addWidget(m_updateCheck);

    m_thirdPartyCheck = new QCheckBox("📦 Instalar drivers proprietários e codecs");
    m_thirdPartyCheck->setChecked(false);
    optLayout->addWidget(m_thirdPartyCheck);

    layout->addWidget(optGroup);

    // Informação
    QLabel *info = new QLabel(
        "<p style='color:#888; font-size:11px;'>"
        "💡 As atualizações podem tornar a instalação mais lenta, "
        "mas garantem as ferramentas nas versões mais recentes.</p>"
    );
    info->setWordWrap(true);
    layout->addWidget(info);

    layout->addStretch();
}

bool PreparationPage::installUpdates() const { return m_updateCheck->isChecked(); }
bool PreparationPage::installThirdParty() const { return m_thirdPartyCheck->isChecked(); }
QString PreparationPage::keyboardLayout() const { return m_keyboardCombo->currentData().toString(); }