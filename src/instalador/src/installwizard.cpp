#include "installwizard.h"

#include "welcomepage.h"
#include "preparationpage.h"
#include "partitionpage.h"
#include "toolselectionpage.h"
#include "slideshowpage.h"     // ← NOVO include
#include "summarypage.h"

#include <QFrame>
#include <QScrollArea>
#include <QMessageBox>

InstallWizard::InstallWizard(QWidget *parent)
    : QWidget(parent)
    , m_welcomePage(nullptr)
    , m_preparationPage(nullptr)
    , m_partitionPage(nullptr)
    , m_toolsPage(nullptr)
    , m_slideshowPage(nullptr)
    , m_summaryPage(nullptr)
    , m_currentPage(0)
    , m_installing(false)
{
    setupStyleSheet();
    setupUI();
}

void InstallWizard::setupStyleSheet() {
    setStyleSheet(R"(
        * { font-family: 'DejaVu Sans', 'Ubuntu', 'Noto Sans', sans-serif; }
        QWidget { background-color: #1a1a2e; color: #e0e0e0; }

        /* Sidebar */
        #sidebar {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #0a0a1e, stop:1 #0f3460);
            border-right: 2px solid #00d4ff;
        }
        #sidebar QLabel {
            color: #555;
            font-size: 12px;
            padding: 8px 15px;
        }
        #sidebar QLabel[active="true"] {
            color: #00d4ff;
            font-weight: bold;
        }
        #sidebar QLabel[done="true"] {
            color: #00c853;
        }
        #sidebar #logoLabel {
            font-size: 16px;
            font-weight: bold;
            color: #00d4ff;
            padding: 20px 15px;
        }

        /* Navegação */
        #navBar QPushButton {
            font-size: 14px;
            padding: 10px 30px;
            border-radius: 6px;
            font-weight: bold;
        }
        QPushButton#btnBack {
            background-color: #16213e;
            color: #00d4ff;
            border: 1px solid #00d4ff;
        }
        QPushButton#btnBack:hover { background-color: #0a1a3a; }
        QPushButton#btnNext {
            background-color: #00c853;
            color: white;
            border: none;
        }
        QPushButton#btnNext:hover { background-color: #00e676; }
        QPushButton#btnNext:disabled {
            background-color: #2a2a3e;
            color: #666;
        }
        #stepIndicator {
            color: #888;
            font-size: 11px;
        }
    )");
}

void InstallWizard::setupUI() {
    QHBoxLayout *mainLayout = new QHBoxLayout(this);
    mainLayout->setContentsMargins(0, 0, 0, 0);
    mainLayout->setSpacing(0);

    // ─── Sidebar ───────────────────────────────────────────────────
    m_sidebar = new QWidget;
    m_sidebar->setObjectName("sidebar");
    m_sidebar->setFixedWidth(220);

    QVBoxLayout *sidebarLayout = new QVBoxLayout(m_sidebar);
    sidebarLayout->setContentsMargins(0, 0, 0, 0);
    sidebarLayout->setSpacing(0);

    // Logo
    m_logoLabel = new QLabel("⚡ FydelisTechOS");
    m_logoLabel->setObjectName("logoLabel");
    sidebarLayout->addWidget(m_logoLabel);

    sidebarLayout->addSpacing(20);

    QFrame *sep = new QFrame;
    sep->setFrameShape(QFrame::HLine);
    sep->setStyleSheet("color: #16213e;");
    sidebarLayout->addWidget(sep);
    sidebarLayout->addSpacing(10);

    // Passos
    struct Step { QString icon; QString title; QString desc; };
    QList<Step> steps = {
        {"🖥️", "Boas-vindas",      "Idioma e introdução"},
        {"🔧", "Preparação",        "Teclado, rede, updates"},
        {"📀", "Particionamento",   "Discos e dual boot"},
        {"🧰", "Ferramentas",       "Seleção de pacotes"},
        {"⚙️", "Instalação",       "Copiando arquivos..."},
        {"✅", "Conclusão",         "Finalizado!"},
    };

    for (int i = 0; i < steps.size(); ++i) {
        QWidget *stepWidget = new QWidget;
        QHBoxLayout *stepLayout = new QHBoxLayout(stepWidget);
        stepLayout->setContentsMargins(15, 8, 15, 8);

        QLabel *iconLabel = new QLabel(steps[i].icon);
        iconLabel->setStyleSheet("font-size: 18px;");
        stepLayout->addWidget(iconLabel);

        QVBoxLayout *textLayout = new QVBoxLayout;
        QLabel *titleLabel = new QLabel(steps[i].title);
        titleLabel->setStyleSheet("font-weight: bold; font-size: 13px;");
        textLayout->addWidget(titleLabel);

        QLabel *descLabel = new QLabel(steps[i].desc);
        descLabel->setStyleSheet("font-size: 10px; color: #666;");
        textLayout->addWidget(descLabel);

        stepLayout->addLayout(textLayout, 1);

        // Guarda referência do LABEL do título (não do widget inteiro)
        m_stepLabels.append(titleLabel);
        sidebarLayout->addWidget(stepWidget);
    }

    sidebarLayout->addStretch();

    QLabel *versionLabel = new QLabel("v1.0 Lite");
    versionLabel->setStyleSheet("color: #444; font-size: 10px; padding: 15px;");
    sidebarLayout->addWidget(versionLabel);

    mainLayout->addWidget(m_sidebar);

    // ─── Conteúdo principal ────────────────────────────────────────
    QWidget *contentArea = new QWidget;
    QVBoxLayout *contentLayout = new QVBoxLayout(contentArea);
    contentLayout->setContentsMargins(0, 0, 0, 0);
    contentLayout->setSpacing(0);

    // Stack de páginas
    m_contentStack = new QStackedWidget;

    // Cria as páginas
    m_welcomePage      = new WelcomePage(this);
    m_preparationPage  = new PreparationPage(this);
    m_partitionPage    = new PartitionPage(this);
    m_toolsPage        = new ToolSelectionPage(this);
    m_slideshowPage    = new SlideshowPage(this);   // ← InstallPage → SlideshowPage
    m_summaryPage      = new SummaryPage(this);

    // Função auxiliar para wrap em scroll area
    auto wrapInScroll = [](QWidget *page) -> QWidget* {
        QScrollArea *scroll = new QScrollArea;
        scroll->setWidget(page);
        scroll->setWidgetResizable(true);
        scroll->setFrameShape(QFrame::NoFrame);
        scroll->setStyleSheet(
            "QScrollArea { background-color: #1a1a2e; border: none; }"
            "QScrollBar:vertical { width: 8px; background: #0a0a1a; }"
            "QScrollBar::handle:vertical { background: #0f3460; border-radius: 4px; }"
        );
        return scroll;
    };

    // Para a página de slides, NÃO coloca em ScrollArea (já tem scroll interno)
    m_contentStack->addWidget(wrapInScroll(m_welcomePage));        // 0
    m_contentStack->addWidget(wrapInScroll(m_preparationPage));    // 1
    m_contentStack->addWidget(wrapInScroll(m_partitionPage));      // 2
    m_contentStack->addWidget(wrapInScroll(m_toolsPage));          // 3
    m_contentStack->addWidget(m_slideshowPage);                    // 4 — SEM scroll extra
    m_contentStack->addWidget(wrapInScroll(m_summaryPage));        // 5

    contentLayout->addWidget(m_contentStack, 1);

    // ─── Barra de navegação inferior ───────────────────────────────
    QWidget *navBar = new QWidget;
    navBar->setObjectName("navBar");
    navBar->setFixedHeight(60);
    navBar->setStyleSheet("background-color: #0f3460; border-top: 1px solid #16213e;");

    QHBoxLayout *navLayout = new QHBoxLayout(navBar);
    navLayout->setContentsMargins(20, 8, 20, 8);

    m_stepIndicator = new QLabel("Passo 1 de 6");
    m_stepIndicator->setObjectName("stepIndicator");
    navLayout->addWidget(m_stepIndicator);

    navLayout->addStretch();

    m_backBtn = new QPushButton("← Voltar");
    m_backBtn->setObjectName("btnBack");
    m_backBtn->setFixedSize(120, 38);
    m_backBtn->setCursor(Qt::PointingHandCursor);
    connect(m_backBtn, &QPushButton::clicked, this, &InstallWizard::goBack);

    m_nextBtn = new QPushButton("Continuar →");
    m_nextBtn->setObjectName("btnNext");
    m_nextBtn->setFixedSize(160, 42);
    m_nextBtn->setCursor(Qt::PointingHandCursor);
    connect(m_nextBtn, &QPushButton::clicked, this, &InstallWizard::goNext);

    navLayout->addWidget(m_backBtn);
    navLayout->addSpacing(10);
    navLayout->addWidget(m_nextBtn);

    contentLayout->addWidget(navBar);

    mainLayout->addWidget(contentArea, 1);

    // ─── Conexão do sinal de instalação finalizada ─────────────────
    connect(m_slideshowPage, &SlideshowPage::installationFinished,
            this, &InstallWizard::onInstallFinished);

    // Estado inicial
    updateNavigation();
}

// ─── Iniciar wizard ─────────────────────────────────────────────────────────

void InstallWizard::start() {
    m_currentPage = 0;
    m_contentStack->setCurrentIndex(0);
    updateNavigation();
	
	#ifdef Q_OS_WIN
	
	#endif
}

// ─── Navegação ──────────────────────────────────────────────────────────────

void InstallWizard::goNext() {
    if (m_installing) return;

    // Validação antes de avançar
    switch (m_currentPage) {
    case PAGE_PARTITION: {
        // Verifica se selecionou alguma opção de partição
        QString dev = m_partitionPage->getInstallDevice();
        if (dev.isEmpty()) {
            QMessageBox::warning(this, "Partição necessária",
                "Selecione um disco e um tipo de instalação antes de continuar.");
            return;
        }
        break;
    }
    case PAGE_TOOLS: {
        // Verifica se selecionou pelo menos uma ferramenta
        if (m_toolsPage->getSelectedPackages().isEmpty()) {
            QMessageBox::warning(this, "Nenhuma ferramenta",
                "Selecione pelo menos uma ferramenta para instalar.");
            return;
        }
        break;
    }
    case PAGE_INSTALL:
        // Instalação já rodando — não faz nada
        return;
    }

    if (m_currentPage < PAGE_COUNT - 1) {
        m_currentPage++;
        m_contentStack->setCurrentIndex(m_currentPage);

        // Ao chegar na página de instalação, dispara a instalação
        if (m_currentPage == PAGE_INSTALL) {
            m_installing = true;
            m_nextBtn->setEnabled(false);
            m_nextBtn->setText("⏳ Instalando...");
            m_backBtn->setEnabled(false);

            // Pega dados das páginas anteriores
            QStringList pkgs = m_toolsPage->getSelectedPackages();
            QString installDev = m_partitionPage->getInstallDevice();
            bool dualBoot = m_partitionPage->isDualBootSelected();
            bool eraseDisk = m_partitionPage->isEraseDiskSelected();

            // Tenta carregar slides do diretório onde o instalador está
            QString slidesDir = QCoreApplication::applicationDirPath() + "/slides";
            if (QDir(slidesDir).exists()) {
                m_slideshowPage->setSlidesDirectory(slidesDir);
            }

            // Inicia a instalação em background com slides
            m_slideshowPage->startInstallation(pkgs, installDev, dualBoot, eraseDisk);
        }

        updateNavigation();
    }
}

void InstallWizard::goBack() {
    if (m_installing) return; // Não volta durante instalação
    if (m_currentPage > 0) {
        m_currentPage--;
        m_contentStack->setCurrentIndex(m_currentPage);
        updateNavigation();
    }
}

void InstallWizard::onPageChanged(int page) {
    if (m_installing) return;
    m_currentPage = page;
    m_contentStack->setCurrentIndex(page);
    updateNavigation();
}

// ─── Chamado quando a instalação termina (sucesso ou falha) ─────────────────

void InstallWizard::onInstallFinished(bool success, const QString &summary) {
    Q_UNUSED(summary);

    m_installing = false;

    // Avança para página de resumo
    m_currentPage = PAGE_SUMMARY;
    m_contentStack->setCurrentIndex(PAGE_SUMMARY);

    // Passa o resultado para a SummaryPage
    m_summaryPage->setResult(success, summary);

    // Atualiza navegação
    updateNavigation();

    // Reconfigura botão "Finalizar"
    m_nextBtn->setVisible(true);
    m_nextBtn->setText("🏁 Finalizar");
    m_nextBtn->setEnabled(true);
    m_backBtn->setVisible(false);

    // Desconecta goNext e conecta quit
    disconnect(m_nextBtn, &QPushButton::clicked, this, &InstallWizard::goNext);
    connect(m_nextBtn, &QPushButton::clicked, qApp, &QApplication::quit);
}

// ─── Atualização da interface ───────────────────────────────────────────────

void InstallWizard::updateNavigation() {
    QStringList stepNames = {
        "Boas-vindas", "Preparação", "Particionamento",
        "Ferramentas", "Instalação", "Conclusão"
    };

    // Sidebar
    for (int i = 0; i < m_stepLabels.size() && i < stepNames.size(); ++i) {
        QString style;
        if (i == m_currentPage) {
            style = "color: #00d4ff; font-weight: bold; font-size: 13px;";
        } else if (i < m_currentPage) {
            style = "color: #00c853; font-size: 12px;";
        } else {
            style = "color: #555; font-size: 12px;";
        }
        m_stepLabels[i]->setStyleSheet(style);
    }

    // Botões
    if (m_currentPage == PAGE_SUMMARY) {
        m_backBtn->setVisible(false);
        m_nextBtn->setVisible(true);
        m_nextBtn->setText("🏁 Finalizar");
        m_nextBtn->setEnabled(true);
        disconnect(m_nextBtn, &QPushButton::clicked, this, &InstallWizard::goNext);
        connect(m_nextBtn, &QPushButton::clicked, qApp, &QApplication::quit);
    } else if (m_currentPage == PAGE_INSTALL) {
        m_backBtn->setVisible(false);
        m_nextBtn->setVisible(false);
    } else {
        m_backBtn->setVisible(m_currentPage > 0);
        m_backBtn->setEnabled(true);
        m_nextBtn->setVisible(true);
        m_nextBtn->setText(m_currentPage == PAGE_COUNT - 2 ? "▶ Instalar" : "Continuar →");
        m_nextBtn->setEnabled(true);
        m_nextBtn->disconnect(SIGNAL(clicked()));
        connect(m_nextBtn, &QPushButton::clicked, this, &InstallWizard::goNext);
    }

    // Indicador de passo
    m_stepIndicator->setText(QString("Passo %1 de %2 — %3")
        .arg(m_currentPage + 1)
        .arg(PAGE_COUNT)
        .arg(stepNames.value(m_currentPage, "")));
}