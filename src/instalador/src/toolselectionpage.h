#ifndef TOOLSELECTIONPAGE_H
#define TOOLSELECTIONPAGE_H

#include <QWidget>
#include <QVBoxLayout>
#include <QTreeWidget>
#include <QCheckBox>
#include <QLabel>
#include <QPushButton>
#include "tools.h"

class ToolSelectionPage : public QWidget {
    Q_OBJECT

public:
    explicit ToolSelectionPage(QWidget *parent = nullptr);

    QStringList getSelectedPackages() const;
    int totalSelected() const;

private slots:
    void updateCount();
    void onSelectAllToggled(bool checked);

private:
    void setupUI();
    void populateTools();

    QTreeWidget *m_toolTree;
    QCheckBox   *m_selectAllCheck;
    QLabel      *m_countLabel;
};

#endif // TOOLSELECTIONPAGE_H