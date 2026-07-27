#include "toolselectionpage.h"
#include <QHeaderView>

ToolSelectionPage::ToolSelectionPage(QWidget *parent)
    : QWidget(parent)
{
    setupUI();
}

void ToolSelectionPage::setupUI() {
    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setContentsMargins(30, 20, 30, 20);
    layout->setSpacing(15);

    QLabel *title = new QLabel("<h1 style='color:#fff;'>🧰 Selecionar Ferramentas</h1>");
    layout->addWidget(title);

    QLabel *subtitle = new QLabel(
        "<p style='color:#aaa; font-size:13px;'>"
        "Escolha as ferramentas de segurança ofensiva que deseja instalar. "
        "Organizadas por categoria para facilitar a seleção.</p>"
    );
    subtitle->setWordWrap(true);
    layout->addWidget(subtitle);

    m_selectAllCheck = new QCheckBox("✅ Selecionar todas as ferramentas");
    m_selectAllCheck->setStyleSheet(
        "QCheckBox { color: #00d4ff; font-size: 14px; font-weight: bold; padding: 8px; }"
        "QCheckBox::indicator { width: 20px; height: 20px; border: 2px solid #00d4ff; "
        "border-radius: 4px; background-color: #0a0a1a; }"
        "QCheckBox::indicator:checked { background-color: #00c853; border-color: #00c853; }"
    );
    connect(m_selectAllCheck, &QCheckBox::toggled, this, &ToolSelectionPage::onSelectAllToggled);
    layout->addWidget(m_selectAllCheck);

    // Árvore
    m_toolTree = new QTreeWidget;
    m_toolTree->setHeaderLabels({"Ferramenta", "Pacote", "Descrição"});
    m_toolTree->setColumnWidth(0, 200);
    m_toolTree->setColumnWidth(1, 200);
    m_toolTree->setIndentation(20);
    m_toolTree->setAnimated(true);
    m_toolTree->header()->setStretchLastSection(true);
    m_toolTree->setStyleSheet(
        "QTreeWidget { background-color: #12122a; color: #e0e0e0; border: 1px solid #16213e; border-radius: 4px; }"
        "QTreeWidget::item { padding: 4px; }"
        "QTreeWidget::item:hover { background-color: #16213e; }"
        "QTreeWidget::item:selected { background-color: #0f3460; }"
        "QHeaderView::section { background-color: #0f3460; color: #00d4ff; padding: 6px; border: 1px solid #16213e; font-weight: bold; }"
    );
    populateTools();
    layout->addWidget(m_toolTree, 1);

    // Contador
    m_countLabel = new QLabel("🔄 Nenhuma ferramenta selecionada");
    m_countLabel->setStyleSheet("color: #ffd700; font-size: 13px; padding: 4px;");
    m_countLabel->setAlignment(Qt::AlignRight);
    layout->addWidget(m_countLabel);

    connect(m_toolTree, &QTreeWidget::itemChanged, this, &ToolSelectionPage::updateCount);
}

void ToolSelectionPage::populateTools() {
    auto cats = ToolsDatabase::getAllByCategory();
    for (auto it = cats.begin(); it != cats.end(); ++it) {
        QTreeWidgetItem *catItem = new QTreeWidgetItem({it.key(), "", ""});
        catItem->setFlags(catItem->flags() & ~Qt::ItemIsUserCheckable);
        catItem->setForeground(0, QColor("#00d4ff"));
        QFont f = catItem->font(0);
        f.setBold(true);
        catItem->setFont(0, f);

        for (const auto &tool : it.value()) {
            QTreeWidgetItem *toolItem = new QTreeWidgetItem({
                tool.displayName, tool.packageName, tool.description
            });
            toolItem->setFlags(toolItem->flags() | Qt::ItemIsUserCheckable);
            toolItem->setCheckState(0, Qt::Unchecked);
            toolItem->setForeground(1, QColor("#aaa"));
            toolItem->setForeground(2, QColor("#888"));
            catItem->addChild(toolItem);
        }

        m_toolTree->addTopLevelItem(catItem);
    }
}

void ToolSelectionPage::onSelectAllToggled(bool checked) {
    Qt::CheckState state = checked ? Qt::Checked : Qt::Unchecked;
    for (int i = 0; i < m_toolTree->topLevelItemCount(); ++i) {
        QTreeWidgetItem *cat = m_toolTree->topLevelItem(i);
        for (int j = 0; j < cat->childCount(); ++j) {
            cat->child(j)->setCheckState(0, state);
        }
    }
}

void ToolSelectionPage::updateCount() {
    int count = getSelectedPackages().size();
    if (count > 0) {
        m_countLabel->setText(QString("✅ %1 ferramenta(s) selecionada(s)").arg(count));
    } else {
        m_countLabel->setText("🔄 Nenhuma ferramenta selecionada");
    }
}

QStringList ToolSelectionPage::getSelectedPackages() const {
    QStringList pkgs;
    for (int i = 0; i < m_toolTree->topLevelItemCount(); ++i) {
        QTreeWidgetItem *cat = m_toolTree->topLevelItem(i);
        for (int j = 0; j < cat->childCount(); ++j) {
            if (cat->child(j)->checkState(0) == Qt::Checked) {
                pkgs << cat->child(j)->text(1);
            }
        }
    }
    return pkgs;
}

int ToolSelectionPage::totalSelected() const {
    return getSelectedPackages().size();
}