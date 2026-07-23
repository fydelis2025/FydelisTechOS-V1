#ifndef IMAGESLIDEPLAYER_H
#define IMAGESLIDEPLAYER_H

#include <QWidget>
#include <QLabel>
#include <QTimer>
#include <QPushButton>
#include <QPixmap>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QStackedWidget>
#include <QProgressBar>
#include <QDir>
#include <QFileInfo>
#include <QApplication>

// ─── ImageSlidePlayer — Exibe slides PNG durante a instalação ──────────────
class ImageSlidePlayer : public QWidget {
    Q_OBJECT

public:
    explicit ImageSlidePlayer(QWidget *parent = nullptr);

    // Define o diretório onde estão as imagens slide1.png ... slideN.png
    void setImageDirectory(const QString &path);

    // Define os caminhos manualmente (se preferir)
    void setImagePaths(const QStringList &paths);

    // Avança para o slide baseado no percentual da instalação
    void updateProgress(int percent);

    // Controles manuais
    void nextSlide();
    void prevSlide();
    void goToSlide(int index);

    // Total de slides carregados
    int totalSlides() const { return m_images.size(); }
    int currentIndex() const { return m_currentIndex; }

signals:
    void slideChanged(int index, int total);

private:
    void setupUI();
    void loadImages();
    void renderSlide(int index);

    QStackedWidget *m_stack;
    QLabel         *m_counterLabel;
    QLabel         *m_pageIndicator;    // bolinhas indicadoras
    QWidget        *m_dotContainer;

    QString         m_imageDir;
    QStringList     m_imagePaths;
    QList<QPixmap>  m_images;
    int             m_currentIndex;

    static const int PROGRESS_STEPS = 5; // 5 imagens
};

#endif // IMAGESLIDEPLAYER_H