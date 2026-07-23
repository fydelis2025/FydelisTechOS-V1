#ifndef SLIDESHOWPAGE_H
#define SLIDESHOWPAGE_H

#include <QWidget>
#include <QVBoxLayout>
#include <QSplitter>
#include <QLabel>
#include <QPushButton>
#include <QProgressBar>
#include <QTextEdit>
#include <QThread>

#include "imageslideplayer.h"
#include "installworker.h"

// ─── SlideshowPage — Página de instalação com imagens estilo Ubuntu ────────
class SlideshowPage : public QWidget {
    Q_OBJECT

public:
    explicit SlideshowPage(QWidget *parent = nullptr);

    // Define onde buscar as imagens slide1.png ... slide5.png
    void setSlidesDirectory(const QString &path);
    void setSlidesPaths(const QStringList &paths);

    // Inicia a instalação
    void startInstallation(const QStringList &packages,
                          const QString &installDevice,
                          bool dualBoot,
                          bool eraseDisk);

signals:
    void installationFinished(bool success, const QString &summary);

private slots:
    void onProgressUpdated(int percent, const QString &status);
    void onLogMessage(const QString &message, bool isError);
    void onInstallFinished(bool success, const QString &summary);
    void onCancelClicked();

private:
    void setupUI();

    ImageSlidePlayer *m_slideShow;
    QLabel           *m_statusLabel;
    QProgressBar     *m_progressBar;
    QTextEdit        *m_logOutput;
    QPushButton      *m_cancelBtn;

    QThread          *m_workerThread;
    InstallWorker    *m_worker;
    bool              m_cancelled;
};

#endif // SLIDESHOWPAGE_H