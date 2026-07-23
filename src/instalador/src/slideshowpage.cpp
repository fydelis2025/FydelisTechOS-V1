#include "slideshowpage.h"
#include <QScrollBar>
#include <QDateTime>
#include <QDir>
#include <QApplication>

SlideshowPage::SlideshowPage(QWidget *parent)
    : QWidget(parent)
    , m_worker(nullptr)
    , m_workerThread(nullptr)
    , m_cancelled(false)
{
    setupUI();

    // Tenta carregar slides do diretório padrão
    QStringList defaultDirs = {
        "/usr/share/fydelistechos/slides",
        "/opt/fydelistechos/slides",
        QDir::currentPath() + "/slides",
        QApplication::applicationDirPath() + "/slides",
        QDir::homePath() + "/FydelisTechOS/slides"
    };

    for (const auto &dir : defaultDirs) {
        if (QDir(dir).exists()) {
            m_slideShow->setImageDirectory(dir);
            break;
        }
    }

    // Se ainda não carregou nada, tenta paths relativos
    if (m_slideShow->totalSlides() == 0) {
        QStringList tryPaths;
        for (int i = 1; i <= 5; ++i) {
            tryPaths << QString("slide%1.png").arg(i);
            tryPaths << QString("slides/slide%1.png").arg(i);
        }
        m_slideShow->setImagePaths(tryPaths);
    }
}

void SlideshowPage::setupUI() {
    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);

    QSplitter *splitter = new QSplitter(Qt::Vertical, this);
    splitter->setHandleWidth(3);
    splitter->setStyleSheet("QSplitter::handle { background-color: #16213e; }");

    // ─── Slide show de imagens (painel superior — 65%) ────────────
    m_slideShow = new ImageSlidePlayer(this);
    splitter->addWidget(m_slideShow);

    // ─── Painel inferior (35%) ─────────────────────────────────────
    QWidget *bottomPanel = new QWidget;
    bottomPanel->setStyleSheet("background-color: #0a0a1a;");
    QVBoxLayout *bottomLayout = new QVBoxLayout(bottomPanel);
    bottomLayout->setContentsMargins(20, 12, 20, 12);
    bottomLayout->setSpacing(8);

    // Status / nome do pacote atual
    m_statusLabel = new QLabel("⏳ Preparando instalação...");
    m_statusLabel->setStyleSheet("color: #00d4ff; font-size: 13px; font-weight: bold;");
    bottomLayout->addWidget(m_statusLabel);

    // Barra de progresso
    m_progressBar = new QProgressBar;
    m_progressBar->setValue(0);
    m_progressBar->setTextVisible(true);
    m_progressBar->setFixedHeight(26);
    m_progressBar->setStyleSheet(
        "QProgressBar {"
        "  background-color: #0a0a1a;"
        "  border: 1px solid #16213e;"
        "  border-radius: 6px;"
        "  color: white;"
        "  font-weight: bold;"
        "  text-align: center;"
        "  font-size: 12px;"
        "}"
        "QProgressBar::chunk {"
        "  background: qlineargradient(x1:0, y1:0, x2:1, y2:0,"
        "      stop:0 #00d4ff, stop:1 #00c853);"
        "  border-radius: 5px;"
        "}"
    );
    bottomLayout->addWidget(m_progressBar);

    // Log (recolhível)
    QLabel *logTitle = new QLabel(
        "<span style='color:#888; font-size:11px;'>📋 Log da instalação "
        "<span style='color:#555;'>(clique para expandir/recolher)</span></span>"
    );
    logTitle->setCursor(Qt::PointingHandCursor);
    bottomLayout->addWidget(logTitle);

    m_logOutput = new QTextEdit;
    m_logOutput->setReadOnly(true);
    m_logOutput->setMaximumHeight(120);
    m_logOutput->setStyleSheet(
        "QTextEdit {"
        "  background-color: #050510;"
        "  color: #00ff00;"
        "  border: 1px solid #16213e;"
        "  border-radius: 4px;"
        "  font-family: 'Courier New', 'Consolas', monospace;"
        "  font-size: 11px;"
        "  padding: 6px;"
        "}"
    );

    // Recolhe/exibe log ao clicar no título
    m_logOutput->setVisible(false);
    connect(logTitle, &QLabel::linkActivated, this, [this]() { /* não usado */ });
    // Vamos fazer via clique mesmo
    logTitle->installEventFilter(this);
    // Na prática, usamos um toggle via lambda
    static bool logVisible = false;
    connect(logTitle, &QLabel::linkActivated, [](const QString&){});
    // Melhor: usar QPushButton estilizado
    // Vou substituir por um botão pequeno:

    bottomLayout->removeWidget(logTitle);
    delete logTitle;

    QPushButton *toggleLogBtn = new QPushButton("📋 Log da instalação  ▼");
    toggleLogBtn->setStyleSheet(
        "QPushButton { background-color: transparent; color: #888; border: none; font-size: 11px; text-align: left; padding: 2px 0; }"
        "QPushButton:hover { color: #aaa; }"
    );
    toggleLogBtn->setCursor(Qt::PointingHandCursor);
    connect(toggleLogBtn, &QPushButton::clicked, this, [this, toggleLogBtn]() {
        bool visible = !m_logOutput->isVisible();
        m_logOutput->setVisible(visible);
        toggleLogBtn->setText(visible ? "📋 Log da instalação  ▲" : "📋 Log da instalação  ▼");
    });
    bottomLayout->addWidget(toggleLogBtn);
    bottomLayout->addWidget(m_logOutput);

    // Botão cancelar
    QHBoxLayout *btnLayout = new QHBoxLayout;
    btnLayout->setContentsMargins(0, 4, 0, 0);

    m_cancelBtn = new QPushButton("✕ Cancelar Instalação");
    m_cancelBtn->setStyleSheet(
        "QPushButton {"
        "  background-color: #d32f2f;"
        "  color: white;"
        "  border: none;"
        "  border-radius: 6px;"
        "  padding: 8px 24px;"
        "  font-weight: bold;"
        "  font-size: 12px;"
        "}"
        "QPushButton:hover { background-color: #f44336; }"
        "QPushButton:disabled { background-color: #2a2a3e; color: #666; }"
    );
    m_cancelBtn->setCursor(Qt::PointingHandCursor);
    m_cancelBtn->setFixedHeight(36);
    connect(m_cancelBtn, &QPushButton::clicked, this, &SlideshowPage::onCancelClicked);

    btnLayout->addStretch();
    btnLayout->addWidget(m_cancelBtn);
    bottomLayout->addLayout(btnLayout);

    splitter->addWidget(bottomPanel);

    // Proporção 65% slides / 35% log
    splitter->setStretchFactor(0, 65);
    splitter->setStretchFactor(1, 35);

    layout->addWidget(splitter);
}

// ─── Gerenciamento de slides ───────────────────────────────────────────────

void SlideshowPage::setSlidesDirectory(const QString &path) {
    m_slideShow->setImageDirectory(path);
}

void SlideshowPage::setSlidesPaths(const QStringList &paths) {
    m_slideShow->setImagePaths(paths);
}

// ─── Instalação ─────────────────────────────────────────────────────────────

void SlideshowPage::startInstallation(const QStringList &packages,
                                     const QString &installDevice,
                                     bool dualBoot,
                                     bool eraseDisk) {
    m_cancelled = false;
    m_logOutput->clear();
    m_logOutput->setVisible(false);
    m_progressBar->setValue(0);
    m_cancelBtn->setEnabled(true);
    m_cancelBtn->setText("✕ Cancelar Instalação");
    m_statusLabel->setText("⏳ Iniciando instalação...");

    // Log inicial
    onLogMessage("🚀 Iniciando instalação do FydelisTechOS Lite...\n", false);
    onLogMessage(QString("📦 Pacotes a instalar: %1\n").arg(packages.size()), false);
    onLogMessage(QString("💾 Disco alvo: %1\n").arg(installDevice), false);
    if (dualBoot) onLogMessage("🔀 Modo: Dual Boot\n", false);
    if (eraseDisk) onLogMessage("💥 Modo: Apagar disco\n", false);

    // Worker
    m_worker = new InstallWorker;
    m_worker->setPackages(packages);
    m_worker->setInstallDevice(installDevice);
    m_worker->setDualBoot(dualBoot);
    m_worker->setEraseDisk(eraseDisk);

    m_workerThread = new QThread(this);
    m_worker->moveToThread(m_workerThread);

    connect(m_workerThread, &QThread::started, m_worker, &InstallWorker::run);
    connect(m_worker, &InstallWorker::progressUpdated, this, &SlideshowPage::onProgressUpdated);
    connect(m_worker, &InstallWorker::logMessage, this, &SlideshowPage::onLogMessage);
    connect(m_worker, &InstallWorker::finished, this, &SlideshowPage::onInstallFinished);
    connect(m_worker, &InstallWorker::finished, m_workerThread, &QThread::quit);
    connect(m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);

    m_workerThread->start();
}

// ─── Slots ──────────────────────────────────────────────────────────────────

void SlideshowPage::onProgressUpdated(int percent, const QString &status) {
    m_progressBar->setValue(percent);
    m_statusLabel->setText(QString("📌 %1").arg(status));

    // Avança o slide conforme o progresso!
    m_slideShow->updateProgress(percent);
}

void SlideshowPage::onLogMessage(const QString &message, bool isError) {
    QString color = isError ? "#ff5252" : "#00ff00";
    QString ts = QDateTime::currentDateTime().toString("HH:mm:ss");
    m_logOutput->append(QString("<span style='color:%1'>[%2] %3</span>")
                            .arg(color, ts, message.toHtmlEscaped()));

    QScrollBar *sb = m_logOutput->verticalScrollBar();
    sb->setValue(sb->maximum());
    QApplication::processEvents();
}

void SlideshowPage::onInstallFinished(bool success, const QString &summary) {
    m_cancelBtn->setEnabled(false);
    m_cancelBtn->setText("✓ Concluído");

    if (success) {
        m_statusLabel->setText("✅ Instalação concluída com sucesso!");
        m_statusLabel->setStyleSheet("color: #00c853; font-size: 14px; font-weight: bold;");
        m_progressBar->setValue(100);
        m_slideShow->updateProgress(100); // Último slide
    } else {
        m_statusLabel->setText("❌ Instalação interrompida");
        m_statusLabel->setStyleSheet("color: #ff5252; font-size: 14px; font-weight: bold;");
    }

    emit installationFinished(success, summary);

    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
        m_workerThread = nullptr;
    }
}

void SlideshowPage::onCancelClicked() {
    if (m_worker) {
        m_worker->cancel();
        m_cancelBtn->setEnabled(false);
        m_cancelBtn->setText("⏳ Cancelando...");
        m_statusLabel->setText("⚠️ Cancelando instalação...");
        m_statusLabel->setStyleSheet("color: #ffd700; font-size: 14px; font-weight: bold;");
        onLogMessage("\n⚠️  Cancelamento solicitado pelo usuário.\n", true);
    }
}