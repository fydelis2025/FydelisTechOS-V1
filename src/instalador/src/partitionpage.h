#ifndef PARTITIONPAGE_H
#define PARTITIONPAGE_H

#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QComboBox>
#include <QRadioButton>
#include <QButtonGroup>
#include <QGroupBox>
#include <QTableWidget>
#include <QSlider>
#include <QSpinBox>
#include <QScrollArea>
#include <QStackedWidget>

#include "partitionmanager.h"
#include "diskwidget.h"

// ─── PartitionPage — Página estilo Ubuntu de gerenciamento de partição ──────
class PartitionPage : public QWidget {
    Q_OBJECT

public:
    explicit PartitionPage(QWidget *parent = nullptr);

    void refreshDisks();
    QList<PartitionAction> getActions() const;
    QString getInstallDevice() const;
    bool isDualBootSelected() const;
    bool isEraseDiskSelected() const;

signals:
    void selectionChanged(const QString &summary);
    void readyChanged(bool ready);

private slots:
    void onInstallTypeChanged(int id);
    void onDiskSelected(int index);
    void onPartitionClicked(const PartitionInfo &part);
    void onDualBootSliderChanged(int value);
    void onManualActionClicked();
    void showPartitionDetails(const PartitionInfo &part);
    void refreshClicked();

private:
    void setupUI();
    void updateDiskVisualization();
    void updateSummary();
    void populateDiskCombo();
    void populatePartitionTable();
    bool validateSelection();

    // ─── Widgets ───────────────────────────────────────────────────
    QStackedWidget *m_typeStack;

    // Radio buttons de tipo de instalação
    QButtonGroup *m_typeGroup;
    QRadioButton *m_radioDualBoot;
    QRadioButton *m_radioEraseDisk;
    QRadioButton *m_radioManual;

    // Dual Boot
    QComboBox *m_dualBootDiskCombo;
    QLabel *m_dualBootInfoLabel;
    QSlider *m_dualBootSlider;
    QLabel *m_dualBootSizeLabel;
    QLabel *m_dualBootWindowsSizeLabel;
    QLabel *m_dualBootNewSizeLabel;

    // Apagar disco
    QComboBox *m_eraseDiskCombo;
    QLabel *m_eraseInfoLabel;

    // Manual
    QComboBox *m_manualDiskCombo;
    QTableWidget *m_partitionTable;
    QPushButton *m_btnNewPartition;
    QPushButton *m_btnDeletePartition;
    QPushButton *m_btnFormatPartition;
    QPushButton *m_btnResizePartition;

    // Visualização
    DiskWidget *m_diskWidget;
    QLabel *m_diskInfoLabel;

    // Detalhes
    QLabel *m_partitionDetailsLabel;

    // Resumo
    QLabel *m_summaryLabel;

    // Dados
    PartitionManager *m_partMgr;
    QList<DiskInfo> m_disks;
    QList<DualBootOption> m_dualBootOptions;
    QList<PartitionAction> m_actions;
    int m_selectedDiskIndex;
};

#endif // PARTITIONPAGE_H