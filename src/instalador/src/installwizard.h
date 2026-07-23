#ifndef INSTALLWIZARD_H
#define INSTALLWIZARD_H

#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QStackedWidget>
#include <QLabel>
#include <QPushButton>
#include <QProgressBar>
#include <QApplication>

// Forward declarations
class WelcomePage;
class PreparationPage;
class PartitionPage;
class ToolSelectionPage;
class SummaryPage;

// ─── SUBSTITUIMOS InstallPage por SlideshowPage ─────────────────────────────
class SlideshowPage;   // <-- NOVO: em vez de InstallPage

// ─── InstallWizard — Wizard completo estilo Ubuntu Ubiquity ─────────────────
class InstallWizard : public QWidget {
    Q_OBJECT

public:
    explicit InstallWizard(QWidget *parent = nullptr);

    void start(); // Inicia o wizard

signals:
    void finished(bool success);

private slots:
    void goNext();
    void goBack();
    void onPageChanged(int page);
    void onInstallFinished(bool success, const QString &summary);

private:
    void setupUI();
    void updateNavigation();
    void setupStyleSheet();

    enum Page {
        PAGE_WELCOME = 0,
        PAGE_PREPARATION,
        PAGE_PARTITION,
        PAGE_TOOLS,
        PAGE_INSTALL,      // ← Agora é SlideshowPage
        PAGE_SUMMARY,
        PAGE_COUNT
    };

    // ─── Sidebar ───────────────────────────────────────────────────
    QWidget *m_sidebar;
    QList<QLabel*> m_stepLabels;
    QLabel *m_logoLabel;

    // ─── Conteúdo ──────────────────────────────────────────────────
    QStackedWidget *m_contentStack;

    WelcomePage       *m_welcomePage;
    PreparationPage   *m_preparationPage;
    PartitionPage     *m_partitionPage;
    ToolSelectionPage  *m_toolsPage;
    SlideshowPage     *m_slideshowPage;   // ← ANTES era InstallPage *m_installPage;
    SummaryPage       *m_summaryPage;

    // ─── Navegação ─────────────────────────────────────────────────
    QPushButton *m_backBtn;
    QPushButton *m_nextBtn;
    QLabel *m_stepIndicator;

    int m_currentPage;
    bool m_installing;
};

#endif // INSTALLWIZARD_H