#include "installpage.h"
#include "slides_content.h"
#include <QScrollBar>
#include <QDateTime>

InstallPage::InstallPage(QWidget *parent)
    : QWidget(parent)
    , m_worker(nullptr)
    , m_workerThread(nullptr)
    , m_cancelled(false)
{
    setupUI();
}

void InstallPage::setupUI() {
    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);

    QSplitter *splitter = new QSplitter(Qt::Vertical, this);
    splitter->setHandleWidth(3);
    splitter->setStyleSheet("QSplitter::handle { background-color: #16213e; }");

    // ─── Slide Player (painel superior — 60%) ──────────────────────
    m_slidePlayer = new SlidePlayer(this);
    m_slidePlayer->setSlides(createFydelisSlides());
    m_slidePlayer->setAutoAdvanceInterval(15);
    splitter->addWidget(m_slidePlayer);

    // ─── Painel inferior (40%) ─────────────────────────────────────
    QWidget *bottomPanel = new QWidget;
    QVBoxLayout *bottomLayout = new QVBoxLayout(bottomPanel);
    bottomLayout->setContentsMargins(15, 10, 15, 10);
    bottomLayout->setSpacing(8);

    m_statusLabel = new QLabel("⏳ Preparando instalação...");
    m_statusLabel->setStyleSheet("color: #00d4ff; font-size: 14px; font-weight: bold;");
    bottomLayout->addWidget(m_statusLabel);

    m_progressBar = new QProgressBar;
    m_progressBar->setValue(0);
    m_progressBar->setTextVisible(true);
    m_progressBar->setFixedHeight(24);
    m_progressBar->setStyleSheet(
        "QProgressBar { background-color: #0a0a1a; border: 1px solid #16213e; border-radius: 6px; color: white; font-weight: bold; text-align: center; }"
        "QProgressBar::chunk { background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #00d4ff, stop:1 #00c853); border-radius: 5px; }"
    );
    bottomLayout->addWidget(m_progressBar);

    QLabel *logTitle = new QLabel("<b style='color:#aaa;'>📋 Log da instalação:</b>");
    bottomLayout->addWidget(logTitle);

    m_logOutput = new QTextEdit;
    m_logOutput->setReadOnly(true);
    m_logOutput->setMinimumHeight(100);
    m_logOutput->setStyleSheet(
        "QTextEdit { background-color: #0a0a1a; color: #00ff00; border: 1px solid #16213e; border-radius: 4px; font-family: 'Courier New', monospace; font-size: 12px; }"
    );
    bottomLayout->addWidget(m_logOutput, 1);

    QHBoxLayout *btnLayout = new QHBoxLayout;
    m_cancelBtn = new QPushButton("✕ Cancelar Instalação");
    m_cancelBtn->setStyleSheet(
        "QPushButton { background-color: #d32f2f; color: white; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold; }"
        "QPushButton:hover { background-color: #f44336; }"
        "QPushButton:disabled { background-color: #2a2a3e; color: #666; }"
    );
    m_cancelBtn->setCursor(Qt::PointingHandCursor);
    m_cancelBtn->setFixedSize(180, 38);
    connect(m_cancelBtn, &QPushButton::clicked, this, &InstallPage::onCancelClicked);

    btnLayout->addStretch();
    btnLayout->addWidget(m_cancelBtn);
    bottomLayout->addLayout(btnLayout);

    splitter->addWidget(bottomPanel);

    // Proporção 60/40
    splitter->setStretchFactor(0, 3);
    splitter->setStretchFactor(1, 2);

    layout->addWidget(splitter);
}

void InstallPage::startInstallation(const QStringList &packages,
                                   const QString &installDevice,
                                   bool dualBoot,
                                   bool eraseDisk) {
    m_cancelled = false;
    m_logOutput->clear();
    m_progressBar->setValue(0);
    m_cancelBtn->setEnabled(true);
    m_cancelBtn->setText("✕ Cancelar Instalação");
    m_statusLabel->setText("⏳ Iniciando instalação...");

    // Inicia slides automáticos
    m_slidePlayer->startAutoPlay();

    // Setup worker
    m_worker = new InstallWorker;
    m_worker->setPackages(packages);
    m_worker->setInstallDevice(installDevice);
    m_worker->setDualBoot(dualBoot);
    m_worker->setEraseDisk(eraseDisk);

    m_workerThread = new QThread(this);
    m_worker->moveToThread(m_workerThread);

    connect(m_workerThread, &QThread::started, m_worker, &InstallWorker::run);
    connect(m_worker, &InstallWorker::progressUpdated, this, &InstallPage::onProgressUpdated);
    connect(m_worker, &InstallWorker::logMessage, this, &InstallPage::onLogMessage);
    connect(m_worker, &InstallWorker::packageStarted, this, &InstallPage::onPackageStarted);
    connect(m_worker, &InstallWorker::packageFinished, this, &InstallPage::onPackageFinished);
    connect(m_worker, &InstallWorker::finished, this, &InstallPage::onInstallFinished);
    connect(m_worker, &InstallWorker::finished, m_workerThread, &QThread::quit);
    connect(m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);

    m_workerThread->start();
}

void InstallPage::onProgressUpdated(int percent, const QString &status) {
    m_progressBar->setValue(percent);
    m_statusLabel->setText(QString("📌 %1").arg(status));
}

void InstallPage::onLogMessage(const QString &message, bool isError) {
    QString color = isError ? "#ff5252" : "#00ff00";
    QString ts = QDateTime::currentDateTime().toString("HH:mm:ss");
    m_logOutput->append(QString("<span style='color:%1'>[%2] %3</span>").arg(color, ts, message.toHtmlEscaped()));

    QScrollBar *sb = m_logOutput->verticalScrollBar();
    sb->setValue(sb->maximum());
    QApplication::processEvents();
}

void InstallPage::onPackageStarted(const QString &pkg, int current, int total) {
    m_statusLabel->setText(QString("📦 Instalando %1 (%2/%3)").arg(pkg).arg(current).arg(total));
}

void InstallPage::onPackageFinished(const QString &pkg, bool success) {
    Q_UNUSED(pkg);
    Q_UNUSED(success);
}

void InstallPage::onInstallFinished(bool success, const QString &summary) {
    m_slidePlayer->stopAutoPlay();
    m_cancelBtn->setEnabled(false);
    m_cancelBtn->setText("✓ Concluído");

    if (success) {
        m_statusLabel->setText("✅ Instalação concluída com sucesso!");
        m_statusLabel->setStyleSheet("color: #00c853; font-size: 14px; font-weight: bold;");
    } else {
        m_statusLabel->setText("❌ Instalação interrompida");
        m_statusLabel->setStyleSheet("color: #ff5252; font-size: 14px; font-weight: bold;");
    }

    m_progressBar->setValue(success ? 100 : 0);

    emit installationFinished(success, summary);

    // Limpeza da thread
    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
        m_workerThread = nullptr;
    }
}

void InstallPage::onCancelClicked() {
    if (m_worker) {
        m_worker->cancel();
        m_cancelBtn->setEnabled(false);
        m_cancelBtn->setText("⏳ Cancelando...");
        m_statusLabel->setText("⚠️ Cancelando instalação...");
        m_statusLabel->setStyleSheet("color: #ffd700; font-size: 14px; font-weight: bold;");
        onLogMessage("\n⚠️  Cancelamento solicitado pelo usuário.\n", true);
    }
}