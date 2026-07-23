#ifndef WELCOMEPAGE_H
#define WELCOMEPAGE_H

#include <QWidget>
#include <QLabel>
#include <QVBoxLayout>
#include <QComboBox>
#include <QPushButton>

class WelcomePage : public QWidget {
    Q_OBJECT

public:
    explicit WelcomePage(QWidget *parent = nullptr);

    QString selectedLanguage() const;

private:
    void setupUI();
    QComboBox *m_langCombo;
};

#endif // WELCOMEPAGE_H