#ifndef SUMMARYPAGE_H
#define SUMMARYPAGE_H

#include <QWidget>
#include <QLabel>
#include <QVBoxLayout>
#include <QTextEdit>

class SummaryPage : public QWidget {
    Q_OBJECT

public:
    explicit SummaryPage(QWidget *parent = nullptr);

    void setResult(bool success, const QString &summary);

private:
    void setupUI();

    QLabel    *m_iconLabel;
    QLabel    *m_titleLabel;
    QTextEdit *m_summaryText;
};

#endif // SUMMARYPAGE_H