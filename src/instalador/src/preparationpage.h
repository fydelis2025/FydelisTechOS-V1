#ifndef PREPARATIONPAGE_H
#define PREPARATIONPAGE_H

#include <QWidget>
#include <QLabel>
#include <QVBoxLayout>
#include <QCheckBox>
#include <QComboBox>
#include <QGroupBox>

class PreparationPage : public QWidget {
    Q_OBJECT

public:
    explicit PreparationPage(QWidget *parent = nullptr);

    bool installUpdates() const;
    bool installThirdParty() const;
    QString keyboardLayout() const;

private:
    void setupUI();

    QCheckBox *m_updateCheck;
    QCheckBox *m_thirdPartyCheck;
    QComboBox *m_keyboardCombo;
};

#endif // PREPARATIONPAGE_H