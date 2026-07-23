#ifndef ASSISTANTINTRO_H
#define ASSISTANTINTRO_H

#include <QWidget>
#include <QLabel>
#include <QPushButton>
#include <QTimer>
#include <QVBoxLayout>

class AssistantIntro : public QWidget {
    Q_OBJECT
public:
    explicit AssistantIntro(QWidget *parent = nullptr);

signals:
    void assistantFinished(); // Sinal para avançar para o instalador principal

private slots:
    void typeText();

private:
    QLabel *m_avatarLabel;
    QLabel *m_textLabel;
    QPushButton *m_nextButton;
    QTimer *m_timer;
    QString m_fullText;
    int m_index;
};

#endif // ASSISTANTINTRO_H