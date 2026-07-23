#ifndef DISKWIDGET_H
#define DISKWIDGET_H

#include <QWidget>
#include <QPainter>
#include <QMouseEvent>
#include <QToolTip>
#include "partitionmanager.h"

// ─── DiskWidget — Representação visual de um disco com partições coloridas ───
class DiskWidget : public QWidget {
    Q_OBJECT

public:
    explicit DiskWidget(QWidget *parent = nullptr);

    void setDisk(const DiskInfo &disk);
    void setPartitions(const QList<PartitionInfo> &partitions);
    void setInteractive(bool interactive);
    void setSelectedPartition(const QString &device);
    void highlightPartition(const QString &device);
    void setDualBootMode(bool enabled, qint64 newOSSize);

    DiskInfo disk() const { return m_disk; }
    QString selectedPartition() const { return m_selectedDevice; }

signals:
    void partitionClicked(const PartitionInfo &partition);
    void partitionDoubleClicked(const PartitionInfo &partition);
    void resizeRequested(const QString &device, qint64 newSize);

protected:
    void paintEvent(QPaintEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseDoubleClickEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void leaveEvent(QEvent *event) override;

private:
    QRect partitionRect(int index) const;
    int partitionAtPos(const QPoint &pos) const;
    QColor colorForPartition(const PartitionInfo &part) const;

    DiskInfo m_disk;
    int m_hoveredIndex;
    int m_selectedIndex;
    QString m_selectedDevice;
    QString m_highlightedDevice;
    bool m_interactive;
    bool m_dualBootMode;
    qint64 m_dualBootSize;
    QList<PartitionInfo> m_partitions;

    static const int BAR_HEIGHT = 48;
    static const int BAR_MARGIN = 20;
};

#endif // DISKWIDGET_H