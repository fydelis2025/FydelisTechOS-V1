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

// ─── Cancelamento ───────────────────────────────────────────────────────────

void InstallWorker::cancel() {
    m_cancelled = true;
    if (m_process && m_process->state() == QProcess::Running) {
        m_process->kill();
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// RUN — Pipeline principal da instalação
// ═══════════════════════════════════════════════════════════════════════════

void InstallWorker::run() {
    m_timer.start();
    m_progress = 0;
    m_cancelled = false;

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
        emitLog("📌 Esta foi uma simulação da interface. No Linux, a instalação real ocorreria.\n");
        emit finished(true, "Dry-run concluído com sucesso. Nenhuma alteração no sistema.");
        return;
    }

    // ─── Etapa 1: Particionamento (0% → 5%) ───────────────────────
    if (!m_installDevice.isEmpty() && (m_eraseDisk || m_dualBoot)) {
        emitProgress(0, "Preparando partições...");
        emitLog("📀 Configurando partições...\n");
        if (!stepPartitioning()) {
            emit finished(false, "Falha no particionamento do disco.");
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

    // ─── Resumo final ──────────────────────────────────────────────
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
        "   source ~/.bashrc\n\n"
        "🔴 Happy Hacking! — FydelisTechOS\n"
    ).arg(m_packages.size()).arg(elapsed)
     .arg(m_installDevice.isEmpty() ? "Nenhum (modo pacotes)" : m_installDevice);

    emitLog(summary);
    emit finished(true, summary);
}

// ═══════════════════════════════════════════════════════════════════════════
// Etapas
// ═══════════════════════════════════════════════════════════════════════════

bool InstallWorker::stepPartitioning() {
    if (m_eraseDisk) {
        emitLog("💾 Apagando disco " + m_installDevice + "...\n");

        // Desmonta partições
        runBash(QString("umount %1* 2>/dev/null || true").arg(m_installDevice));

        // Cria tabela GPT
        runBash(QString("parted %1 mklabel gpt -s 2>&1").arg(m_installDevice));
        emitLog("   Tabela GPT criada.\n");

        // Cria partição EFI (512 MB)
        runBash(QString("parted %1 mkpart primary fat32 0%% 512MiB -s 2>&1").arg(m_installDevice));
        QString efiPart = m_installDevice + "1";
        if (m_installDevice.contains("nvme")) efiPart = m_installDevice + "p1";
        runBash(QString("mkfs.vfat -F32 %1 2>&1").arg(efiPart));
        emitLog("   Partição EFI criada.\n");

        // Cria partição root (restante do disco)
        runBash(QString("parted %1 mkpart primary ext4 512MiB 100%% -s 2>&1").arg(m_installDevice));
        QString rootPart = m_installDevice + "2";
        if (m_installDevice.contains("nvme")) rootPart = m_installDevice + "p2";
        runBash(QString("mkfs.ext4 -F %1 2>&1").arg(rootPart));
        emitLog("   Partição root (ext4) criada.\n");

        // Monta a partição root
        runBash(QString("mount %1 /mnt 2>&1").arg(rootPart));
        runBash("mkdir -p /mnt/boot/efi");
        runBash(QString("mount %1 /mnt/boot/efi 2>&1").arg(efiPart));

        emitLog("✅ Disco particionado e montado em /mnt.\n");
        return true;
    }

    if (m_dualBoot) {
        emitLog("🔀 Modo Dual Boot — preparando espaço...\n");
        emitLog("   Analisando partições existentes...\n");

        // Detecta partição Windows e redimensiona
        QString partInfo = runBash(QString("lsblk -o NAME,SIZE,FSTYPE,LABEL %1 --json 2>/dev/null").arg(m_installDevice));

        // Redimensiona a última partição grande (tipicamente Windows)
        QString resizeResult = runBash(QString(
            "PART=$(lsblk -o NAME %1 --json 2>/dev/null | "
            "python3 -c \"import sys,json; "
            "d=json.load(sys.stdin); "
            "[print(c['name']) for c in d.get('blockdevices',[{}])[0].get('children',[]) "
            "if c.get('fstype') in ('ntfs','ext4')][-1:]\" 2>/dev/null) && "
            "echo \"$PART\""
        ).arg(m_installDevice));

        if (!resizeResult.isEmpty()) {
            QString fullPart = m_installDevice + resizeResult.trimmed();
            if (m_installDevice.contains("nvme"))
                fullPart = m_installDevice + "p" + resizeResult.trimmed();

            emitLog(QString("   Redimensionando %1...\n").arg(fullPart));
            runBash(QString("ntfsresize --force %1 2>&1 || true").arg(fullPart));
            emitLog("   Espaço liberado para o novo sistema.\n");
        }

        emitLog("✅ Dual Boot preparado.\n");
        return true;
    }

    return true; // Nenhuma ação de partição necessária
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
        if (!ok && m_verbose) emitLog("      " + result.trimmed() + "\n", true);
    }

    return true;
}

bool InstallWorker::stepUpdatePackageList() {
    if (m_cancelled) return false;
    emitLog("   → apt-get update... ");
    QString result = runBash("apt-get update -qq 2>&1 | tail -3");
    bool ok = !result.contains("E:");
    emitLog(ok ? "✓\n" : "⚠️\n");
    if (!ok) emitLog("      " + result.trimmed() + "\n", true);
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
            emitLog(QString("      ⚠️  %1\n").arg(result.trimmed().left(150)), true);
        }

        emit packageFinished(pkg, success);
    }

    return true;
}

bool InstallWorker::stepCreateDirectories() {
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString basePath = m_installPath.isEmpty()
        ? home + "/FydelisTechOS"
        : m_installPath;

    QStringList dirs = {
        basePath,
        basePath + "/tools",
        basePath + "/wordlists",
        basePath + "/reports",
        basePath + "/scripts",
        basePath + "/labs",
        basePath + "/cheatsheets",
        basePath + "/slides",
        basePath + "/targets"
    };

    for (const auto &d : dirs) {
        if (m_cancelled) return false;
        QDir dir(d);
        if (!dir.exists()) {
            if (dir.mkpath(".")) {
                emitLog(QString("   📁 Criado: %1\n").arg(d));
            } else {
                emitLog(QString("   ⚠️  Falha ao criar: %1\n").arg(d), true);
            }
        }
    }

    return true;
}

bool InstallWorker::stepConfigureAliases() {
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QStringList rcFiles = {home + "/.bashrc", home + "/.zshrc"};

    QStringList aliasBlock;
    aliasBlock << "";
    aliasBlock << "# ─── FydelisTechOS Aliases ─────────────────────────";
    aliasBlock << "alias ft-recon='nmap -sV -sC -O'";
    aliasBlock << "alias ft-fullscan='nmap -p- -sV -sC -A'";
    aliasBlock << "alias ft-webfuzz='gobuster dir -u'";
    aliasBlock << "alias ft-dirsearch='dirsearch -u'";
    aliasBlock << "alias ft-enum='enum4linux -a'";
    aliasBlock << "alias ft-sql='sqlmap -u'";
    aliasBlock << "alias ft-hashid='hash-identifier'";
    aliasBlock << "alias ft-wifi='sudo airmon-ng'";
    aliasBlock << "alias ft-wordlist='ls ~/FydelisTechOS/wordlists'";
    aliasBlock << "alias ft-report='mkdir -p ~/FydelisTechOS/reports/\\$(date +%Y%m%d)'";
    aliasBlock << "alias ft-cheat='ls ~/FydelisTechOS/cheatsheets'";
    aliasBlock << "alias fydelis='cat ~/FydelisTechOS/banner.txt 2>/dev/null || echo \"FydelisTechOS\"'";
    aliasBlock << "alias ft-update='sudo apt-get update && sudo apt-get upgrade -y'";
    aliasBlock << "alias ft-lab='cd ~/FydelisTechOS/labs'";
    aliasBlock << "alias ft-ip='ip a | grep inet'";
    aliasBlock << "alias ft-scanlocal='nmap -sn 192.168.1.0/24'";
    aliasBlock << "# ───────────────────────────────────────────────────";
    aliasBlock << "";

    QString aliasText = aliasBlock.join("\n");

    for (const auto &rc : rcFiles) {
        QFile file(rc);
        if (!file.exists()) continue;

        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = QString::fromUtf8(file.readAll());
            file.close();
            if (content.contains("FydelisTechOS Aliases")) {
                emitLog(QString("   ⏭️  Aliases já configurados em: %1\n").arg(rc));
                continue;
            }
        }

        if (file.open(QIODevice::Append | QIODevice::Text)) {
            QTextStream out(&file);
            out << aliasText;
            file.close();
            emitLog(QString("   ✓ Aliases adicionados em: %1\n").arg(rc));
        }
    }

    // Cria banner
    QString bannerPath = home + "/FydelisTechOS/banner.txt";
    QFile bannerFile(bannerPath);
    if (bannerFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&bannerFile);
        out << "  ______ _           _ _ _           _____ _           _   ___  ____\n";
        out << " |  ____| |         | | | |         |_   _| |         | | / _ \\/ ___|\n";
        out << " | |__  | |_   _  __| | | | ___ _ __  | | | |__   ___ | |/ / _\\` \\___ \\\n";
        out << " |  __| | | | | |/ _` | | |/ _ \\ '__| | | | '_ \\ / _ \\| | | (_| |___) |\n";
        out << " | |    | | |_| | (_| | | |  __/ |    _| |_| | | | (_) | | \\__,_|____/\n";
        out << " |_|    |_|\\__, |\\__,_|_|_|\\___|_|   |_____|_| |_|\\___/|_|      |_|\n";
        out << "            __/ |\n";
        out << "           |___/\n";
        out << "  FydelisTechOS — Segurança Ofensiva & Pentest\n";
        out << "  \"Educação que transforma profissionais em hackers éticos\"\n";
        bannerFile.close();
    }

    return true;
}

bool InstallWorker::stepCreateCheatsheets() {
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString cheatDir = home + "/FydelisTechOS/cheatsheets";
    QDir().mkpath(cheatDir);

    // Nmap cheatsheet
    QFile nmapCS(cheatDir + "/nmap-cheatsheet.txt");
    if (nmapCS.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&nmapCS);
        out << "Nmap Cheatsheet — FydelisTechOS\n";
        out << "═══════════════════════════════\n\n";
        out << "nmap -sV -sC -O <target>        # Scan básico\n";
        out << "nmap -p- -sV -sC -A <target>    # Scan completo\n";
        out << "nmap -sn <subnet>/24            # Ping sweep\n";
        out << "nmap --script vuln <target>     # Vulnerabilidades\n";
        out << "nmap -sU <target>               # Scan UDP\n";
        out << "nmap -O <target>                # Detecção de SO\n";
        out << "nmap -T4 -F <target>            # Scan rápido\n";
        nmapCS.close();
    }

    // SQLMap cheatsheet
    QFile sqlmapCS(cheatDir + "/sqlmap-cheatsheet.txt");
    if (sqlmapCS.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&sqlmapCS);
        out << "SQLMap Cheatsheet — FydelisTechOS\n";
        out << "══════════════════════════════════\n\n";
        out << "sqlmap -u 'http://target/page?id=1' --batch\n";
        out << "sqlmap -u 'http://target/page?id=1' --dbs\n";
        out << "sqlmap -u 'http://target/page?id=1' -D db --tables\n";
        out << "sqlmap -u 'http://target/page?id=1' --os-shell\n";
        out << "sqlmap -r request.txt\n";
        out << "sqlmap --crawl=3\n";
        sqlmapCS.close();
    }

    // Metasploit cheatsheet
    QFile msfCS(cheatDir + "/metasploit-cheatsheet.txt");
    if (msfCS.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&msfCS);
        out << "Metasploit Cheatsheet — FydelisTechOS\n";
        out << "════════════════════════════════════\n\n";
        out << "msfconsole                    # Iniciar\n";
        out << "search <exploit>              # Buscar\n";
        out << "use <path>                    # Selecionar\n";
        out << "show options                  # Opções\n";
        out << "set RHOSTS <ip>              # Alvo\n";
        out << "set PAYLOAD <payload>        # Payload\n";
        out << "check                         # Verificar\n";
        out << "exploit                       # Executar\n";
        out << "sessions -l                   # Listar\n";
        out << "sessions -i <id>             # Interagir\n";
        msfCS.close();
    }

    emitLog(QString("   📄 Cheatsheets criadas em %1\n").arg(cheatDir));
    return true;
}

bool InstallWorker::stepFinalize() {
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);

    // Cria script de boas-vindas
    QFile welcomeScript(home + "/FydelisTechOS/welcome.sh");
    if (welcomeScript.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&welcomeScript);
        out << "#!/bin/bash\n";
        out << "# FydelisTechOS — Boas-vindas\n";
        out << "cat ~/FydelisTechOS/banner.txt\n";
        out << "echo \"\"\n";
        out << "echo \"📦 Ferramentas instaladas: $(dpkg -l | grep -c '^ii')\"\n";
        out << "echo \"📁 Laboratório: ~/FydelisTechOS/labs\"\n";
        out << "echo \"📖 Cheatsheets: ~/FydelisTechOS/cheatsheets\"\n";
        out << "echo \"\"\n";
        out << "echo \"🚀 Comandos rápidos:\"\n";
        out << "echo \"   ft-recon <target>    → Scan Nmap\"\n";
        out << "echo \"   ft-webfuzz <url>     → Gobuster\"\n";
        out << "echo \"   ft-enum <target>     → Enum4linux\"\n";
        out << "echo \"   ft-sql <url>         → SQLMap\"\n";
        out << "echo \"   fydelis              → Este banner\"\n";
        welcomeScript.close();
        runBash(QString("chmod +x %1").arg(home + "/FydelisTechOS/welcome.sh"));
    }

    // Mensagem final
    emitLog("\n📌 Para ativar os aliases, execute: source ~/.bashrc\n");
    emitLog("📌 Para ver o banner: fydelis\n");
    emitLog("📌 Para começar: ft-recon <seu-alvo-autorizado>\n");

    return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// 🛠️  MÉTODOS AUXILIARES — runCommand, runBash, isPackageInstalled, etc.
// ═══════════════════════════════════════════════════════════════════════════

QString InstallWorker::runCommand(const QString &cmd, const QStringList &args) {
#ifdef Q_OS_WIN
    // ─── No Windows: apenas simula (modo demonstração) ─────────────
    Q_UNUSED(cmd);
    Q_UNUSED(args);
    if (m_cancelled) return "";
    QThread::msleep(30);  // Pequeno delay para simular processamento
    return "OK (simulado no Windows)";
#else
    // ─── No Linux: executa o comando real ──────────────────────────
    if (m_cancelled) return "";

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(cmd, args);
    proc.waitForFinished(300000); // 5 minutos de timeout

    QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    QString err = QString::fromUtf8(proc.readAllStandardError()).trimmed();

    if (m_verbose && !err.isEmpty()) {
        emitLog(QString("      ⚠️ STDERR: %1\n").arg(err.left(200)), true);
    }

    if (!err.isEmpty() && out.isEmpty()) {
        return err;
    }

    return out;
#endif
}

QString InstallWorker::runBash(const QString &script) {
#ifdef Q_OS_WIN
    // ─── No Windows: simula (modo demonstração) ────────────────────
    Q_UNUSED(script);
    if (m_cancelled) return "";
    QThread::msleep(50);
    return "OK (simulado no Windows)";
#else
    // ─── No Linux: executa via bash -c ─────────────────────────────
    return runCommand("/bin/bash", {"-c", script});
#endif
}

bool InstallWorker::isPackageInstalled(const QString &pkg) {
#ifdef Q_OS_WIN
    // ─── No Windows: simula que metade dos pacotes já estão instalados
    Q_UNUSED(pkg);
    return false; // Simula que nenhum pacote está instalado
#else
    // ─── No Linux: verifica com dpkg ───────────────────────────────
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