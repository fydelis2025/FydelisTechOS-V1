#ifndef PARTITIONMANAGER_H
#define PARTITIONMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QList>
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

// ─── Estrutura de uma partição ──────────────────────────────────────────────
struct PartitionInfo {
    QString device;        // Ex: /dev/sda1
    QString parentDisk;    // Ex: /dev/sda
    QString label;         // Rótulo da partição
    QString fstype;        // ext4, ntfs, vfat, swap, etc
    QString mountpoint;    // Onde está montada (se montada)
    QString uuid;
    QString osName;        // Nome do SO detectado (ex: "Windows 11", "Ubuntu 22.04")
    qint64 sizeBytes;
    qint64 usedBytes;
    qint64 freeBytes;
    int number;            // Número da partição
    bool isBoot;
    bool isRoot;
    bool isEFI;
    bool isSwap;
    bool isLogical;
    bool isMounted;

    QString sizeHuman() const;
    QString usedHuman() const;
    QString freeHuman() const;
    int usagePercent() const;
};

// ─── Estrutura de um disco ──────────────────────────────────────────────────
struct DiskInfo {
    QString device;        // Ex: /dev/sda
    QString model;         // Modelo do disco
    QString transport;     // sata, nvme, virtio
    qint64 sizeBytes;
    int sectorSize;
    QString partitionTable; // gpt, mbr/dos
    bool isRemovable;
    bool isSSD;
    QList<PartitionInfo> partitions;

    QString sizeHuman() const;
    QString description() const;
};

// ─── Ação de particionamento ────────────────────────────────────────────────
struct PartitionAction {
    enum Type {
        None,
        Resize,        // Redimensionar partição existente
        Create,        // Criar nova partição
        Delete,        // Excluir partição
        Format,        // Format partição
        InstallAlongside  // Dual boot - redimensionar automático
    };

    Type type = None;
    QString targetDevice;    // Disco alvo
    QString partitionDevice; // Partição alvo (para resize/format/delete)
    qint64 newSizeBytes = 0; // Novo tamanho (para resize/create)
    qint64 startSector = 0;
    qint64 endSector = 0;
    QString newFstype = "ext4";
    QString newMountpoint = "/";
    bool createEFI = false;

    QString description() const {
        switch (type) {
            case Resize: return "Redimensionar " + partitionDevice;
            case Create: return "Criar partição em " + targetDevice;
            case Delete: return "Excluir " + partitionDevice;
            case Format: return "Formatar " + partitionDevice + " como " + newFstype;
            case InstallAlongside: return "Instalar junto (dual boot) em " + targetDevice;
            default: return "Nenhuma ação";
        }
    }
};

// ─── Resultado de detecção de dual boot ─────────────────────────────────────
struct DualBootOption {
    QString diskDevice;
    QString existingOS;
    QString existingPartition;
    qint64 totalDiskSize;
    qint64 usedOnExisting;
    qint64 freeForNew;
    qint64 suggestedNewSize;  // Sugestão: metade do espaço livre disponível
    bool viable;              // Se há espaço suficiente para dual boot
};

// ═══════════════════════════════════════════════════════════════════════════
// PartitionManager — Detecta, analisa e opera partições do sistema
// ═══════════════════════════════════════════════════════════════════════════
class PartitionManager : public QObject {
    Q_OBJECT

public:
    explicit PartitionManager(QObject *parent = nullptr);

    // ─── Detecção ───────────────────────────────────────────────────
    QList<DiskInfo> detectDisks();
    DiskInfo getDiskInfo(const QString &device);
    QList<DualBootOption> detectDualBootOptions();

    // ─── Informação ─────────────────────────────────────────────────
    static bool isEFIBoot();
    static QString systemArchitecture();
    static qint64 requiredSpace();        // Espaço mínimo para instalação
    static qint64 recommendedSpace();     // Espaço recomendado

    // ─── Ações (simuladas / reais) ──────────────────────────────────
    bool executeAction(const PartitionAction &action, bool dryRun = true);
    bool applyChanges(const QList<PartitionAction> &actions, bool dryRun = true);
    bool rollback(const QList<PartitionAction> &actions);

    // ─── Utilitários ────────────────────────────────────────────────
    static QString runCommand(const QString &cmd);
    static QString runBash(const QString &script);
    static QString sizeHuman(qint64 bytes);
    static qint64 parseSize(const QString &human);

signals:
    void progressChanged(int percent, const QString &status);
    void errorOcurred(const QString &message);
    void actionCompleted(const QString &description, bool success);

private:
    PartitionInfo parsePartition(const QString &device);
    QString detectOSOnPartition(const QString &device, const QString &fstype);
};

#endif // PARTITIONMANAGER_H