#include "imageslideplayer.h"
#include <QPainter>
#include <QFileInfoList>
#include <QHBoxLayout>

ImageSlidePlayer::ImageSlidePlayer(QWidget *parent)
    : QWidget(parent)
    , m_stack(new QStackedWidget(this))
    , m_counterLabel(new QLabel(this))
    , m_pageIndicator(nullptr)
    , m_dotContainer(nullptr)
    , m_currentIndex(0)
{
    setupUI();
}

void ImageSlidePlayer::setupUI() {
    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);

    // ─── Stack de imagens ──────────────────────────────────────────
    layout->addWidget(m_stack, 1);

    // ─── Barra inferior com indicadores ────────────────────────────
    QWidget *bottomBar = new QWidget(this);
    bottomBar->setFixedHeight(50);
    bottomBar->setStyleSheet(
        "background-color: rgba(10, 10, 26, 200);"
        "border-top: 1px solid #16213e;"
    );

    QHBoxLayout *bottomLayout = new QHBoxLayout(bottomBar);
    bottomLayout->setContentsMargins(20, 5, 20, 5);

    // Contador textual "3 / 5"
    m_counterLabel->setStyleSheet("color: #aaa; font-size: 13px; font-weight: bold;");
    m_counterLabel->setFixedWidth(80);
    bottomLayout->addWidget(m_counterLabel);

    bottomLayout->addStretch();

    // Bolinhas indicadoras (page dots)
    m_dotContainer = new QWidget;
    QHBoxLayout *dotLayout = new QHBoxLayout(m_dotContainer);
    dotLayout->setContentsMargins(0, 0, 0, 0);
    dotLayout->setSpacing(8);
    bottomLayout->addWidget(m_dotContainer);

    bottomLayout->addStretch();

    // Legenda
    QLabel *legendLabel = new QLabel("FydelisTechOS Lite — Instalação");
    legendLabel->setStyleSheet("color: #555; font-size: 11px;");
    bottomLayout->addWidget(legendLabel);

    layout->addWidget(bottomBar);
}

// ─── Carregar imagens ──────────────────────────────────────────────────────

void ImageSlidePlayer::setImageDirectory(const QString &path) {
    m_imageDir = path;
    m_imagePaths.clear();

    QDir dir(path);
    if (!dir.exists()) return;

    // Procura por slide1.png até slideN.png na ordem
    for (int i = 1; i <= 100; ++i) {
        QString fileName = QString("slide%1.png").arg(i);
        QString fullPath = dir.absoluteFilePath(fileName);
        if (QFileInfo::exists(fullPath)) {
            m_imagePaths << fullPath;
        } else {
            // Tenta com zero padding: slide01.png
            fileName = QString("slide%1.png").arg(i, 2, 10, QChar('0'));
            fullPath = dir.absoluteFilePath(fileName);
            if (QFileInfo::exists(fullPath)) {
                m_imagePaths << fullPath;
            } else {
                break; // Para no primeiro gap
            }
        }
    }

    loadImages();
}

void ImageSlidePlayer::setImagePaths(const QStringList &paths) {
    m_imagePaths = paths;
    m_imageDir.clear();
    loadImages();
}

void ImageSlidePlayer::loadImages() {
    // Correção para o Qt 6: Remove os widgets do stack um a um de forma segura
    while (m_stack->count() > 0) {
        QWidget *widget = m_stack->widget(0);
        m_stack->removeWidget(widget);
        delete widget;
    }
    
    m_images.clear();

    // Limpar bolinhas antigas
    if (m_dotContainer) {
        QLayout *layout = m_dotContainer->layout();
        if (layout) {
            QLayoutItem *item;
            while ((item = layout->takeAt(0)) != nullptr) {
                delete item->widget();
                delete item;
            }
        }
    }

    for (int i = 0; i < m_imagePaths.size(); ++i) {
        QPixmap pix(m_imagePaths[i]);
        if (pix.isNull()) {
            // Se a imagem não carregar, cria uma placeholder
            pix = QPixmap(800, 500);
            pix.fill(QColor("#1a1a2e"));
            QPainter p(&pix);
            p.setPen(QColor("#ff5252"));
            p.setFont(QFont("sans-serif", 20));
            p.drawText(pix.rect(), Qt::AlignCenter,
                       QString("⚠️ Slide %1 não encontrado\n%2")
                           .arg(i + 1)
                           .arg(m_imagePaths[i]));
            p.end();
        }

        m_images.append(pix);

        // Cria label com a imagem escalada
        QLabel *imageLabel = new QLabel;
        imageLabel->setPixmap(pix);
        imageLabel->setAlignment(Qt::AlignCenter);
        imageLabel->setScaledContents(true);
        imageLabel->setStyleSheet("background-color: #0a0a1a;");
        m_stack->addWidget(imageLabel);

        // Cria bolinha indicadora
        QLabel *dot = new QLabel;
        dot->setFixedSize(12, 12);
        dot->setStyleSheet(
            "background-color: #333; border-radius: 6px; border: 1px solid #555;"
        );
        m_dotContainer->layout()->addWidget(dot);
    }

    if (!m_images.isEmpty()) {
        m_currentIndex = 0;
        m_stack->setCurrentIndex(0);
        renderSlide(0);
    } else {
        // Nenhuma imagem encontrada — mostra placeholder
        QLabel *noImg = new QLabel;
        noImg->setAlignment(Qt::AlignCenter);
        noImg->setStyleSheet("color: #888; font-size: 18px;");
        noImg->setText(
            "📸 Nenhuma imagem encontrada\n\n"
            "Coloque os arquivos slide1.png a slide5.png em:\n"
            "/usr/share/fydelistechos/slides/\n"
            "ou no diretório atual"
        );
        m_stack->addWidget(noImg);
        m_counterLabel->setText("0 / 0");
    }
}

// ─── Atualizar slide baseado no progresso ──────────────────────────────────

void ImageSlidePlayer::updateProgress(int percent) {
    if (m_images.isEmpty()) return;

    // Mapeia percentual 0-100 para slide 0-4 (5 imagens)
    int total = m_images.size();
    int targetIndex = qMin((percent * total) / 100, total - 1);

    if (targetIndex != m_currentIndex) {
        goToSlide(targetIndex);
    }
}

void ImageSlidePlayer::nextSlide() {
    if (m_currentIndex < m_images.size() - 1) {
        goToSlide(m_currentIndex + 1);
    }
}

void ImageSlidePlayer::prevSlide() {
    if (m_currentIndex > 0) {
        goToSlide(m_currentIndex - 1);
    }
}

void ImageSlidePlayer::goToSlide(int index) {
    if (index < 0 || index >= m_images.size()) return;
    m_currentIndex = index;
    m_stack->setCurrentIndex(index);
    renderSlide(index);
    emit slideChanged(index, m_images.size());
}

void ImageSlidePlayer::renderSlide(int index) {
    m_counterLabel->setText(QString("%1 / %2").arg(index + 1).arg(m_images.size()));

    // Atualiza bolinhas
    QLayout *layout = m_dotContainer ? m_dotContainer->layout() : nullptr;
    if (layout) {
        for (int i = 0; i < layout->count(); ++i) {
            QWidget *dot = layout->itemAt(i)->widget();
            if (!dot) continue;

            if (i == index) {
                dot->setStyleSheet(
                    "background-color: #00d4ff; border-radius: 6px; "
                    "border: 2px solid #00d4ff;"
                );
            } else if (i < index) {
                dot->setStyleSheet(
                    "background-color: #00c853; border-radius: 6px; "
                    "border: 1px solid #00c853;"
                );
            } else {
                dot->setStyleSheet(
                    "background-color: #333; border-radius: 6px; border: 1px solid #555;"
                );
            }
        }
    }
}