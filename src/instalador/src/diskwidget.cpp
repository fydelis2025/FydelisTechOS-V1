#include "diskwidget.h"
#include <QFontMetrics>
#include <QLinearGradient>
#include <cmath>

DiskWidget::DiskWidget(QWidget *parent)
    : QWidget(parent)
    , m_hoveredIndex(-1)
    , m_selectedIndex(-1)
    , m_interactive(true)
    , m_dualBootMode(false)
    , m_dualBootSize(0)
{
    setMouseTracking(true);
    setMinimumHeight(80);
    setCursor(Qt::PointingHandCursor);
}

void DiskWidget::setDisk(const DiskInfo &disk) {
    m_disk = disk;
    m_partitions = disk.partitions;
    m_selectedIndex = -1;
    m_selectedDevice.clear();
    m_highlightedDevice.clear();
    update();
}

void DiskWidget::setPartitions(const QList<PartitionInfo> &partitions) {
    m_partitions = partitions;
    update();
}

void DiskWidget::setInteractive(bool interactive) {
    m_interactive = interactive;
    setCursor(interactive ? Qt::PointingHandCursor : Qt::ArrowCursor);
}

void DiskWidget::setSelectedPartition(const QString &device) {
    m_selectedDevice = device;
    for (int i = 0; i < m_partitions.size(); ++i) {
        if (m_partitions[i].device == device) {
            m_selectedIndex = i;
            break;
        }
    }
    update();
}

void DiskWidget::highlightPartition(const QString &device) {
    m_highlightedDevice = device;
    update();
}

void DiskWidget::setDualBootMode(bool enabled, qint64 newOSSize) {
    m_dualBootMode = enabled;
    m_dualBootSize = newOSSize;
    update();
}

// ─── Paint ──────────────────────────────────────────────────────────────────

void DiskWidget::paintEvent(QPaintEvent *) {
    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);

    int w = width();
    int h = height();

    // Fundo
    painter.fillRect(rect(), QColor("#0a0a1a"));

    // Informações do disco no topo
    QFont infoFont = font();
    infoFont.setPointSize(10);
    infoFont.setBold(true);
    painter.setFont(infoFont);

    QString diskInfo = m_disk.device + " — " + m_disk.model;
    if (!m_disk.isSSD) diskInfo += " [HDD]";
    else diskInfo += " [SSD]";
    diskInfo += " — " + m_disk.sizeHuman() + " — " + m_disk.partitionTable.toUpper();

    painter.setPen(QColor("#00d4ff"));
    painter.drawText(10, 15, w - 20, 20, Qt::AlignLeft | Qt::AlignVCenter, diskInfo);

    // Posição da barra de partições
    int barY = 40;
    int barH = BAR_HEIGHT;
    int barX = BAR_MARGIN;
    int barW = w - 2 * BAR_MARGIN;

    if (m_partitions.isEmpty()) {
        // Disco vazio — mostrar barra vazia
        painter.setPen(Qt::NoPen);
        painter.setBrush(QColor("#1a1a3e"));
        painter.drawRoundedRect(barX, barY, barW, barH, 6, 6);

        painter.setPen(QColor("#666"));
        painter.drawText(QRect(barX, barY, barW, barH), Qt::AlignCenter, "Disco vazio — sem partições");
        return;
    }

    // Calcula tamanho total
    qint64 totalSize = 0;
    for (const auto &p : m_partitions) totalSize += p.sizeBytes;
    if (totalSize == 0) totalSize = m_disk.sizeBytes;

    // Desenha partições
    int xOffset = barX;
    for (int i = 0; i < m_partitions.size(); ++i) {
        const auto &part = m_partitions[i];

        qint64 partSize = part.sizeBytes;
        if (m_dualBootMode && i == m_partitions.size() - 1 && part.osName.contains("Windows")) {
            // Em modo dual boot, a última partição Windows é reduzida
            partSize = part.sizeBytes - m_dualBootSize;
        }

        int partW = static_cast<int>((static_cast<double>(partSize) / totalSize) * barW);
        if (partW < 4) partW = 4; // Mínimo visível

        QColor color = colorForPartition(part);
        QRect partRect(xOffset, barY, partW, barH);

        // Fundo da partição
        painter.setPen(Qt::NoPen);
        if (i == m_selectedIndex || part.device == m_selectedDevice) {
            // Selecionada: borda brilhante
            painter.setBrush(color);
            painter.drawRoundedRect(partRect.adjusted(0, 0, 0, 0), 4, 4);
            painter.setPen(QPen(QColor("#00d4ff"), 2));
            painter.drawRoundedRect(partRect.adjusted(1, 1, -1, -1), 4, 4);
        } else if (part.device == m_highlightedDevice) {
            painter.setBrush(color.lighter(130));
            painter.drawRoundedRect(partRect, 4, 4);
            painter.setPen(QPen(QColor("#ffd700"), 2));
            painter.drawRoundedRect(partRect.adjusted(1, 1, -1, -1), 4, 4);
        } else if (i == m_hoveredIndex) {
            painter.setBrush(color.lighter(120));
            painter.drawRoundedRect(partRect, 4, 4);
        } else {
            painter.setBrush(color);
            painter.drawRoundedRect(partRect, 4, 4);
        }

        // Rótulo na partição
        QFont labelFont = font();
        labelFont.setPointSize(8);
        painter.setFont(labelFont);
        painter.setPen(QColor("#fff"));

        QString label = part.fstype.toUpper();
        if (!part.osName.isEmpty()) label = part.osName.left(12);
        else if (!part.label.isEmpty()) label = part.label.left(12);

        QString sizeStr = PartitionManager::sizeHuman(partSize);

        if (partW > 60) {
            painter.drawText(partRect.adjusted(4, 2, -4, -2), Qt::AlignLeft | Qt::AlignTop, label);
            painter.drawText(partRect.adjusted(4, 2, -4, -2), Qt::AlignRight | Qt::AlignBottom, sizeStr);
        } else if (partW > 30) {
            painter.drawText(partRect, Qt::AlignCenter, sizeStr);
        }

        // Marcação de dual boot (linha tracejada mostrando onde vai cortar)
        if (m_dualBootMode && i == m_partitions.size() - 1 && part.osName.contains("Windows")) {
            int cutX = xOffset + partW;
            QPen dashedPen(QColor("#ffd700"), 2, Qt::DashLine);
            painter.setPen(dashedPen);
            painter.drawLine(cutX, barY - 5, cutX, barY + barH + 5);

            // Label "Novo SO →"
            painter.setPen(QColor("#ffd700"));
            QFont arrowFont = font();
            arrowFont.setPointSize(9);
            arrowFont.setBold(true);
            painter.setFont(arrowFont);
            painter.drawText(cutX + 5, barY - 18, 120, 16, Qt::AlignLeft,
                             "← FydelisTechOS (" + PartitionManager::sizeHuman(m_dualBootSize) + ")");
        }

        xOffset += partW;
    }

    // Espaço livre após partições (se houver)
    if (xOffset < barX + barW) {
        int freeW = (barX + barW) - xOffset;
        if (freeW > 10) {
            painter.setPen(Qt::NoPen);
            painter.setBrush(QColor("#2a2a4e"));
            painter.drawRoundedRect(xOffset, barY, freeW, barH, 4, 4);
            painter.setPen(QColor("#888"));
            painter.drawText(QRect(xOffset, barY, freeW, barH), Qt::AlignCenter, "Espaço livre");
        }
    }

    // Legenda abaixo
    int legendY = barY + barH + 12;
    int legendX = barX;
    QStringList legendItems;

    // Cores da legenda
    struct LegendEntry { QColor color; QString text; };
    QList<LegendEntry> entries = {
        {QColor("#00c853"), "ext4/ext3 (Linux)"},
        {QColor("#2979ff"), "NTFS (Windows)"},
        {QColor("#ff6d00"), "vfat/EFI"},
        {QColor("#d500f9"), "swap"},
        {QColor("#ffd700"), "Dual Boot (novo SO)"},
        {QColor("#2a2a4e"), "Livre/Outros"},
    };

    for (const auto &e : entries) {
        painter.setPen(Qt::NoPen);
        painter.setBrush(e.color);
        painter.drawRoundedRect(legendX, legendY, 12, 12, 2, 2);
        painter.setPen(QColor("#aaa"));
        QFont legFont = font();
        legFont.setPointSize(8);
        painter.setFont(legFont);
        painter.drawText(legendX + 16, legendY - 2, 120, 16, Qt::AlignLeft | Qt::AlignVCenter, e.text);
        legendX += 130;
    }
}

// ─── Mouse Events ───────────────────────────────────────────────────────────

int DiskWidget::partitionAtPos(const QPoint &pos) const {
    int w = width();
    int barX = BAR_MARGIN;
    int barW = w - 2 * BAR_MARGIN;
    int barY = 40;
    int barH = BAR_HEIGHT;

    if (pos.y() < barY || pos.y() > barY + barH) return -1;

    qint64 totalSize = 0;
    for (const auto &p : m_partitions) totalSize += p.sizeBytes;
    if (totalSize == 0) return -1;

    int xOffset = barX;
    for (int i = 0; i < m_partitions.size(); ++i) {
        const auto &part = m_partitions[i];
        qint64 partSize = part.sizeBytes;
        if (m_dualBootMode && i == m_partitions.size() - 1 && part.osName.contains("Windows")) {
            partSize = part.sizeBytes - m_dualBootSize;
        }
        int partW = static_cast<int>((static_cast<double>(partSize) / totalSize) * barW);
        if (partW < 4) partW = 4;

        if (pos.x() >= xOffset && pos.x() <= xOffset + partW) return i;
        xOffset += partW;
    }

    return -1;
}

void DiskWidget::mousePressEvent(QMouseEvent *event) {
    if (!m_interactive) return;
    int idx = partitionAtPos(event->pos());
    if (idx >= 0 && idx < m_partitions.size()) {
        m_selectedIndex = idx;
        m_selectedDevice = m_partitions[idx].device;
        update();
        emit partitionClicked(m_partitions[idx]);
    }
}

void DiskWidget::mouseDoubleClickEvent(QMouseEvent *event) {
    if (!m_interactive) return;
    int idx = partitionAtPos(event->pos());
    if (idx >= 0 && idx < m_partitions.size()) {
        emit partitionDoubleClicked(m_partitions[idx]);
    }
}

void DiskWidget::mouseMoveEvent(QMouseEvent *event) {
    int idx = partitionAtPos(event->pos());
    if (idx != m_hoveredIndex) {
        m_hoveredIndex = idx;
        update();

        if (idx >= 0 && idx < m_partitions.size()) {
            const auto &p = m_partitions[idx];
            QString tip = QString(
                "<b>%1</b><br>"
                "Tamanho: %2<br>"
                "Sistema: %3<br>"
                "Montado em: %4<br>"
                "UUID: %5"
            ).arg(p.device, p.sizeHuman(), p.fstype.isEmpty() ? "N/A" : p.fstype.toUpper(),
                  p.mountpoint.isEmpty() ? "Não montado" : p.mountpoint,
                  p.uuid.isEmpty() ? "N/A" : p.uuid);

            if (!p.osName.isEmpty()) {
                tip += "<br><b>SO:</b> " + p.osName;
            }

            setToolTip(tip);
        } else {
            setToolTip("");
        }
    }
}

void DiskWidget::leaveEvent(QEvent *) {
    m_hoveredIndex = -1;
    update();
}

// ─── Cores por tipo ─────────────────────────────────────────────────────────

QColor DiskWidget::colorForPartition(const PartitionInfo &part) const {
    if (part.osName.contains("Windows")) return QColor("#2979ff");
    if (part.osName.contains("Ubuntu") || part.osName.contains("Debian") ||
        part.osName.contains("Kali") || part.osName.contains("Linux Mint") ||
        part.osName.contains("Fedora") || part.osName.contains("Arch") ||
        part.osName.contains("Manjaro") || part.osName.contains("Pop")) {
        if (part.isRoot) return QColor("#00c853");
        if (part.isBoot) return QColor("#00e676");
        return QColor("#69f0ae");
    }
    if (part.isEFI) return QColor("#ff6d00");
    if (part.isSwap) return QColor("#d500f9");
    if (part.fstype == "ntfs") return QColor("#2979ff");
    if (part.fstype == "vfat" || part.fstype == "fat32") return QColor("#ff9100");
    if (part.fstype == "ext4" || part.fstype == "ext3" || part.fstype == "ext2") return QColor("#00c853");
    if (part.fstype == "btrfs") return QColor("#00bfa5");
    if (part.fstype == "xfs") return QColor("#1de9b6");
    if (part.fstype == "swap") return QColor("#d500f9");
    if (part.fstype == "zfs") return QColor("#448aff");

    return QColor("#3e3e6e");
}