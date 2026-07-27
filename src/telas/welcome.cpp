#include <QApplication>
#include <QWidget>
#include <QLabel>
#include <QCheckBox>
#include <QPushButton>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QFile>
#include <QTextStream>
#include <QStandardPaths>
#include <QDir>
#include <QFont>
#include <QFrame>

class WelcomeWindow : public QWidget {
public:
    WelcomeWindow(QWidget *parent = nullptr) : QWidget(parent) {
        setWindowTitle("FydelistechOS v1.0 — Boas-vindas");
        setFixedSize(680, 520);
        setStyleSheet("background-color: #0c0c1e;");

        QVBoxLayout *mainLayout = new QVBoxLayout(this);
        mainLayout->setContentsMargins(30, 25, 30, 25);
        mainLayout->setSpacing(8);

        // ===== BORDA =====
        QFrame *borda = new QFrame(this);
        borda->setStyleSheet(
            "QFrame {"
            "  border: 2px solid #00bcd4;"
            "  border-radius: 6px;"
            "  background-color: #0f0f24;"
            "}"
        );
        QVBoxLayout *frameLayout = new QVBoxLayout(borda);
        frameLayout->setContentsMargins(25, 20, 25, 20);
        frameLayout->setSpacing(6);

        // TÍTULO
        QLabel *titulo = new QLabel("🚀  BEM-VINDO AO FYDELISTECHOS OS v1.0", borda);
        titulo->setAlignment(Qt::AlignCenter);
        titulo->setStyleSheet("color: #ffd700; font-size: 20px; font-weight: bold; background: transparent; border: none;");

        // LINHA
        QFrame *hr1 = new QFrame(borda);
        hr1->setFrameShape(QFrame::HLine);
        hr1->setStyleSheet("color: #333355; background: #333355; border: none; height: 1px;");

        // DESCRIÇÃO
        QLabel *desc = new QLabel(
            "Sistema operacional desenvolvido pela Fydelistechos\n"
            "Baseado em Debian GNU/Linux — estável, seguro e completo.",
            borda
        );
        desc->setAlignment(Qt::AlignCenter);
        desc->setStyleSheet("color: #a0a0c0; font-size: 12px; background: transparent; border: none;");

        // LINHA
        QFrame *hr2 = new QFrame(borda);
        hr2->setFrameShape(QFrame::HLine);
        hr2->setStyleSheet("color: #333355; background: #333355; border: none; height: 1px;");

        // CONTEÚDO
        QLabel *conteudo = new QLabel(borda);
        conteudo->setText(
            "<span style='color: #4caf50; font-weight: bold;'>📌  O que você encontra aqui:</span><br>"
            "  <span style='color: #e0e0e0;'>• Terminal próprio de baixo nível</span><br>"
            "  <span style='color: #e0e0e0;'>• Programas básicos, escritório e rede</span><br>"
            "  <span style='color: #e0e0e0;'>• Ferramentas de análise e segurança</span><br>"
            "  <span style='color: #e0e0e0;'>• Gerenciamento fácil de pacotes e atualizações</span><br><br>"
            "<span style='color: #9e9e9e;'>💡  Use o menu abaixo para navegar ou digite comandos</span><br>"
            "<span style='color: #9e9e9e;'>     diretamente no terminal.</span>"
        );
        conteudo->setStyleSheet("background: transparent; border: none; font-size: 12px;");
        conteudo->setWordWrap(true);

        // LINHA
        QFrame *hr3 = new QFrame(borda);
        hr3->setFrameShape(QFrame::HLine);
        hr3->setStyleSheet("color: #333355; background: #333355; border: none; height: 1px;");

        // SUPORTE
        QLabel *suporte = new QLabel("📞  Suporte: suporte@fydelistechos.com.br", borda);
        suporte->setAlignment(Qt::AlignCenter);
        suporte->setStyleSheet("color: #00bcd4; font-size: 12px; background: transparent; border: none;");

        frameLayout->addWidget(titulo);
        frameLayout->addWidget(hr1);
        frameLayout->addWidget(desc);
        frameLayout->addWidget(hr2);
        frameLayout->addWidget(conteudo);
        frameLayout->addWidget(hr3);
        frameLayout->addWidget(suporte);

        // ===== CHECKBOX + BOTÃO =====
        QHBoxLayout *bottomLayout = new QHBoxLayout();
        bottomLayout->setContentsMargins(10, 8, 10, 0);

        checkNaoMostrar = new QCheckBox("Não mostrar esta tela novamente", this);
        checkNaoMostrar->setStyleSheet(
            "QCheckBox { color: white; font-size: 11px; spacing: 8px; }"
            "QCheckBox::indicator { width: 16px; height: 16px; border: 2px solid #00bcd4; border-radius: 3px; background: #1a1a3a; }"
            "QCheckBox::indicator:checked { background-color: #00bcd4; }"
        );

        btnContinuar = new QPushButton("Continuar", this);
        btnContinuar->setFixedSize(120, 35);
        btnContinuar->setStyleSheet(
            "QPushButton {"
            "  background-color: #0078d7; color: white;"
            "  font-size: 12px; font-weight: bold;"
            "  border: none; border-radius: 4px;"
            "}"
            "QPushButton:hover { background-color: #1a8ae8; }"
            "QPushButton:pressed { background-color: #0060b0; }"
        );

        bottomLayout->addWidget(checkNaoMostrar);
        bottomLayout->addStretch();
        bottomLayout->addWidget(btnContinuar);

        mainLayout->addWidget(borda, 1);
        mainLayout->addLayout(bottomLayout);

        // Conexão com LAMBDA — sem MOC necessário!
        connect(btnContinuar, &QPushButton::clicked, [this]() {
            onContinuar();
        });

        // Verificar se já foi exibida
        if (jaFoiExibida()) {
            close();
        }
    }

private:
    QCheckBox *checkNaoMostrar;
    QPushButton *btnContinuar;

    void onContinuar() {
        salvarPreferencia(checkNaoMostrar->isChecked());
        close();
    }

    QString configPath() {
        QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
        return home + "/.fydelistechos_welcome.conf";
    }

    bool jaFoiExibida() {
        QFile file(configPath());
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            return false;
        QTextStream in(&file);
        QString val = in.readAll().trimmed();
        return val == "1";
    }

    void salvarPreferencia(bool naoMostrar) {
        QFile file(configPath());
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            out << (naoMostrar ? "1" : "0");
        }
    }
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    app.setStyle("Fusion");

    WelcomeWindow w;
    w.show();

    return app.exec();
}
