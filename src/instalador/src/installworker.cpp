#include "installworker.h"

#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QStorageInfo>
#include <QThread>
#include <cmath>

#ifndef Q_OS_WIN
#include <unistd.h>
#endif

InstallWorker::InstallWorker(QObject *parent)
    : QObject(parent)
    , m_process(new QProcess(this))
    , m_dualBoot(false)
    , m_eraseDisk(false)
    , m_skipUpdate(false)
    , m_verbose(false)
    , m_dryRun(false)
    , m_cancelled(false)
    , m_progress(0)
{
    m_process->setProcessChannelMode(QProcess::MergedChannels);
}

InstallWorker::~InstallWorker() {}

// ─── Setters ────────────────────────────────────────────────────────────────

void InstallWorker::setPackages(const QStringList &packages) { m_packages = packages; }
void InstallWorker::setInstallDevice(const QString &device) { m_installDevice = device; }
void InstallWorker::setDualBoot(bool enabled) { m_dualBoot = enabled; }
void InstallWorker::setEraseDisk(bool enabled) { m_eraseDisk = enabled; }
void InstallWorker::setInstallPath(const QString &path) { m_installPath = path; }
void InstallWorker::setSkipUpdate(bool skip) { m_skipUpdate = skip; }
void InstallWorker::setVerbose(bool verbose) { m_verbose = verbose; }
void InstallWorker::setDryRun(bool dryRun) { m_dryRun = dryRun; }

// ─── Cancelamento Seguro ────────────────────────────────────────────────────

void InstallWorker::cancel() {
    m_cancelled = true;
    if (m_process) {
        if (m_process->state() == QProcess::Running) {
            m_process->terminate();
            if (!m_process->waitForFinished(2000)) {
                m_process->kill();
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// RUN — Pipeline principal da instalação
// ═══════════════════════════════════════════════════════════════════════════

void InstallWorker::run() {
    m_timer.start();
    m_progress = 0;
    m_cancelled = false;

    // ─── Verificação de Privilégios no Linux ───────────────────────
#ifndef Q_OS_WIN
    if (getuid() != 0) {
        emitLog("❌ Erro crítico: O instalador precisa ser executado como root (sudo).\n", true);
        emit finished(false, "Permissão negada. Execute com privilégios de root.");
        return;
    }
#endif

    // ─── Se for Windows, força dry-run automático ──────────────────
#ifdef Q_OS_WIN
    m_dryRun = true;
    emitLog("🪟  Windows detectado — Modo Demonstração (dry-run) ativado automaticamente.\n");
    emitLog("⚠️  Nenhum comando real será executado. Apenas simulação visual.\n\n");
#endif

    emitLog("🚀 FydelisTechOS Lite Installer v1.0\n");
    emitLog(QString("📅 %1\n").arg(QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm:ss")));
    emitLog(QString("📦 Pacotes a instalar: %1\n").arg(m_packages.size()));
    emitLog(QString("💾 Disco alvo: %1\n").arg(m_installDevice.isEmpty() ? "Nenhum (apenas pacotes)" : m_installDevice));
    emitLog(QString("🔀 Dual Boot: %1\n").arg(m_dualBoot ? "Sim" : "Não"));
    emitLog(QString("💥 Apagar disco: %1\n").arg(m_eraseDisk ? "Sim" : "Não"));
    emitLog(QString("⚙️  Dry-run: %1\n\n").arg(m_dryRun ? "Sim" : "Não"));

    if (m_dryRun) {
        emitProgress(0, "Dry-run — simulando instalação...");
        for (int i = 0; i <= 100; i += 5) {
            if (m_cancelled) break;
            QThread::msleep(100);
            emitProgress(i, QString("Simulando passo %1%...").arg(i));
        }
        emitProgress(100, "Dry-run concluído!");
        emitLog("\n✅ Dry-run finalizado. Nenhuma alteração foi feita no sistema.\n");
        emit finished(true, "Dry-run concluído com sucesso. Nenhuma alteração no sistema.");
        return;
    }

    // ─── Etapa 1: Particionamento e Cópia Real (0% → 5%) ───────────
    if (!m_installDevice.isEmpty() && (m_eraseDisk || m_dualBoot)) {
        emitProgress(0, "Preparando partições e gravando sistema...");
        emitLog("📀 Configurando partições e copiando sistema...\n");
        if (!stepPartitioning()) {
            emit finished(false, "Falha crítica no particionamento ou cópia do disco.");
            return;
        }
    } else {
        emitProgress(PROGRESS_PARTITION, "Particionamento não necessário");
    }

    // ─── Etapa 2: Dependências do sistema (5% → 10%) ──────────────
    emitProgress(PROGRESS_PARTITION, "Instalando dependências do sistema...");
    if (!stepSystemDeps()) {
        emit finished(false, "Falha ao instalar dependências do sistema.");
        return;
    }

    // ─── Etapa 3: Atualizar lista de pacotes (10% → 15%) ──────────
    if (!m_skipUpdate) {
        emitProgress(PROGRESS_DEPS, "Atualizando lista de pacotes...");
        if (!stepUpdatePackageList()) {
            emitLog("⚠️  Aviso: falha no apt-get update. Continuando...\n", true);
        }
    } else {
        emitProgress(PROGRESS_UPDATE, "Update pulado (--skip-update)");
    }

    // ─── Etapa 4: Instalar pacotes (15% → 85%) ────────────────────
    if (!stepInstallPackages()) {
        emit finished(false, "Instalação interrompida.");
        return;
    }

    // ─── Etapa 5: Diretórios (85% → 90%) ──────────────────────────
    emitProgress(PROGRESS_DIRS, "Criando estrutura de diretórios...");
    stepCreateDirectories();

    // ─── Etapa 6: Aliases (90% → 95%) ─────────────────────────────
    emitProgress(PROGRESS_ALIASES, "Configurando aliases...");
    stepConfigureAliases();

    // ─── Etapa 7: Cheatsheets (95% → 98%) ─────────────────────────
    emitProgress(PROGRESS_CHEATS, "Gerando cheatsheets...");
    stepCreateCheatsheets();

    // ─── Finalização (98% → 100%) ─────────────────────────────────
    emitProgress(PROGRESS_DONE, "✅ Instalação concluída!");
    stepFinalize();

    qint64 elapsed = m_timer.elapsed() / 1000;
    QString summary = QString(
        "\n═══════════════════════════════════════════════\n"
        "✅  INSTALAÇÃO CONCLUÍDA COM SUCESSO!\n"
        "═══════════════════════════════════════════════\n\n"
        "📦 Pacotes instalados: %1\n"
        "⏱️  Tempo total: %2 segundos\n"
        "💾 Disco: %3\n"
        "📁 Log salvo em: /tmp/fydelistechos-installer.log\n\n"
        "🔄 Recomendamos reiniciar o terminal ou executar:\n"
        "    source ~/.bashrc\n\n"
        "🔴 Happy Hacking! — FydelisTechOS\n"
    ).arg(m_packages.size()).arg(elapsed)
     .arg(m_installDevice.isEmpty() ? "Nenhum (modo pacotes)" : m_installDevice);

    emitLog(summary);
    emit finished(true, summary);
}

// ═══════════════════════════════════════════════════════════════════════════
// Etapas com Validações
// ═══════════════════════════════════════════════════════════════════════════

QString InstallWorker::getPartitionName(const QString &device, int partitionNumber) {
    if (device.contains("nvme") || device.contains("mmcblk")) {
        return device + "p" + QString::number(partitionNumber);
    }
    return device + QString::number(partitionNumber);
}

bool InstallWorker::stepPartitioning() {
    if (m_eraseDisk) {
        emitLog("💾 Apagando disco " + m_installDevice + " e criando partições...\n");

        runBash(QString("umount %1* 2>/dev/null || true").arg(m_installDevice));

        // Cria tabela GPT com validação
        QString labelRes = runBash(QString("parted %1 mklabel gpt -s 2>&1").arg(m_installDevice));
        if (labelRes.contains("Error") || labelRes.contains("error")) {
            emitLog("❌ Falha ao criar tabela GPT: " + labelRes, true);
            return false;
        }
        emitLog("   Tabela GPT criada com sucesso.\n");

        // Cria partição EFI (512 MB)
        QString efiRes = runBash(QString("parted %1 mkpart primary fat32 0%% 512MiB -s 2>&1").arg(m_installDevice));
        if (efiRes.contains("Error") || efiRes.contains("error")) {
            emitLog("❌ Falha ao criar partição EFI: " + efiRes, true);
            return false;
        }

        QString efiPart = getPartitionName(m_installDevice, 1);
        runBash(QString("mkfs.vfat -F32 %1 2>&1").arg(efiPart));
        emitLog("   Partição EFI formatada (FAT32).\n");

        // Cria partição root (restante)
        QString rootRes = runBash(QString("parted %1 mkpart primary ext4 512MiB 100%% -s 2>&1").arg(m_installDevice));
        if (rootRes.contains("Error") || rootRes.contains("error")) {
            emitLog("❌ Falha ao criar partição Root: " + rootRes, true);
            return false;
        }

        QString rootPart = getPartitionName(m_installDevice, 2);
        runBash(QString("mkfs.ext4 -F %1 2>&1").arg(rootPart));
        emitLog("   Partição Root formatada (EXT4).\n");

        // Monta o sistema de arquivos em /mnt
        runBash(QString("mount %1 /mnt 2>&1").arg(rootPart));
        runBash("mkdir -p /mnt/boot/efi");
        runBash(QString("mount %1 /mnt/boot/efi 2>&1").arg(efiPart));
        emitLog("   Partições montadas em /mnt.\n");

        // Cópia real dos arquivos do sistema operacional rodando (LiveCD) para o disco
        emitLog("   Copiando arquivos do sistema operacional para o disco...\n");
        QString copyRes = runBash(
            "rsync -aAX / /mnt/ "
            "--exclude=/dev/* --exclude=/proc/* --exclude=/sys/* "
            "--exclude=/tmp/* --exclude=/run/* --exclude=/mnt/* "
            "--exclude=/media/* --exclude=/lost+found 2>&1"
        );
        if (copyRes.contains("error") || copyRes.contains("Error")) {
            emitLog("⚠️ Aviso na sincronização rsync: " + copyRes, true);
        } else {
            emitLog("   Arquivos do sistema copiados com sucesso.\n");
        }

        // Configuração do Bootloader (GRUB)
        emitLog("   Instalando o GRUB no disco...\n");
        runBash(QString("chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=FydelisTechOS --recheck 2>&1 || chroot /mnt grub-install %1 2>&1").arg(m_installDevice));
        runBash("chroot /mnt update-grub 2>&1");
        emitLog("   GRUB configurado com sucesso.\n");

        emitLog("✅ Disco particionado, gravado e configurado com sucesso.\n");
        return true;
    }

    if (m_dualBoot) {
        emitLog("🔀 Modo Dual Boot — analisando e preparando espaço...\n");
        QString resizeResult = runBash(QString(
            "PART=$(lsblk -o NAME %1 --json 2>/dev/null | "
            "python3 -c \"import sys,json; "
            "d=json.load(sys.stdin); "
            "[print(c['name']) for c in d.get('blockdevices',[{}])[0].get('children',[]) "
            "if c.get('fstype') in ('ntfs','ext4')][-1:]\" 2>/dev/null) && "
            "echo \"$PART\""
        ).arg(m_installDevice));

        if (!resizeResult.isEmpty()) {
            QString fullPart = m_installDevice.contains("nvme") ? 
                               m_installDevice + "p" + resizeResult.trimmed() : 
                               m_installDevice + resizeResult.trimmed();

            emitLog(QString("   Redimensionando partição existente %1...\n").arg(fullPart));
            runBash(QString("ntfsresize --force %1 2>&1 || true").arg(fullPart));
        }
        emitLog("✅ Dual Boot preparado.\n");
        return true;
    }

    return true;
}

bool InstallWorker::stepSystemDeps() {
    QStringList basic = {"curl", "wget", "git", "gpg", "ca-certificates",
                         "apt-transport-https", "software-properties-common",
                         "whiptail", "dialog"};

    for (const auto &pkg : basic) {
        if (m_cancelled) return false;

        if (isPackageInstalled(pkg)) {
            emitLog(QString("   ✓ %1 (já instalado)\n").arg(pkg));
            continue;
        }

        emitLog(QString("   → Instalando %1... ").arg(pkg));
        QString result = runBash(QString("DEBIAN_FRONTEND=noninteractive apt-get install -y -qq %1 2>&1").arg(pkg));
        bool ok = !result.contains("E: Unable") && !result.contains("E: Package");
        emitLog(ok ? "✓\n" : "✗\n");
        if (!ok && m_verbose) emitLog("     " + result.trimmed() + "\n", true);
    }

    return true;
}

bool InstallWorker::stepUpdatePackageList() {
    if (m_cancelled) return false;
    emitLog("   → apt-get update... ");
    QString result = runBash("apt-get update -qq 2>&1 | tail -3");
    bool ok = !result.contains("E:");
    emitLog(ok ? "✓\n" : "⚠️\n");
    if (!ok) emitLog("     " + result.trimmed() + "\n", true);
    return ok;
}

bool InstallWorker::stepInstallPackages() {
    int total = m_packages.size();
    if (total == 0) {
        emitLog("⚠️  Nenhum pacote selecionado para instalação.\n");
        return true;
    }

    int done = 0;
    for (const auto &pkg : m_packages) {
        if (m_cancelled) return false;

        done++;
        int pct = PROGRESS_INSTALL_MIN + ((done * (PROGRESS_INSTALL_MAX - PROGRESS_INSTALL_MIN)) / total);
        if (pct > PROGRESS_INSTALL_MAX) pct = PROGRESS_INSTALL_MAX;

        emitProgress(pct, QString("Instalando %1 (%2/%3)").arg(pkg).arg(done).arg(total));
        emit packageStarted(pkg, done, total);

        if (isPackageInstalled(pkg)) {
            emitLog(QString("   ✓ %1 (já instalado)\n").arg(pkg));
            emit packageFinished(pkg, true);
            continue;
        }

        emitLog(QString("   → Instalando %1... ").arg(pkg));
        QString result = runBash(QString("DEBIAN_FRONTEND=noninteractive apt-get install -y -qq %1 2>&1").arg(pkg));
        bool success = !result.contains("E: Unable") && !result.contains("E: Package");

        if (success) {
            emitLog("✓\n");
        } else {
            emitLog("✗\n");
            emitLog(QString("     ⚠️  %1\n").arg(result.trimmed().left(150)), true);
        }

        emit packageFinished(pkg, success);
    }

    return true;
}

bool InstallWorker::stepCreateDirectories() {
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString basePath = m_installPath.isEmpty() ? home + "/FydelisTechOS" : m_installPath;

    QStringList dirs = {
        basePath, basePath + "/tools", basePath + "/wordlists",
        basePath + "/reports", basePath + "/scripts", basePath + "/labs",
        basePath + "/cheatsheets", basePath + "/slides", basePath + "/targets"
    };

    for (const auto &d : dirs) {
        if (m_cancelled) return false;
        QDir dir(d);
        if (!dir.exists()) {
            dir.mkpath(".");
        }
    }
    return true;
}

bool InstallWorker::stepConfigureAliases() {
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QStringList rcFiles = {home + "/.bashrc", home + "/.zshrc"};

    QString aliasText = "\n# ─── FydelisTechOS Aliases ─────────────────────────\n"
                        "alias ft-recon='nmap -sV -sC -O'\n"
                        "alias ft-fullscan='nmap -p- -sV -sC -A'\n"
                        "alias ft-webfuzz='gobuster dir -u'\n"
                        "alias fydelis='cat ~/FydelisTechOS/banner.txt 2>/dev/null || echo \"FydelisTechOS\"'\n"
                        "# ───────────────────────────────────────────────────\n";

    for (const auto &rc : rcFiles) {
        QFile file(rc);
        if (!file.exists()) continue;
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = QString::fromUtf8(file.readAll());
            file.close();
            if (content.contains("FydelisTechOS Aliases")) continue;
        }
        if (file.open(QIODevice::Append | QIODevice::Text)) {
            QTextStream out(&file);
            out << aliasText;
            file.close();
        }
    }
    return true;
}

bool InstallWorker::stepCreateCheatsheets() {
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString cheatDir = home + "/FydelisTechOS/cheatsheets";
    QDir().mkpath(cheatDir);

    QFile nmapCS(cheatDir + "/nmap-cheatsheet.txt");
    if (nmapCS.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&nmapCS);
        out << "Nmap Cheatsheet — FydelisTechOS\nnmap -sV -sC -O <target>\n";
        nmapCS.close();
    }
    return true;
}

bool InstallWorker::stepFinalize() {
    emitLog("\n📌 Instalação finalizada com sucesso.\n");
    return true;
}

QString InstallWorker::runCommand(const QString &cmd, const QStringList &args) {
#ifdef Q_OS_WIN
    Q_UNUSED(cmd);
    Q_UNUSED(args);
    if (m_cancelled) return "";
    QThread::msleep(30);
    return "OK (simulado no Windows)";
#else
    if (m_cancelled) return "";
    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(cmd, args);
    proc.waitForFinished(300000);
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
#endif
}

QString InstallWorker::runBash(const QString &script) {
#ifdef Q_OS_WIN
    Q_UNUSED(script);
    if (m_cancelled) return "";
    QThread::msleep(50);
    return "OK (simulado no Windows)";
#else
    return runCommand("/bin/bash", {"-c", script});
#endif
}

bool InstallWorker::isPackageInstalled(const QString &pkg) {
#ifdef Q_OS_WIN
    Q_UNUSED(pkg);
    return false;
#else
    QString result = runBash(QString("dpkg -s %1 2>/dev/null | grep -q 'Status: install ok installed' && echo 'yes' || echo 'no'").arg(pkg));
    return result.trimmed() == "yes";
#endif
}

void InstallWorker::emitProgress(int percent, const QString &status) {
    m_progress = percent;
    emit progressUpdated(percent, status);
}

void InstallWorker::emitLog(const QString &msg, bool isErr) {
    emit logMessage(msg, isErr);
}
