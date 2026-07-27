#include "partitionpage.h"
#include <QMessageBox>
#include <QHeaderView>
#include <QFormLayout>

PartitionPage::PartitionPage(QWidget *parent)
    : QWidget(parent)
    , m_partMgr(new PartitionManager(this))
    , m_selectedDiskIndex(-1)
{
    setupUI();
    refreshDisks();
}

void PartitionPage::setupUI() {
    QVBoxLayout *mainLayout = new QVBoxLayout(this);
    mainLayout->setContentsMargins(30, 20, 30, 20);
    mainLayout->setSpacing(15);

    // ─── Título ────────────────────────────────────────────────────
    QLabel *title = new QLabel("<h1 style='color:#fff;'>📀 Gerenciamento de Partição</h1>");
    mainLayout->addWidget(title);

    QLabel *subtitle = new QLabel(
        "<p style='color:#aaa; font-size:13px;'>"
        "Escolha como deseja instalar o FydelisTechOS Lite. "
        "Você pode instalá-lo junto com outros sistemas, "
        "apagar o disco inteiro ou particionar manualmente.</p>");
    mainLayout->addWidget(subtitle);

    // ─── Tipo de instalação ────────────────────────────────────────
    QGroupBox *typeGroup = new QGroupBox("Tipo de instalação");
    typeGroup->setStyleSheet(
        "QGroupBox { color: #00d4ff; font-weight: bold; border: 1px solid #16213e; border-radius: 6px; margin-top: 15px; padding: 15px; }"
        "QGroupBox::title { color: #00d4ff; }"
        "QRadioButton { color: #e0e0e0; font-size: 13px; padding: 6px; }"
        "QRadioButton::indicator { width: 18px; height: 18px; border: 2px solid #00d4ff; border-radius: 10px; }"
        "QRadioButton::indicator:checked { background-color: #00c853; border-color: #00c853; }"
    );

    QVBoxLayout *typeLayout = new QVBoxLayout(typeGroup);
    m_typeGroup = new QButtonGroup(this);

    m_radioDualBoot = new QRadioButton("🔀 Instalar junto (Dual Boot) — mantém sistemas existentes");
    m_radioDualBoot->setChecked(true);
    m_typeGroup->addButton(m_radioDualBoot, 0);

    m_radioEraseDisk = new QRadioButton("💾 Apagar disco e instalar FydelisTechOS");
    m_typeGroup->addButton(m_radioEraseDisk, 1);

    m_radioManual = new QRadioButton("⚙️ Particionamento manual (avançado)");
    m_typeGroup->addButton(m_radioManual, 2);

    typeLayout->addWidget(m_radioDualBoot);
    typeLayout->addWidget(m_radioEraseDisk);
    typeLayout->addWidget(m_radioManual);

    mainLayout->addWidget(typeGroup);
    
    // Conexão do grupo de botões
    connect(m_typeGroup, &QButtonGroup::idClicked,
        this, &PartitionPage::onInstallTypeChanged);

    // ─── Stack de opções ───────────────────────────────────────────
    m_typeStack = new QStackedWidget;

    // --- Página 0: Dual Boot ---
    QWidget *dualBootPage = new QWidget;
    QVBoxLayout *dbLayout = new QVBoxLayout(dualBootPage);

    m_dualBootDiskCombo = new QComboBox;
    dbLayout->addWidget(new QLabel("Selecione o disco para dual boot:"));
    dbLayout->addWidget(m_dualBootDiskCombo);

    m_dualBootInfoLabel = new QLabel("Detectando sistemas operacionais...");
    m_dualBootInfoLabel->setStyleSheet("color: #ffd700; padding: 8px;");
    m_dualBootInfoLabel->setWordWrap(true);
    dbLayout->addWidget(m_dualBootInfoLabel);

    // Slider de tamanho
    QLabel *sliderTitle = new QLabel("🔧 Espaço para o novo sistema:");
    sliderTitle->setStyleSheet("color: #e0e0e0; font-weight: bold; margin-top: 10px;");
    dbLayout->addWidget(sliderTitle);

    QHBoxLayout *sliderLayout = new QHBoxLayout;
    m_dualBootWindowsSizeLabel = new QLabel("Windows: --");
    m_dualBootWindowsSizeLabel->setStyleSheet("color: #2979ff;");
    m_dualBootSlider = new QSlider(Qt::Horizontal);
    m_dualBootSlider->setRange(8, 500); // 8 GB a 500 GB
    m_dualBootSlider->setValue(50);
    m_dualBootSlider->setStyleSheet(
        "QSlider::groove:horizontal { height: 8px; background: #16213e; border-radius: 4px; }"
        "QSlider::handle:horizontal { background: #00d4ff; width: 20px; height: 20px; margin: -6px 0; border-radius: 10px; }"
        "QSlider::sub-page:horizontal { background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #00d4ff, stop:1 #00c853); border-radius: 4px; }"
    );
    m_dualBootNewSizeLabel = new QLabel("FydelisTechOS: 50 GB");
    m_dualBootNewSizeLabel->setStyleSheet("color: #00c853; font-weight: bold;");

    sliderLayout->addWidget(m_dualBootWindowsSizeLabel);
    sliderLayout->addWidget(m_dualBootSlider, 1);
    sliderLayout->addWidget(m_dualBootNewSizeLabel);
    dbLayout->addLayout(sliderLayout);

    m_dualBootSizeLabel = new QLabel("Espaço livre disponível: --");
    m_dualBootSizeLabel->setStyleSheet("color: #888;");
    dbLayout->addWidget(m_dualBootSizeLabel);

    connect(m_dualBootSlider, &QSlider::valueChanged, this, &PartitionPage::onDualBootSliderChanged);
    connect(m_dualBootDiskCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, [this](int index) { onDiskSelected(index); });

    m_typeStack->addWidget(dualBootPage);

    // --- Página 1: Apagar disco ---
    QWidget *erasePage = new QWidget;
    QVBoxLayout *erLayout = new QVBoxLayout(erasePage);

    m_eraseDiskCombo = new QComboBox;
    erLayout->addWidget(new QLabel("Selecione o disco que será apagado:"));
    erLayout->addWidget(m_eraseDiskCombo);

    m_eraseInfoLabel = new QLabel(
        "<span style='color:#ff5252;'>⚠️ Atenção: todos os dados do disco selecionado serão perdidos!</span>"
    );
    m_eraseInfoLabel->setStyleSheet("padding: 8px;");
    m_eraseInfoLabel->setWordWrap(true);
    erLayout->addWidget(m_eraseInfoLabel);

    connect(m_eraseDiskCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, [this](int index) { onDiskSelected(index); });

    m_typeStack->addWidget(erasePage);

    // --- Página 2: Manual ---
    QWidget *manualPage = new QWidget;
    QVBoxLayout *manLayout = new QVBoxLayout(manualPage);

    m_manualDiskCombo = new QComboBox;
    manLayout->addWidget(new QLabel("Disco:"));
    manLayout->addWidget(m_manualDiskCombo);

    m_partitionTable = new QTableWidget;
    m_partitionTable->setColumnCount(6);
    m_partitionTable->setHorizontalHeaderLabels({"Partição", "Tamanho", "Sistema", "Rótulo", "Ponto Montagem", "SO Detectado"});
    m_partitionTable->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_partitionTable->setSelectionMode(QAbstractItemView::SingleSelection);
    m_partitionTable->setStyleSheet(
        "QTableWidget { background-color: #12122a; color: #e0e0e0; border: 1px solid #16213e; gridline-color: #16213e; }"
        "QTableWidget::item { padding: 6px; }"
        "QTableWidget::item:selected { background-color: #0f3460; }"
        "QHeaderView::section { background-color: #0f3460; color: #00d4ff; padding: 6px; border: 1px solid #16213e; font-weight: bold; }"
    );
    m_partitionTable->horizontalHeader()->setStretchLastSection(true);
    m_partitionTable->setAlternatingRowColors(true);
    manLayout->addWidget(m_partitionTable);

    QHBoxLayout *manualBtnLayout = new QHBoxLayout;
    m_btnNewPartition = new QPushButton("➕ Nova");
    m_btnDeletePartition = new QPushButton("🗑️ Excluir");
    m_btnFormatPartition = new QPushButton("📝 Format");
    m_btnResizePartition = new QPushButton("↔️ Redimensionar");

    for (auto *btn : {m_btnNewPartition, m_btnDeletePartition, m_btnFormatPartition, m_btnResizePartition}) {
        btn->setStyleSheet(
            "QPushButton { background-color: #0f3460; color: #e0e0e0; border: 1px solid #16213e; border-radius: 4px; padding: 6px 14px; }"
            "QPushButton:hover { background-color: #16213e; border-color: #00d4ff; }"
        );
        btn->setCursor(Qt::PointingHandCursor);
        manualBtnLayout->addWidget(btn);
    }
    manLayout->addLayout(manualBtnLayout);

    connect(m_manualDiskCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, [this](int index) { onDiskSelected(index); populatePartitionTable(); });
    connect(m_partitionTable, &QTableWidget::cellClicked,
            this, [this](int row, int) {
                if (row >= 0 && row < m_disks[m_manualDiskCombo->currentIndex()].partitions.size())
                    showPartitionDetails(m_disks[m_manualDiskCombo->currentIndex()].partitions[row]);
            });

    m_typeStack->addWidget(manualPage);

    mainLayout->addWidget(m_typeStack);

    // ─── Visualização do disco ─────────────────────────────────────
    QGroupBox *vizGroup = new QGroupBox("Visualização do disco");
    vizGroup->setStyleSheet(
        "QGroupBox { color: #00d4ff; font-weight: bold; border: 1px solid #16213e; border-radius: 6px; margin-top: 15px; padding: 15px; }"
        "QGroupBox::title { color: #00d4ff; }"
    );
    QVBoxLayout *vizLayout = new QVBoxLayout(vizGroup);

    m_diskWidget = new DiskWidget;
    m_diskWidget->setMinimumHeight(120);
    vizLayout->addWidget(m_diskWidget);

    m_partitionDetailsLabel = new QLabel("Clique em uma partição para ver detalhes");
    m_partitionDetailsLabel->setStyleSheet("color: #888; font-size: 12px; padding: 6px; background-color: #0a0a1a; border-radius: 4px;");
    m_partitionDetailsLabel->setWordWrap(true);
    vizLayout->addWidget(m_partitionDetailsLabel);

    mainLayout->addWidget(vizGroup);
    connect(m_diskWidget, &DiskWidget::partitionClicked,
            this, &PartitionPage::onPartitionClicked);

    // ─── Botão refresh ─────────────────────────────────────────────
    QPushButton *refreshBtn = new QPushButton("🔄 Atualizar detecção de discos");
    refreshBtn->setStyleSheet(
        "QPushButton { background-color: #0f3460; color: #e0e0e0; border: 1px solid #16213e; border-radius: 4px; padding: 8px 16px; }"
        "QPushButton:hover { background-color: #16213e; }"
    );
    refreshBtn->setCursor(Qt::PointingHandCursor);
    connect(refreshBtn, &QPushButton::clicked, this, &PartitionPage::refreshClicked);
    mainLayout->addWidget(refreshBtn, 0, Qt::AlignLeft);

    // ─── Resumo ────────────────────────────────────────────────────
    QGroupBox *summaryGroup = new QGroupBox("Resumo da instalação");
    summaryGroup->setStyleSheet(
        "QGroupBox { color: #ffd700; font-weight: bold; border: 1px solid #16213e; border-radius: 6px; margin-top: 15px; padding: 15px; }"
        "QGroupBox::title { color: #ffd700; }"
    );
    QVBoxLayout *sumLayout = new QVBoxLayout(summaryGroup);
    m_summaryLabel = new QLabel("Nenhuma opção selecionada.");
    m_summaryLabel->setStyleSheet("color: #e0e0e0; font-size: 13px;");
    m_summaryLabel->setWordWrap(true);
    sumLayout->addWidget(m_summaryLabel);
    mainLayout->addWidget(summaryGroup);

    mainLayout->addStretch();
}

// ─── Atualização de dados ───────────────────────────────────────────────────

void PartitionPage::refreshDisks() {
    m_disks = m_partMgr->detectDisks();
    m_dualBootOptions = m_partMgr->detectDualBootOptions();

    populateDiskCombo();
    onInstallTypeChanged(m_typeGroup->checkedId());
    updateSummary();
}

void PartitionPage::populateDiskCombo() {
    auto populate = [this](QComboBox *combo) {
        combo->clear();
        for (const auto &d : m_disks) {
            combo->addItem(d.description(), d.device);
        }
    };

    populate(m_dualBootDiskCombo);
    populate(m_eraseDiskCombo);
    populate(m_manualDiskCombo);

    // Pré-seleciona disco com dual boot viável
    for (const auto &opt : m_dualBootOptions) {
        if (opt.viable) {
            int idx = m_dualBootDiskCombo->findData(opt.diskDevice);
            if (idx >= 0) {
                m_dualBootDiskCombo->setCurrentIndex(idx);
                break;
            }
        }
    }
}

void PartitionPage::populatePartitionTable() {
    m_partitionTable->setRowCount(0);
    int idx = m_manualDiskCombo->currentIndex();
    if (idx < 0 || idx >= m_disks.size()) return;

    const auto &disk = m_disks[idx];
    m_partitionTable->setRowCount(disk.partitions.size());

    for (int i = 0; i < disk.partitions.size(); ++i) {
        const auto &p = disk.partitions[i];
        m_partitionTable->setItem(i, 0, new QTableWidgetItem(p.device));
        m_partitionTable->setItem(i, 1, new QTableWidgetItem(p.sizeHuman()));
        m_partitionTable->setItem(i, 2, new QTableWidgetItem(p.fstype.toUpper()));
        m_partitionTable->setItem(i, 3, new QTableWidgetItem(p.label));
        m_partitionTable->setItem(i, 4, new QTableWidgetItem(p.mountpoint.isEmpty() ? "---" : p.mountpoint));
        m_partitionTable->setItem(i, 5, new QTableWidgetItem(p.osName.isEmpty() ? "---" : p.osName));
    }
}

void PartitionPage::updateDiskVisualization() {
    // Proteção contra índice inválido
    if (m_disks.isEmpty() || m_selectedDiskIndex < 0 || m_selectedDiskIndex >= m_disks.size()) {
        return;
    }

    auto disk = m_disks[m_selectedDiskIndex];

    if (isDualBootSelected()) {
        int val = m_dualBootSlider->value();
        qint64 newSizeGB = val * 1024LL * 1024 * 1024;
        m_diskWidget->setDualBootMode(true, newSizeGB);
    } else {
        m_diskWidget->setDualBootMode(false, 0);
    }

    m_diskWidget->setDisk(disk);
}

void PartitionPage::onInstallTypeChanged(int id) {
    m_typeStack->setCurrentIndex(id);
    m_actions.clear();

    switch (id) {
    case 0: // Dual Boot
        m_selectedDiskIndex = m_dualBootDiskCombo->currentIndex();
        {
            int idx = m_selectedDiskIndex;
            if (idx >= 0 && idx < m_dualBootOptions.size()) {
                const auto &opt = m_dualBootOptions[idx];
                m_dualBootSlider->setMaximum(static_cast<int>(opt.freeForNew / (1024*1024*1024)));
                m_dualBootSlider->setValue(static_cast<int>(opt.suggestedNewSize / (1024*1024*1024)));
                onDualBootSliderChanged(m_dualBootSlider->value());
            }
        }
        break;
    case 1: // Apagar disco
        m_selectedDiskIndex = m_eraseDiskCombo->currentIndex();
        break;
    case 2: // Manual
        m_selectedDiskIndex = m_manualDiskCombo->currentIndex();
        populatePartitionTable();
        break;
    }

    updateDiskVisualization();
    updateSummary();
}

void PartitionPage::onDiskSelected(int index) {
    if (index < 0) return;
    
    switch (m_typeGroup->checkedId()) {
    case 0: m_selectedDiskIndex = m_dualBootDiskCombo->currentIndex(); break;
    case 1: m_selectedDiskIndex = m_eraseDiskCombo->currentIndex(); break;
    case 2: m_selectedDiskIndex = m_manualDiskCombo->currentIndex(); break;
    }

    updateDiskVisualization();
    updateSummary();
}

void PartitionPage::onDualBootSliderChanged(int value) {
    qint64 gb = value;
    qint64 bytes = gb * 1024LL * 1024 * 1024;

    int idx = m_dualBootDiskCombo->currentIndex();
    if (idx >= 0 && idx < m_dualBootOptions.size()) {
        const auto &opt = m_dualBootOptions[idx];
        m_dualBootWindowsSizeLabel->setText(
            QString("Windows (~%1)").arg(PartitionManager::sizeHuman(opt.totalDiskSize - bytes)));
        // Atribuição unificada sem conflito de sobrescrita
        m_dualBootNewSizeLabel->setText(
            QString("FydelisTechOS: %1 GB").arg(gb));
        m_dualBootSizeLabel->setText(
            QString("Espaço livre / Máximo: %1")
                .arg(PartitionManager::sizeHuman(opt.freeForNew)));
    }

    updateDiskVisualization();
    updateSummary();
}

void PartitionPage::onPartitionClicked(const PartitionInfo &part) {
    showPartitionDetails(part);
}

void PartitionPage::showPartitionDetails(const PartitionInfo &part) {
    m_partitionDetailsLabel->setText(
        QString(
            "<b style='color:#00d4ff;'>%1</b><br>"
            "Tamanho: <b>%2</b> | Sistema: <b>%3</b> | Rótulo: %4<br>"
            "Montagem: %5 | UUID: <span style='color:#888;'>%6</span><br>"
            "%7"
        ).arg(part.device, part.sizeHuman(), part.fstype.toUpper(), part.label.isEmpty() ? "---" : part.label,
              part.mountpoint.isEmpty() ? "Não montado" : part.mountpoint,
              part.uuid.isEmpty() ? "N/A" : part.uuid,
              part.osName.isEmpty() ? "" : QString("<b style='color:#ffd700;'>SO Detectado: %1</b>").arg(part.osName))
    );
}

void PartitionPage::updateSummary() {
    QString summary;
    int id = m_typeGroup->checkedId();

    switch (id) {
    case 0: {
        int idx = m_dualBootDiskCombo->currentIndex();
        if (idx >= 0 && idx < m_disks.size()) {
            int gb = m_dualBootSlider->value();
            summary = QString(
                "🔀 <b>Dual Boot</b> — %1<br>"
                "📀 Instalando junto com sistemas existentes<br>"
                "💾 <b>%2 GB</b> alocados para FydelisTechOS<br>"
                "✅ Sistemas atuais serão preservados"
            ).arg(m_disks[idx].description()).arg(gb);
        }
        break;
    }
    case 1: {
        int idx = m_eraseDiskCombo->currentIndex();
        if (idx >= 0 && idx < m_disks.size()) {
            summary = QString(
                "💾 <b>Apagar disco</b> — %1<br>"
                "⚠️ <span style='color:#ff5252;'>Todos os dados serão perdidos!</span><br>"
                "📀 Instalação limpa do FydelisTechOS"
            ).arg(m_disks[idx].description());
        }
        break;
    }
    case 2: {
        int idx = m_manualDiskCombo->currentIndex();
        if (idx >= 0 && idx < m_disks.size()) {
            int parts = m_disks[idx].partitions.size();
            summary = QString(
                "⚙️ <b>Particionamento manual</b> — %1<br>"
                "📊 %2 partição(ões) encontrada(s)<br>"
                "🛠️ Configure as partições manualmente"
            ).arg(m_disks[idx].description()).arg(parts);
        }
        break;
    }
    }

    if (summary.isEmpty()) {
        summary = "<span style='color:#888;'>Nenhuma opção de instalação selecionada.</span>";
    }

    m_summaryLabel->setText(summary);
    emit selectionChanged(summary);
    emit readyChanged(!summary.isEmpty());
}

void PartitionPage::refreshClicked() {
    refreshDisks();
}

QList<PartitionAction> PartitionPage::getActions() const {
    return m_actions;
}

QString PartitionPage::getInstallDevice() const {
    switch (m_typeGroup->checkedId()) {
    case 0: return m_dualBootDiskCombo->currentData().toString();
    case 1: return m_eraseDiskCombo->currentData().toString();
    case 2: return m_manualDiskCombo->currentData().toString();
    default: return "";
    }
}

bool PartitionPage::isDualBootSelected() const {
    return m_typeGroup->checkedId() == 0;
}

bool PartitionPage::isEraseDiskSelected() const {
    return m_typeGroup->checkedId() == 1;
}

void PartitionPage::onManualActionClicked() {
    // Espaço reservado para ações manuais
}
