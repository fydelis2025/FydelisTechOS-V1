#ifndef INSTALLPAGE_H
#define INSTALLPAGE_H

#include <QWidget>
#include <QVBoxLayout>
#include <QSplitter>
#include <QLabel>
#include <QPushButton>
#include <QProgressBar>
#include <QTextEdit>
#include <QThread>

#include "slideplayer.h"
#include "installworker.h"

class InstallPage : public QWidget {
    Q_OBJECT

public:
    explicit InstallPage(QWidget *parent = nullptr);

    void startInstallation(const QStringList &packages,
                          const QString &installDevice,
                          bool dualBoot,
                          bool eraseDisk);

signals:
    void installationFinished(bool success, const QString &summary);

private slots:
    void onProgressUpdated(int percent, const QString &status);
    void onLogMessage(const QString &message, bool isError);
    void onPackageStarted(const QString &pkg, int current, int total);
    void onPackageFinished(const QString &pkg, bool success);
    void onInstallFinished(bool success, const QString &summary);
    void onCancelClicked();

private:
    void setupUI();

    SlidePlayer    *m_slidePlayer;
    QLabel         *m_statusLabel;
    QProgressBar   *m_progressBar;
    QTextEdit      *m_logOutput;
    QPushButton    *m_cancelBtn;

    QThread        *m_workerThread;
    InstallWorker  *m_worker;
    bool            m_cancelled;
};

#endif // INSTALLPAGE_H