#include "partitionmanager.h"
#include <QRegularExpression>
#include <QStorageInfo>
#include <QDir>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <cmath>

PartitionManager::PartitionManager(QObject *parent) : QObject(parent) {}

// ─── Utilitários estáticos ──────────────────────────────────────────────────

QString PartitionManager::runCommand(const QString &cmd) {
    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start("/bin/bash", {"-c", cmd});
    proc.waitForFinished(30000);
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
}

QString PartitionManager::runBash(const QString &script) {
    return runCommand(script);
}

QString PartitionManager::sizeHuman(qint64 bytes) {
    if (bytes < 0) return "0 B";
    const char *units[] = {"B", "KB", "MB", "GB", "TB"};
    int unit = 0;
    double size = bytes;
    while (size >= 1024 && unit < 4) {
        size /= 1024;
        unit++;
    }
    return QString::number(size, 'f', (unit == 0) ? 0 : 1) + " " + units[unit];
}

qint64 PartitionManager::parseSize(const QString &human) {
    QRegularExpression re(R"(([\d.]+)\s*([KMGT]?B))", QRegularExpression::CaseInsensitiveOption);
    auto match = re.match(human.trimmed());
    if (!match.hasMatch()) return 0;

    double value = match.captured(1).toDouble();
    QString unit = match.captured(2).toUpper();

    if (unit == "KB") return static_cast<qint64>(value * 1024);
    if (unit == "MB") return static_cast<qint64>(value * 1024 * 1024);
    if (unit == "GB") return static_cast<qint64>(value * 1024 * 1024 * 1024);
    if (unit == "TB") return static_cast<qint64>(value * 1024LL * 1024 * 1024 * 1024);
    return static_cast<qint64>(value); // B
}

bool PartitionManager::isEFIBoot() {
    return QDir("/sys/firmware/efi").exists();
}

QString PartitionManager::systemArchitecture() {
    return runCommand("uname -m");
}

qint64 PartitionManager::requiredSpace() {
    return 8LL * 1024 * 1024 * 1024; // 8 GB mínimo
}

qint64 PartitionManager::recommendedSpace() {
    return 25LL * 1024 * 1024 * 1024; // 25 GB recomendado
}

// ─── Detecção de Discos ─────────────────────────────────────────────────────

QList<DiskInfo> PartitionManager::detectDisks() {
#ifdef Q_OS_WIN
    // ─── No Windows, retorna dados simulados para teste visual ────
    QList<DiskInfo> disks;

    // Disco 1: SSD com Windows + dados
    DiskInfo disk1;
    disk1.device = "\\\\.\\PHYSICALDRIVE0";
    disk1.model = "NVMe Samsung SSD 980 PRO 1TB";
    disk1.transport = "NVMe";
    disk1.sizeBytes = 1000LL * 1024 * 1024 * 1024; // 1TB
    disk1.isSSD = true;
    disk1.partitionTable = "GPT";
    disk1.isRemovable = false;

    PartitionInfo efi;
    efi.device = "\\\\.\\PHYSICALDRIVE0p1";
    efi.parentDisk = disk1.device;
    efi.sizeBytes = 512LL * 1024 * 1024;
    efi.fstype = "vfat";
    efi.label = "ESP";
    efi.mountpoint = "";
    efi.isEFI = true;
    efi.isMounted = false;
    efi.osName = "EFI System";
    disk1.partitions.append(efi);

    PartitionInfo win;
    win.device = "\\\\.\\PHYSICALDRIVE0p2";
    win.parentDisk = disk1.device;
    win.sizeBytes = 500LL * 1024 * 1024 * 1024;
    win.fstype = "ntfs";
    win.label = "Windows";
    win.mountpoint = "C:\\";
    win.isMounted = true;
    win.isRoot = true;
    win.osName = "Windows 11";
    disk1.partitions.append(win);

    PartitionInfo dados;
    dados.device = "\\\\.\\PHYSICALDRIVE0p3";
    dados.parentDisk = disk1.device;
    dados.sizeBytes = 400LL * 1024 * 1024 * 1024;
    dados.fstype = "ntfs";
    dados.label = "DADOS";
    dados.mountpoint = "D:\\";
    dados.isMounted = true;
    dados.osName = "";
    disk1.partitions.append(dados);

    disks.append(disk1);

    // Disco 2: HD externo vazio
    DiskInfo disk2;
    disk2.device = "\\\\.\\PHYSICALDRIVE1";
    disk2.model = "USB External Drive 2TB";
    disk2.transport = "USB";
    disk2.sizeBytes = 2000LL * 1024 * 1024 * 1024;
    disk2.isSSD = false;
    disk2.partitionTable = "MBR";
    disk2.isRemovable = true;
    disks.append(disk2);

    return disks;
#else
    QList<DiskInfo> disks;

    // Usa lsblk com JSON para obter informações estruturadas
    QString output = runCommand("lsblk -J -o NAME,SIZE,TYPE,MODEL,TRAN,ROTA,PTTYPE,RM 2>/dev/null");
    QJsonDocument doc = QJsonDocument::fromJson(output.toUtf8());

    if (doc.isNull()) {
        // Fallback: parsing manual
        QString lsblkOut = runCommand("lsblk -d -o NAME,SIZE,TYPE,MODEL,TRAN,ROTA,PTTYPE 2>/dev/null | tail -n +2");
        QStringList lines = lsblkOut.split('\n', Qt::SkipEmptyParts);

        for (const auto &line : lines) {
            QStringList parts = line.simplified().split(' ');
            if (parts.size() < 3) continue;

            DiskInfo disk;
            disk.device = "/dev/" + parts[0];
            disk.sizeBytes = parseSize(parts[1]);
            disk.model = parts.size() > 3 ? parts[3] : "Desconhecido";
            disk.transport = parts.size() > 4 ? parts[4] : "unknown";
            disk.isSSD = parts.size() > 5 ? parts[5] == "0" : false;
            disk.partitionTable = parts.size() > 6 ? parts[6] : "unknown";
            disk.isRemovable = false;

            // Pega partições deste disco
            QString partOut = runCommand(QString("lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT /dev/%1 2>/dev/null | tail -n +2 | grep -v '^%1 '").arg(parts[0]));
            QStringList partLines = partOut.split('\n', Qt::SkipEmptyParts);
            for (const auto &pl : partLines) {
                QStringList p = pl.simplified().split(' ');
                if (p.size() < 1) continue;
                PartitionInfo pi;
                pi.device = "/dev/" + p[0];
                pi.parentDisk = disk.device;
                pi.sizeBytes = p.size() > 1 ? parseSize(p[1]) : 0;
                pi.fstype = p.size() > 2 ? p[2] : "";
                pi.label = p.size() > 3 ? p[3] : "";
                pi.mountpoint = p.size() > 4 ? p[4] : "";
                pi.isMounted = !pi.mountpoint.isEmpty();
                pi.number = QRegularExpression("\\d+$").match(p[0]).captured().toInt();
                pi.isEFI = pi.fstype == "vfat" && pi.mountpoint.contains("efi");
                pi.isSwap = pi.fstype == "swap";
                pi.isBoot = pi.mountpoint == "/boot" || pi.mountpoint == "/boot/efi";
                pi.isRoot = pi.mountpoint == "/";

                if (!pi.fstype.isEmpty() && pi.fstype != "swap") {
                    pi.osName = detectOSOnPartition(pi.device, pi.fstype);
                }

                disk.partitions.append(pi);
            }

            disks.append(disk);
        }
        return disks;
    }

    // Parsing JSON do lsblk
    QJsonArray blockdevices = doc.object()["blockdevices"].toArray();
    for (const auto &bd : blockdevices) {
        QJsonObject diskObj = bd.toObject();
        QString type = diskObj["type"].toString();
        if (type != "disk") continue;

        DiskInfo disk;
        disk.device = "/dev/" + diskObj["name"].toString();
        disk.sizeBytes = parseSize(diskObj["size"].toString());
        disk.model = diskObj["model"].toString("Desconhecido");
        disk.transport = diskObj["tran"].toString("unknown");
        disk.isSSD = !diskObj["rota"].toBool(); // 0 = SSD, 1 = HDD
        disk.partitionTable = diskObj["pttype"].toString("unknown");
        disk.isRemovable = diskObj["rm"].toBool();

        // Partições
        QJsonArray children = diskObj["children"].toArray();
        for (const auto &child : children) {
            QJsonObject partObj = child.toObject();
            if (partObj["type"].toString() != "part") continue;

            PartitionInfo pi;
            pi.device = "/dev/" + partObj["name"].toString();
            pi.parentDisk = disk.device;
            pi.sizeBytes = parseSize(partObj["size"].toString());
            pi.fstype = partObj["fstype"].toString();
            pi.label = partObj["label"].toString();
            pi.mountpoint = partObj["mountpoint"].toString();
            pi.isMounted = !pi.mountpoint.isEmpty();
            pi.number = QRegularExpression("\\d+$").match(partObj["name"].toString()).captured().toInt();
            pi.isEFI = pi.fstype == "vfat" && pi.mountpoint.contains("efi");
            pi.isSwap = pi.fstype == "swap";
            pi.isRoot = pi.mountpoint == "/";

            // UUID
            QString blkidOut = runCommand(QString("blkid -o value -s UUID %1 2>/dev/null").arg(pi.device));
            pi.uuid = blkidOut.trimmed();

            // Detectar SO
            if (!pi.fstype.isEmpty() && pi.fstype != "swap" && !pi.isEFI) {
                pi.osName = detectOSOnPartition(pi.device, pi.fstype);
            }

            disk.partitions.append(pi);
        }

        disks.append(disk);
    }

    return disks;
#endif
}

DiskInfo PartitionManager::getDiskInfo(const QString &device) {
    auto disks = detectDisks();
    for (const auto &d : disks) {
        if (d.device == device) return d;
    }
    return DiskInfo();
}

// ─── Detecção de SO em partição ─────────────────────────────────────────────

QString PartitionManager::detectOSOnPartition(const QString &device, const QString &fstype) {
    QString mountPoint = "/tmp/fydelis-osdetect-" + device.mid(5).replace('/', '_');
    bool wasMounted = QDir(mountPoint).exists();

    if (!wasMounted) {
        QDir().mkpath(mountPoint);
        runCommand(QString("mount -t %1 %2 %3 2>/dev/null").arg(fstype, device, mountPoint));
    }

    if (QFile::exists(mountPoint + "/Windows/System32/winver.exe")) {
        QString winVer = runCommand(QString("strings %1/Windows/System32/winver.exe 2>/dev/null | grep -E '10\\.0\\.\\d+' | head -1").arg(mountPoint));
        if (winVer.contains("10.0.22000") || winVer.contains("10.0.22621") || winVer.contains("10.0.26100"))
            return "Windows 11";
        if (winVer.contains("10.0.19041") || winVer.contains("10.0.19042") || winVer.contains("10.0.19043") || winVer.contains("10.0.19044") || winVer.contains("10.0.19045"))
            return "Windows 10";
        if (winVer.contains("10.0.")) return "Windows 10/11";

        if (QFile::exists(mountPoint + "/bootmgr")) return "Windows";
        return "Windows (desconhecido)";
    }

    if (QFile::exists(mountPoint + "/etc/os-release")) {
        QFile osRelease(mountPoint + "/etc/os-release");
        if (osRelease.open(QIODevice::ReadOnly)) {
            QString content = QString::fromUtf8(osRelease.readAll());
            osRelease.close();

            QRegularExpression nameRx("^PRETTY_NAME=\"(.+)\"", QRegularExpression::MultilineOption);
            auto match = nameRx.match(content);
            if (match.hasMatch()) return match.captured(1);

            QRegularExpression idRx("^ID=(.+)$", QRegularExpression::MultilineOption);
            match = idRx.match(content);
            if (match.hasMatch()) return match.captured(1).trimmed();
        }
        return "Linux";
    }

    if (QFile::exists(mountPoint + "/etc/arch-release")) return "Arch Linux";
    if (QFile::exists(mountPoint + "/etc/fedora-release")) return "Fedora Linux";
    if (QFile::exists(mountPoint + "/etc/debian_version")) {
        QString ver = runCommand(QString("cat %1/etc/debian_version 2>/dev/null").arg(mountPoint)).trimmed();
        return "Debian " + ver;
    }

    if (!wasMounted) {
        runCommand(QString("umount %1 2>/dev/null").arg(mountPoint));
        QDir().rmdir(mountPoint);
    }

    return "";
}

// ─── Detecção de Dual Boot ──────────────────────────────────────────────────

QList<DualBootOption> PartitionManager::detectDualBootOptions() {
#ifdef Q_OS_WIN
    QList<DualBootOption> options;
    DualBootOption opt;
    opt.diskDevice = "\\\\.\\PHYSICALDRIVE0";
    opt.existingOS = "Windows 11";
    opt.existingPartition = "\\\\.\\PHYSICALDRIVE0p2";
    opt.totalDiskSize = 1000LL * 1024 * 1024 * 1024;
    opt.usedOnExisting = 350LL * 1024 * 1024 * 1024;
    opt.freeForNew = 500LL * 1024 * 1024 * 1024;
    opt.suggestedNewSize = 100LL * 1024 * 1024 * 1024;
    opt.viable = true;
    options.append(opt);
    return options;
#else
    QList<DualBootOption> options;
    auto disks = detectDisks();

    for (const auto &disk : disks) {
        DualBootOption opt;
        opt.diskDevice = disk.device;
        opt.totalDiskSize = disk.sizeBytes;

        qint64 totalUsed = 0;
        QStringList existingOS;

        for (const auto &part : disk.partitions) {
            if (!part.osName.isEmpty() && !part.isEFI && !part.isSwap) {
                existingOS << part.osName;
                opt.existingOS = part.osName;
                opt.existingPartition = part.device;
                if (part.isMounted) {
                    QStorageInfo si(part.mountpoint);
                    opt.usedOnExisting += si.bytesTotal() - si.bytesFree();
                } else {
                    opt.usedOnExisting += part.sizeBytes * 0.7;
                }
                totalUsed += part.sizeBytes;
            }
        }

        opt.freeForNew = disk.sizeBytes - totalUsed;
        opt.suggestedNewSize = qMax(opt.freeForNew / 2, requiredSpace());
        opt.viable = opt.freeForNew >= requiredSpace() && !existingOS.isEmpty();

        if (opt.viable || !existingOS.isEmpty()) {
            options.append(opt);
        }
    }
    return options;
#endif
}

// ─── Ações de particionamento ───────────────────────────────────────────────

bool PartitionManager::executeAction(const PartitionAction &action, bool dryRun) {
    emit progressChanged(0, "Preparando: " + action.description());

    if (dryRun) {
        qDebug() << "[DRY-RUN]" << action.description();
        emit actionCompleted(action.description(), true);
        return true;
    }

    QString cmd;

    switch (action.type) {
    case PartitionAction::Resize: {
        qint64 endBytes = action.newSizeBytes;
        if (endBytes <= 0) return false;

        runCommand(QString("umount %1 2>/dev/null").arg(action.partitionDevice));

        cmd = QString("e2fsck -f -y %1 2>/dev/null && "
                      "resize2fs %1 %2 2>/dev/null && "
                      "parted %3 resizepart %4 %5 2>/dev/null")
                  .arg(action.partitionDevice)
                  .arg(sizeHuman(action.newSizeBytes))
                  .arg(action.targetDevice)
                  .arg(QRegularExpression("\\d+$").match(action.partitionDevice).captured())
                  .arg(sizeHuman(action.newSizeBytes));
        break;
    }
    case PartitionAction::Create: {
        cmd = QString("parted %1 mkpart primary ext4 %2 %3 2>/dev/null")
                  .arg(action.targetDevice)
                  .arg(sizeHuman(action.startSector))
                  .arg(sizeHuman(action.endSector));
        break;
    }
    case PartitionAction::Delete: {
        cmd = QString("parted %1 rm %2 2>/dev/null")
                  .arg(action.targetDevice)
                  .arg(QRegularExpression("\\d+$").match(action.partitionDevice).captured());
        break;
    }
    case PartitionAction::Format: {
        cmd = QString("mkfs.%1 -F %2 2>/dev/null").arg(action.newFstype, action.partitionDevice);
        break;
    }
    case PartitionAction::InstallAlongside: {
        cmd = QString("echo 'Dual boot automático em %1'").arg(action.targetDevice);
        break;
    }
    default:
        return false;
    }

    if (!cmd.isEmpty()) {
        QString result = runCommand(cmd);
        bool success = !result.contains("Error") && !result.contains("failed");
        emit actionCompleted(action.description(), success);
        emit progressChanged(100, success ? "✓ Completo" : "✗ Falhou");
        return success;
    }

    return true;
}

bool PartitionManager::applyChanges(const QList<PartitionAction> &actions, bool dryRun) {
    int total = actions.size();
    for (int i = 0; i < total; ++i) {
        int pct = (i * 100) / total;
        emit progressChanged(pct, QString("Aplicando: %1/%2").arg(i+1).arg(total));

        if (!executeAction(actions[i], dryRun)) {
            emit errorOcurred("Falha na ação: " + actions[i].description());
            return false;
        }
    }
    emit progressChanged(100, "Todas as ações aplicadas");
    return true;
}

bool PartitionManager::rollback(const QList<PartitionAction> &actions) {
    Q_UNUSED(actions);
    emit progressChanged(0, "Rollback não implementado completamente");
    return false;
}

// ─── Métodos de formatação ──────────────────────────────────────────────────

QString PartitionInfo::sizeHuman() const { return PartitionManager::sizeHuman(sizeBytes); }
QString PartitionInfo::usedHuman() const { return PartitionManager::sizeHuman(usedBytes); }
QString PartitionInfo::freeHuman() const { return PartitionManager::sizeHuman(freeBytes); }
int PartitionInfo::usagePercent() const {
    if (sizeBytes == 0) return 0;
    return static_cast<int>((usedBytes * 100) / sizeBytes);
}

QString DiskInfo::sizeHuman() const { return PartitionManager::sizeHuman(sizeBytes); }

QString DiskInfo::description() const {
    QString desc = device + " — " + model;
    desc += " (" + sizeHuman() + ")";
    desc += isSSD ? " [SSD]" : " [HDD]";
    desc += " — " + partitionTable.toUpper();
    return desc;
}