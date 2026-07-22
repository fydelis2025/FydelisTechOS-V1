#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FydelisPackage.py - Gerenciador de Pacotes Gráfico FydelisTechOS
Versão 3.1 — Correções Windows + Gradiente
"""

import os
import sys
import subprocess
import re
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QMessageBox, QInputDialog, QTextEdit,
    QFrame, QSizePolicy, QSpacerItem, QDialog, QGraphicsDropShadowEffect,
    QTableWidget, QTableWidgetItem, QHeaderView, QAbstractItemView,
    QCheckBox, QGroupBox, QScrollArea
)
from PyQt5.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, pyqtProperty, pyqtSignal
from PyQt5.QtGui import QFont, QColor, QPalette, QIcon, QPixmap, QLinearGradient, QBrush, QPainter


# ──────────────────────────────────────────────────────────────
#  Widget decorado com gradiente animado (background vivo)
# ──────────────────────────────────────────────────────────────
class AnimatedBackground(QWidget):
    """Widget com gradiente animado suave no fundo."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self._gradient_pos = 0.0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._animate)
        self._timer.start(50)

    def _animate(self):
        self._gradient_pos += 0.005
        if self._gradient_pos > 1.0:
            self._gradient_pos = 0.0
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        rect = self.rect()
        grad = QLinearGradient(0, 0, rect.width(), rect.height())

        # Garante que as posições fiquem DENTRO de [0.0, 1.0]
        offset = self._gradient_pos * 0.15
        p1 = min(max(0.0 + offset, 0.0), 1.0)
        p2 = min(max(0.5 + offset, 0.0), 1.0)
        p3 = min(max(1.0 + offset, 0.0), 1.0)

        c1 = QColor(16, 22, 47)       # #10162F
        c2 = QColor(26, 35, 80)       # tom intermediário
        c3 = QColor(16, 22, 47)

        grad.setColorAt(p1, c1)
        grad.setColorAt(p2, c2)
        grad.setColorAt(p3, c3)

        painter.fillRect(rect, grad)

    def stop_animation(self):
        self._timer.stop()


# ──────────────────────────────────────────────────────────────
#  Botão estilizado com sombra e hover suave
# ──────────────────────────────────────────────────────────────
class ModernButton(QPushButton):
    def __init__(self, text, icon="", accent_color="#6A11CB", hover_color="#22D3EE"):
        super().__init__(text)
        self._accent = accent_color
        self._hover = hover_color
        self.setCursor(Qt.PointingHandCursor)
        self.setMinimumHeight(46)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        font = QFont("Segoe UI", 11, QFont.Bold)
        self.setFont(font)

        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(18)
        shadow.setXOffset(0)
        shadow.setYOffset(4)
        shadow.setColor(QColor(0, 0, 0, 100))
        self.setGraphicsEffect(shadow)

        self._update_style()

    def set_accent(self, color):
        self._accent = color
        self._update_style()

    def set_hover_color(self, color):
        self._hover = color
        self._update_style()

    def _update_style(self):
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 {self._accent}, stop:1 #8B5CF6);
                color: #FFFFFF;
                border: none;
                border-radius: 12px;
                padding: 10px 20px;
                text-align: left;
            }}
            QPushButton:hover {{
                background-color: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 {self._hover}, stop:1 #38BDF8);
                color: #0F172A;
            }}
            QPushButton:pressed {{
                padding-top: 12px;
                padding-bottom: 8px;
            }}
        """)


# ──────────────────────────────────────────────────────────────
#  Janela de resultado — visual moderna com QTextEdit
# ──────────────────────────────────────────────────────────────
class ResultDialog(QDialog):
    def __init__(self, title, text, parent=None):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setMinimumSize(680, 420)
        self.setStyleSheet("""
            QDialog {
                background-color: #0F172A;
                border-radius: 16px;
            }
        """)

        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(30)
        shadow.setXOffset(0)
        shadow.setYOffset(8)
        shadow.setColor(QColor(0, 0, 0, 120))
        self.setGraphicsEffect(shadow)

        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)

        lbl_title = QLabel(f"📄 {title}")
        lbl_title.setFont(QFont("Segoe UI", 14, QFont.Bold))
        lbl_title.setStyleSheet("color: #F8FAFC;")
        layout.addWidget(lbl_title)

        self.text_area = QTextEdit()
        self.text_area.setReadOnly(True)
        self.text_area.setFont(QFont("Consolas", 10))
        self.text_area.setPlainText(text if text else "Nenhuma saída gerada.")
        self.text_area.setStyleSheet("""
            QTextEdit {
                background-color: #1E293B;
                color: #E2E8F0;
                border: 1px solid #334155;
                border-radius: 10px;
                padding: 12px;
                selection-background-color: #6A11CB;
            }
        """)
        layout.addWidget(self.text_area)

        btn_close = QPushButton("✕ Fechar")
        btn_close.setMinimumHeight(42)
        btn_close.setCursor(Qt.PointingHandCursor)
        btn_close.setStyleSheet("""
            QPushButton {
                background-color: #334155;
                color: #F8FAFC;
                border: none;
                border-radius: 10px;
                font-size: 13px;
                font-weight: bold;
                padding: 10px;
            }
            QPushButton:hover {
                background-color: #475569;
            }
        """)
        btn_close.clicked.connect(self.accept)

        layout.addWidget(btn_close)
        self.setLayout(layout)


# ──────────────────────────────────────────────────────────────
#  Grid de Atualizações — Tabela com checkboxes
# ──────────────────────────────────────────────────────────────
class UpdateGridWidget(QFrame):
    """Painel que exibe pacotes disponíveis para atualização em formato de grid."""

    # Signal agora importado corretamente via from PyQt5.QtCore import pyqtSignal
    update_selected_signal = pyqtSignal(list)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._upgradable_data = []  # lista de (pacote, versao_atual, versao_nova)
        self._setup_ui()

    def _setup_ui(self):
        self.setStyleSheet("""
            UpdateGridWidget {
                background-color: rgba(15, 23, 42, 180);
                border-radius: 16px;
                border: 1px solid rgba(106, 17, 203, 60);
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        layout.setSpacing(8)

        # ── Cabeçalho da seção ──
        header_row = QHBoxLayout()

        icon_lbl = QLabel("📦")
        icon_lbl.setFont(QFont("Segoe UI", 16))
        header_row.addWidget(icon_lbl)

        title_lbl = QLabel("Atualizações Disponíveis")
        title_lbl.setFont(QFont("Segoe UI", 13, QFont.Bold))
        title_lbl.setStyleSheet("color: #F8FAFC;")
        header_row.addWidget(title_lbl)

        header_row.addStretch()

        # Botão "Verificar"
        self.btn_scan = QPushButton("🔄 Verificar")
        self.btn_scan.setMinimumHeight(34)
        self.btn_scan.setCursor(Qt.PointingHandCursor)
        self.btn_scan.setStyleSheet("""
            QPushButton {
                background-color: #2563EB;
                color: #FFFFFF;
                border: none;
                border-radius: 8px;
                font-size: 11px;
                font-weight: bold;
                padding: 6px 16px;
            }
            QPushButton:hover {
                background-color: #3B82F6;
            }
        """)
        self.btn_scan.clicked.connect(self._scan_updates)
        header_row.addWidget(self.btn_scan)

        # Botão "Atualizar Selecionados"
        self.btn_apply = QPushButton("⬆ Aplicar")
        self.btn_apply.setMinimumHeight(34)
        self.btn_apply.setCursor(Qt.PointingHandCursor)
        self.btn_apply.setEnabled(False)
        self.btn_apply.setStyleSheet("""
            QPushButton {
                background-color: #0D9488;
                color: #FFFFFF;
                border: none;
                border-radius: 8px;
                font-size: 11px;
                font-weight: bold;
                padding: 6px 16px;
            }
            QPushButton:hover {
                background-color: #14B8A6;
            }
            QPushButton:disabled {
                background-color: #334155;
                color: #64748B;
            }
        """)
        self.btn_apply.clicked.connect(self._apply_selected)
        header_row.addWidget(self.btn_apply)

        layout.addLayout(header_row)

        # ── Tabela ──
        self.table = QTableWidget()
        self.table.setColumnCount(4)
        self.table.setHorizontalHeaderLabels(["", "Pacote", "Versão Atual", "Nova Versão"])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Fixed)
        self.table.setColumnWidth(0, 36)
        self.table.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeToContents)
        self.table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeToContents)
        self.table.verticalHeader().setVisible(False)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.setAlternatingRowColors(True)
        self.table.setMinimumHeight(140)
        self.table.setMaximumHeight(300)

        self.table.setStyleSheet("""
            QTableWidget {
                background-color: #0F172A;
                color: #E2E8F0;
                border: 1px solid #334155;
                border-radius: 8px;
                gridline-color: #1E293B;
                font-size: 11px;
                font-family: 'Consolas', 'Courier New', monospace;
            }
            QTableWidget::item {
                padding: 4px 8px;
            }
            QTableWidget::item:selected {
                background-color: #6A11CB;
                color: #FFFFFF;
            }
            QHeaderView::section {
                background-color: #1E293B;
                color: #94A3B8;
                border: none;
                border-bottom: 1px solid #334155;
                padding: 6px 4px;
                font-size: 10px;
                font-weight: bold;
                text-transform: uppercase;
            }
            QTableWidget::indicator {
                width: 16px;
                height: 16px;
            }
        """)

        # Placeholder quando vazio
        self._show_placeholder()

        layout.addWidget(self.table)

        # ── Label de contagem ──
        self.lbl_count = QLabel("Nenhuma atualização verificada.")
        self.lbl_count.setFont(QFont("Segoe UI", 10))
        self.lbl_count.setStyleSheet("color: #64748B;")
        layout.addWidget(self.lbl_count)

    def _show_placeholder(self):
        """Exibe mensagem de placeholder na tabela vazia."""
        self.table.setRowCount(1)
        self.table.setSpan(0, 0, 1, 4)
        item = QTableWidgetItem("  Clique em \"Verificar\" para buscar atualizações...")
        item.setTextAlignment(Qt.AlignCenter)
        item.setForeground(QColor(100, 116, 139))
        self.table.setItem(0, 0, item)
        for col in range(4):
            self.table.setCellWidget(0, col, None)
        cb = QCheckBox()
        cb.setVisible(False)
        self.table.setCellWidget(0, 0, cb)

    def _clear_table(self):
        """Remove todas as linhas da tabela."""
        self.table.setRowCount(0)

    def _scan_updates(self):
        """Executa apt list --upgradable e preenche a tabela."""
        QApplication.processEvents()

        self.lbl_count.setText("🔄 Escaneando atualizações...")
        self.btn_scan.setEnabled(False)
        QApplication.processEvents()

        env = os.environ.copy()
        env["DEBIAN_FRONTEND"] = "noninteractive"

        try:
            resultado = subprocess.run(
                "apt list --upgradable 2>/dev/null",
                shell=True, env=env,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True
            )

            self._parse_and_fill(resultado.stdout)
        except Exception as e:
            self._clear_table()
            self._show_placeholder()
            self.lbl_count.setText(f"❌ Erro: {str(e)}")
        finally:
            self.btn_scan.setEnabled(True)

    def _parse_and_fill(self, raw_text):
        """Interpreta a saída do apt list --upgradable e monta a tabela."""
        self._upgradable_data = []
        self._clear_table()

        lines = raw_text.strip().split('\n')
        # Formato: nome/now versao_apt amd64 [upgradable from: versao_atual]
        pattern = re.compile(
            r'^(\S+)/now\s+(\S+)\s+\S+\s+\[upgradable\s+from:\s+(\S+)\]$'
        )

        for line in lines:
            line = line.strip()
            if not line or line.startswith("Listing..."):
                continue
            m = pattern.match(line)
            if m:
                pacote = m.group(1)
                versao_nova = m.group(2)
                versao_atual = m.group(3)
                pacote_clean = pacote.split(':')[0] if ':' in pacote else pacote
                self._upgradable_data.append((pacote_clean, versao_atual, versao_nova))

        if not self._upgradable_data:
            # Parse alternativo
            pattern2 = re.compile(
                r'^(\S+?)(?::\S+)?/now\s+(\S+)\s+\S+\s+\[upgradable\s+from:\s+(\S+)\]$'
            )
            for line in lines:
                line = line.strip()
                if not line or line.startswith("Listing..."):
                    continue
                m = pattern2.match(line)
                if m:
                    pacote = m.group(1)
                    versao_nova = m.group(2)
                    versao_atual = m.group(3)
                    self._upgradable_data.append((pacote, versao_atual, versao_nova))

        if not self._upgradable_data:
            self._show_placeholder()
            self.lbl_count.setText("✅ Sistema atualizado — nenhum pacote pendente.")
            self.btn_apply.setEnabled(False)
            return

        self.table.setRowCount(len(self._upgradable_data))
        for i, (pacote, v_old, v_new) in enumerate(self._upgradable_data):
            # Checkbox
            cb = QCheckBox()
            cb.setStyleSheet("""
                QCheckBox::indicator {
                    width: 16px;
                    height: 16px;
                }
                QCheckBox::indicator:unchecked {
                    border: 2px solid #64748B;
                    border-radius: 4px;
                    background-color: transparent;
                }
                QCheckBox::indicator:checked {
                    border: 2px solid #22D3EE;
                    border-radius: 4px;
                    background-color: #22D3EE;
                }
            """)
            self.table.setCellWidget(i, 0, cb)

            nome_item = QTableWidgetItem(pacote)
            nome_item.setForeground(QColor(248, 250, 252))
            self.table.setItem(i, 1, nome_item)

            v_old_item = QTableWidgetItem(v_old)
            v_old_item.setForeground(QColor(148, 163, 184))
            self.table.setItem(i, 2, v_old_item)

            v_new_item = QTableWidgetItem(v_new)
            v_new_item.setForeground(QColor(52, 211, 153))
            self.table.setItem(i, 3, v_new_item)

        self.table.setSpan(0, 0, 1, 1)
        self.lbl_count.setText(f"📦 {len(self._upgradable_data)} pacote(s) disponível(is) para atualização.")
        self.btn_apply.setEnabled(True)

    def _apply_selected(self):
        """Instala os pacotes selecionados na tabela."""
        selected = []
        for i in range(self.table.rowCount()):
            cb = self.table.cellWidget(i, 0)
            if cb and cb.isChecked():
                pacote = self.table.item(i, 1).text()
                selected.append(pacote)

        if not selected:
            QMessageBox.information(
                self, "Nada Selecionado",
                "Marque ao menos um pacote na tabela para atualizar."
            )
            return

        pacotes_str = " ".join(selected)
        resposta = QMessageBox.question(
            self, "🔄 Atualizar Pacotes",
            f"Deseja atualizar {len(selected)} pacote(s)?\n\n"
            f"{', '.join(selected[:8])}{'...' if len(selected) > 8 else ''}",
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if resposta == QMessageBox.Yes:
            env = os.environ.copy()
            env["DEBIAN_FRONTEND"] = "noninteractive"
            try:
                resultado = subprocess.run(
                    f"apt install --only-upgrade -y {pacotes_str}",
                    shell=True, env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    text=True
                )
                saida = resultado.stdout if resultado.returncode == 0 else resultado.stderr
                dialog = ResultDialog("Atualização Concluída", saida, self)
                dialog.exec_()
                self._scan_updates()
            except Exception as e:
                QMessageBox.critical(self, "Erro", f"Ocorreu um erro:\n{str(e)}")


# ──────────────────────────────────────────────────────────────
#  Janela principal
# ──────────────────────────────────────────────────────────────
class FydelisPackageManager(QMainWindow):
    def __init__(self):
        super().__init__()
        self._setup_window()
        self._build_ui()

    def _setup_window(self):
        self.setWindowTitle("Gerenciador de Pacotes — FydelisTechOS")
        self.setMinimumSize(560, 780)
        self.resize(600, 840)
        self.setAttribute(Qt.WA_TranslucentBackground, False)

    def _build_ui(self):
        # ── Widget central com gradiente animado ──
        self.central = AnimatedBackground(self)
        self.setCentralWidget(self.central)

        # Scroll area para suportar telas pequenas
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)

        # Widget interno do scroll
        scroll_content = QWidget()
        scroll_content.setStyleSheet("background: transparent;")

        outer = QVBoxLayout(scroll_content)
        outer.setContentsMargins(20, 20, 20, 20)

        # ── Card principal ──
        card = QFrame()
        card.setStyleSheet("""
            QFrame {
                background-color: rgba(15, 23, 42, 200);
                border-radius: 20px;
                border: 1px solid rgba(106, 17, 203, 80);
            }
        """)
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(24, 20, 24, 20)
        card_layout.setSpacing(8)

        # ── Header ──
        header = QHBoxLayout()
        icon_label = QLabel("🛡️")
        icon_label.setFont(QFont("Segoe UI", 28))
        header.addWidget(icon_label)

        title_block = QVBoxLayout()
        title_block.setSpacing(2)
        title = QLabel("Gerenciador de Pacotes")
        title.setFont(QFont("Segoe UI", 18, QFont.Bold))
        title.setStyleSheet("color: #F8FAFC;")
        title_block.addWidget(title)
        subtitle = QLabel("FydelisTechOS • APT Frontend")
        subtitle.setFont(QFont("Segoe UI", 10))
        subtitle.setStyleSheet("color: #94A3B8;")
        title_block.addWidget(subtitle)
        header.addLayout(title_block, 1)
        card_layout.addLayout(header)

        # ── Separador ──
        sep = QFrame()
        sep.setFrameShape(QFrame.HLine)
        sep.setStyleSheet("border: none; border-top: 1px solid #334155;")
        sep.setMaximumHeight(1)
        card_layout.addWidget(sep)

        card_layout.addSpacing(4)

        # ── Botões de ação ──
        btns_data = [
            ("🔄   Atualizar Lista de Pacotes", self.atualizar_lista, "#6A11CB", "#22D3EE"),
            ("📥   Instalar Pacote",            self.instalar_pacote, "#7C3AED", "#22D3EE"),
            ("🗑️   Remover Pacote",             self.remover_pacote,  "#DC2626", "#F87171"),
            ("⬆️   Atualizar Sistema Completo", self.upgrade_sistema, "#2563EB", "#60A5FA"),
            ("🔍   Procurar Pacote",            self.procurar_pacote, "#0D9488", "#2DD4BF"),
        ]
        for text, slot, accent, hover in btns_data:
            btn = ModernButton(text, accent_color=accent, hover_color=hover)
            btn.clicked.connect(slot)
            card_layout.addWidget(btn)

        # ── Grid de Atualizações ──
        self.update_grid = UpdateGridWidget()
        card_layout.addWidget(self.update_grid)

        # ── Botão Sair ──
        btn_sair = QPushButton("✕   Sair")
        btn_sair.setMinimumHeight(46)
        btn_sair.setCursor(Qt.PointingHandCursor)
        btn_sair.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                color: #EF4444;
                border: 2px solid #EF4444;
                border-radius: 12px;
                font-size: 13px;
                font-weight: bold;
                padding: 10px;
            }
            QPushButton:hover {
                background-color: #EF4444;
                color: #FFFFFF;
            }
        """)
        btn_sair.clicked.connect(self.close)
        card_layout.addWidget(btn_sair)

        outer.addWidget(card)
        outer.addStretch()

        scroll.setWidget(scroll_content)
        self.central_layout = QVBoxLayout(self.central)
        self.central_layout.setContentsMargins(0, 0, 0, 0)
        self.central_layout.addWidget(scroll)

        # ── Status bar ──
        self.statusBar().setStyleSheet("""
            QStatusBar {
                background-color: #0F172A;
                color: #64748B;
                font-size: 11px;
                border-top: 1px solid #1E293B;
                padding: 4px 12px;
            }
        """)
        self.statusBar().showMessage("✅ Pronto — aguardando comando...")

    # ──────────────────────────────────────────────────────────
    #  Lógica dos comandos
    # ──────────────────────────────────────────────────────────
    def executar_comando(self, comando, titulo):
        env = os.environ.copy()
        env["DEBIAN_FRONTEND"] = "noninteractive"

        self.statusBar().showMessage(f"⏳ Executando: {comando[:50]}...")
        QApplication.processEvents()

        try:
            resultado = subprocess.run(
                comando, shell=True, env=env,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
            )
            saida = resultado.stdout if resultado.returncode == 0 else resultado.stderr
            self.mostrar_resultado(titulo, saida)
            self.statusBar().showMessage(f"✅ {titulo} concluído — código {resultado.returncode}")
        except Exception as e:
            QMessageBox.critical(self, "Erro", f"Ocorreu um erro ao executar:\n{str(e)}")
            self.statusBar().showMessage("❌ Erro na execução")

    def mostrar_resultado(self, titulo, texto):
        dialog = ResultDialog(titulo, texto, self)
        dialog.exec_()

    def atualizar_lista(self):
        self.executar_comando("apt update", "Atualizar Lista")

    def instalar_pacote(self):
        pacote, ok = QInputDialog.getText(
            self, "📥 Instalar Pacote", "Digite o nome do pacote para instalar:"
        )
        if ok and pacote.strip():
            self.executar_comando(f"apt install -y {pacote.strip()}", f"Instalar {pacote.strip()}")

    def remover_pacote(self):
        pacote, ok = QInputDialog.getText(
            self, "🗑️ Remover Pacote", "Digite o nome do pacote para remover:"
        )
        if ok and pacote.strip():
            self.executar_comando(f"apt remove -y {pacote.strip()}", f"Remover {pacote.strip()}")

    def upgrade_sistema(self):
        resposta = QMessageBox.question(
            self, "⬆️ Atualização Completa",
            "Deseja realizar o full-upgrade do sistema?\n\nIsso instalará todas as atualizações disponíveis.",
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if resposta == QMessageBox.Yes:
            self.executar_comando("apt full-upgrade -y", "Atualização Completa do Sistema")
            self.update_grid._scan_updates()

    def procurar_pacote(self):
        termo, ok = QInputDialog.getText(
            self, "🔍 Procurar Pacote", "Digite o termo de busca:"
        )
        if ok and termo.strip():
            self.executar_comando(f"apt search {termo.strip()}", f"Busca por '{termo.strip()}'")


# ──────────────────────────────────────────────────────────────
#  Entry point
# ──────────────────────────────────────────────────────────────
if __name__ == '__main__':
    # Validação de root apenas no Linux
    if os.name == 'posix' and os.geteuid() != 0:
        print("❌ Erro: Este gerenciador de pacotes gráfico precisa ser executado como ROOT (sudo).")
        sys.exit(1)

    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    palette = QPalette()
    palette.setColor(QPalette.Window, QColor(15, 23, 42))
    palette.setColor(QPalette.WindowText, QColor(248, 250, 252))
    palette.setColor(QPalette.Base, QColor(30, 41, 59))
    palette.setColor(QPalette.Text, QColor(226, 232, 240))
    palette.setColor(QPalette.Button, QColor(106, 17, 203))
    palette.setColor(QPalette.ButtonText, QColor(255, 255, 255))
    palette.setColor(QPalette.Highlight, QColor(34, 211, 238))
    palette.setColor(QPalette.HighlightedText, QColor(15, 23, 42))
    app.setPalette(palette)

    ex = FydelisPackageManager()
    ex.show()
    sys.exit(app.exec_())