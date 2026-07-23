#ifndef INSTALLWORKER_H
#define INSTALLWORKER_H

#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QElapsedTimer>
#include <QThread>

class InstallWorker : public QObject {
    Q_OBJECT

public:
    explicit InstallWorker(QObject *parent = nullptr);
    ~InstallWorker();

    // ─── Configuração ──────────────────────────────────────────────
    void setPackages(const QStringList &packages);
    void setInstallDevice(const QString &device);
    void setDualBoot(bool enabled);
    void setEraseDisk(bool enabled);
    void setInstallPath(const QString &path);
    void setSkipUpdate(bool skip);
    void setVerbose(bool verbose);
    void setDryRun(bool dryRun);

    // ─── Getters ───────────────────────────────────────────────────
    QStringList packages() const { return m_packages; }
    QString installDevice() const { return m_installDevice; }
    bool isDualBoot() const { return m_dualBoot; }
    bool isEraseDisk() const { return m_eraseDisk; }
    bool isDryRun() const { return m_dryRun; }

public slots:
    void run();
    void cancel();

signals:
    void progressUpdated(int percent, const QString &status);
    void logMessage(const QString &message, bool isError = false);
    void finished(bool success, const QString &summary);
    void packageStarted(const QString &pkgName, int current, int total);
    void packageFinished(const QString &pkgName, bool success);

private:
    // ─── Etapas da instalação ──────────────────────────────────────
    bool stepPartitioning();        // Particiona o disco
    bool stepSystemDeps();          // Dependências do sistema
    bool stepUpdatePackageList();   // apt-get update
    bool stepInstallPackages();     // Instala ferramentas selecionadas
    bool stepCreateDirectories();   // Cria estrutura de diretórios
    bool stepConfigureAliases();    // Configura aliases no bash/zsh
    bool stepCreateCheatsheets();   // Cria cheatsheets educacionais
    bool stepFinalize();            // Finalização

    // ─── Utilitários ───────────────────────────────────────────────
    QString runCommand(const QString &cmd, const QStringList &args = {});
    QString runBash(const QString &script);
    bool isPackageInstalled(const QString &pkg);
    void emitProgress(int percent, const QString &status);
    void emitLog(const QString &msg, bool isErr = false);

    // ─── Estado ────────────────────────────────────────────────────
    QProcess    *m_process;
    QStringList  m_packages;
    QString      m_installDevice;
    QString      m_installPath;
    bool         m_dualBoot;
    bool         m_eraseDisk;
    bool         m_skipUpdate;
    bool         m_verbose;
    bool         m_dryRun;
    bool         m_cancelled;
    int          m_progress;
    QElapsedTimer m_timer;

    // Constantes
    static constexpr int PROGRESS_PARTITION   = 5;
    static constexpr int PROGRESS_DEPS        = 10;
    static constexpr int PROGRESS_UPDATE      = 15;
    static constexpr int PROGRESS_INSTALL_MIN = 15;
    static constexpr int PROGRESS_INSTALL_MAX = 85;
    static constexpr int PROGRESS_DIRS        = 90;
    static constexpr int PROGRESS_ALIASES     = 95;
    static constexpr int PROGRESS_CHEATS      = 98;
    static constexpr int PROGRESS_DONE        = 100;
};

#endif // INSTALLWORKER_H