#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FydelisSynaptic.py - Gerenciador de Pacotes Estilo Synaptic para FydelisTechOS
Versão 2.0 — Correção do QThread
"""

import sys
import os
import subprocess
import re
import threading
from functools import partial
from collections import OrderedDict

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QTableWidget, QTableWidgetItem, QSplitter,
    QListWidget, QLineEdit, QMessageBox, QHeaderView, QCheckBox,
    QFrame, QTextEdit, QDialog, QProgressBar, QComboBox, QGroupBox,
    QGridLayout, QMenu, QAction, QStatusBar, QToolBar, QTabWidget,
    QAbstractItemView, QListWidgetItem, QStyleFactory, QSizePolicy,
    QSpacerItem, QInputDialog
)
from PyQt5.QtCore import (
    Qt, QTimer, QSize, QThread, pyqtSignal, pyqtSlot, QObject, QEventLoop
)
from PyQt5.QtGui import (
    QFont, QColor, QPalette, QIcon, QPixmap, QPainter,
    QLinearGradient, QBrush, QFontDatabase
)


# ═══════════════════════════════════════════════════════════════
#  WORKER — Executa comandos APT em thread separada (robusto)
# ═══════════════════════════════════════════════════════════════
class AptWorker(QObject):
    finished = pyqtSignal(str, int)
    progress = pyqtSignal(str)

    def __init__(self, command, timeout=300):
        super().__init__()
        self.command = command
        self.timeout = timeout

    def run(self):
        try:
            env = os.environ.copy()
            env["DEBIAN_FRONTEND"] = "noninteractive"
            self.progress.emit(f"Executando: {self.command[:80]}...")

            proc = subprocess.run(
                self.command,
                shell=True,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=self.timeout
            )
            output = proc.stdout if proc.returncode == 0 else proc.stderr
            self.finished.emit(output, proc.returncode)
        except subprocess.TimeoutExpired:
            self.finished.emit("⏱️ Comando excedeu o tempo limite.", -1)
        except Exception as e:
            self.finished.emit(f"❌ Erro: {str(e)}", -1)


# ═══════════════════════════════════════════════════════════════
#  DIALOG — Exibe saída de comandos
# ═══════════════════════════════════════════════════════════════
class OutputDialog(QDialog):
    def __init__(self, title, text, parent=None):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setMinimumSize(700, 450)
        self.setStyleSheet("""
            QDialog { background-color: #0F172A; border-radius: 12px; }
            QLabel { color: #F8FAFC; font-size: 13px; font-weight: bold; }
            QTextEdit {
                background-color: #0B0F19; color: #E2E8F0;
                border: 1px solid #1E293B; border-radius: 8px;
                font-family: 'Consolas', 'Courier New', monospace;
                font-size: 11px; padding: 10px;
            }
            QPushButton {
                background-color: #1E293B; color: #22D3EE;
                border: 1px solid #334155; border-radius: 6px;
                padding: 8px 20px; font-weight: bold;
            }
            QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
        """)
        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)
        layout.addWidget(QLabel(f"📄 {title}"))
        self.txt = QTextEdit()
        self.txt.setReadOnly(True)
        self.txt.setPlainText(text if text else "Nenhuma saída.")
        layout.addWidget(self.txt)
        btn = QPushButton("✕ Fechar")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn, alignment=Qt.AlignRight)
        self.setLayout(layout)


# ═══════════════════════════════════════════════════════════════
#  JANELA PRINCIPAL — Synaptic Style
# ═══════════════════════════════════════════════════════════════
class FydelisSynaptic(QMainWindow):
    def __init__(self):
        super().__init__()
        self._all_packages = []
        self._filtered_packages = []
        self._marked_for_install = set()
        self._marked_for_remove = set()
        self._current_category = "all"

        # ── Referências para threads (evita garbage collection) ──
        self._load_thread = None
        self._action_threads = []

        self._setup_window()
        self._build_ui()
        self._load_packages_async()

    def _setup_window(self):
        self.setWindowTitle("Fydelis Package Manager — Synaptic Style")
        self.setMinimumSize(900, 600)
        self.resize(1100, 700)

    def _build_ui(self):
        cw = QWidget()
        self.setCentralWidget(cw)
        main_layout = QVBoxLayout(cw)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # ── PALETA ESCURA ──
        palette = QPalette()
        palette.setColor(QPalette.Window, QColor(15, 23, 42))
        palette.setColor(QPalette.WindowText, QColor(248, 250, 252))
        palette.setColor(QPalette.Base, QColor(11, 15, 25))
        palette.setColor(QPalette.Text, QColor(226, 232, 240))
        palette.setColor(QPalette.Button, QColor(22, 30, 56))
        palette.setColor(QPalette.ButtonText, QColor(248, 250, 252))
        palette.setColor(QPalette.Highlight, QColor(106, 17, 203))
        palette.setColor(QPalette.HighlightedText, QColor(255, 255, 255))
        palette.setColor(QPalette.Light, QColor(30, 41, 59))
        palette.setColor(QPalette.Midlight, QColor(22, 30, 56))
        palette.setColor(QPalette.Mid, QColor(15, 23, 42))
        palette.setColor(QPalette.Dark, QColor(11, 15, 25))
        self.setPalette(palette)

        # ════════════════════════════════════════════════
        #  TOOLBAR
        # ════════════════════════════════════════════════
        toolbar = QToolBar()
        toolbar.setMovable(False)
        toolbar.setStyleSheet("""
            QToolBar {
                background-color: #0F172A;
                border-bottom: 1px solid #1E293B;
                padding: 4px 8px; spacing: 6px;
            }
            QPushButton {
                background-color: #1E293B; color: #22D3EE;
                border: 1px solid #334155; border-radius: 5px;
                padding: 6px 14px; font-size: 11px; font-weight: bold;
            }
            QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
            QPushButton:disabled {
                background-color: #0F172A; color: #475569; border-color: #1E293B;
            }
        """)
        self.addToolBar(toolbar)

        btn_reload = QPushButton("🔄 Recarregar")
        btn_reload.clicked.connect(self._reload_packages)
        toolbar.addWidget(btn_reload)

        btn_mark_install = QPushButton("📥 Marcar p/ Instalar")
        btn_mark_install.clicked.connect(self._mark_selected_for_install)
        toolbar.addWidget(btn_mark_install)

        btn_mark_remove = QPushButton("🗑️ Marcar p/ Remover")
        btn_mark_remove.clicked.connect(self._mark_selected_for_remove)
        toolbar.addWidget(btn_mark_remove)

        btn_apply = QPushButton("⚡ Aplicar")
        btn_apply.setStyleSheet("""
            QPushButton {
                background-color: #6A11CB; color: #FFFFFF;
                border: none; border-radius: 5px;
                padding: 6px 18px; font-size: 11px; font-weight: bold;
            }
            QPushButton:hover { background-color: #8B5CF6; }
        """)
        btn_apply.clicked.connect(self._apply_changes)
        toolbar.addWidget(btn_apply)

        toolbar.addSeparator()

        btn_properties = QPushButton("📋 Propriedades")
        btn_properties.clicked.connect(self._show_properties)
        toolbar.addWidget(btn_properties)

        btn_search_apt = QPushButton("🔍 Buscar no APT")
        btn_search_apt.clicked.connect(self._search_apt_repos)
        toolbar.addWidget(btn_search_apt)

        toolbar.addSeparator()
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        toolbar.addWidget(spacer)

        self.search_box = QLineEdit()
        self.search_box.setPlaceholderText("🔍 Buscar pacotes...")
        self.search_box.setFixedWidth(260)
        self.search_box.setStyleSheet("""
            QLineEdit {
                background-color: #0B0F19; color: #F8FAFC;
                border: 1px solid #1E293B; border-radius: 5px;
                padding: 5px 10px; font-size: 12px;
            }
        """)
        self.search_box.textChanged.connect(self._on_search_changed)
        toolbar.addWidget(self.search_box)

        # ════════════════════════════════════════════════
        #  SPLITTER
        # ════════════════════════════════════════════════
        splitter = QSplitter(Qt.Horizontal)
        splitter.setStyleSheet("QSplitter::handle { background-color: #1E293B; width: 2px; }")

        # ── Painel Esquerdo ──
        left_widget = QWidget()
        left_layout = QVBoxLayout(left_widget)
        left_layout.setContentsMargins(6, 6, 6, 6)
        left_layout.setSpacing(6)

        lbl_sections = QLabel("📂 SEÇÕES")
        lbl_sections.setStyleSheet("color: #64748B; font-size: 10px; font-weight: bold; letter-spacing: 1px;")
        left_layout.addWidget(lbl_sections)

        self.section_list = QListWidget()
        self.section_list.setStyleSheet("""
            QListWidget {
                background-color: #0B0F19; color: #94A3B8;
                border: 1px solid #1E293B; border-radius: 6px;
                font-size: 12px;
            }
            QListWidget::item { padding: 6px 8px; }
            QListWidget::item:selected {
                background-color: #6A11CB; color: #FFFFFF; border-radius: 4px;
            }
            QListWidget::item:hover { background-color: #1E293B; color: #F8FAFC; }
        """)
        self.section_list.currentRowChanged.connect(self._on_section_changed)
        left_layout.addWidget(self.section_list)

        btn_edit_sections = QPushButton("✏️ Personalizar Seções")
        btn_edit_sections.setStyleSheet("""
            QPushButton {
                background-color: transparent; color: #64748B;
                border: 1px dashed #334155; border-radius: 4px;
                padding: 4px; font-size: 10px;
            }
            QPushButton:hover { color: #22D3EE; border-color: #22D3EE; }
        """)
        btn_edit_sections.clicked.connect(lambda: QMessageBox.information(
            self, "Personalizar Seções",
            "Funcionalidade disponível na versão Pro.\n\n"
            "As seções são detectadas automaticamente dos pacotes Debian."
        ))
        left_layout.addWidget(btn_edit_sections)

        btn_clear = QPushButton("⟲ Limpar Filtros")
        btn_clear.setStyleSheet("""
            QPushButton {
                background-color: transparent; color: #EF4444;
                border: 1px solid #EF4444; border-radius: 4px;
                padding: 4px; font-size: 10px; font-weight: bold;
            }
            QPushButton:hover { background-color: #EF4444; color: #FFFFFF; }
        """)
        btn_clear.clicked.connect(self._clear_filters)
        left_layout.addWidget(btn_clear)

        splitter.addWidget(left_widget)

        # ── Painel Central ──
        center_widget = QWidget()
        center_layout = QVBoxLayout(center_widget)
        center_layout.setContentsMargins(4, 4, 4, 4)
        center_layout.setSpacing(4)

        self.info_label = QLabel("Carregando pacotes...")
        self.info_label.setStyleSheet("color: #64748B; font-size: 11px; padding: 2px 4px;")
        center_layout.addWidget(self.info_label)

        view_opts = QHBoxLayout()
        self.combo_status_filter = QComboBox()
        self.combo_status_filter.addItems([
            "Todos os Pacotes", "Instalados", "Não Instalados",
            "Atualizáveis", "Marcados p/ Instalar", "Marcados p/ Remover"
        ])
        self.combo_status_filter.setStyleSheet("""
            QComboBox {
                background-color: #0B0F19; color: #F8FAFC;
                border: 1px solid #1E293B; border-radius: 4px;
                padding: 4px 8px; font-size: 11px;
            }
            QComboBox::drop-down { border: none; background: #1E293B; border-radius: 4px; }
        """)
        self.combo_status_filter.currentIndexChanged.connect(self._on_filter_changed)
        view_opts.addWidget(QLabel("Status:"))
        view_opts.addWidget(self.combo_status_filter)

        self.btn_select_all = QPushButton("☐ Selecionar Tudo")
        self.btn_select_all.setStyleSheet("""
            QPushButton { background-color: transparent; color: #64748B; border: none; font-size: 11px; }
            QPushButton:hover { color: #22D3EE; }
        """)
        self.btn_select_all.clicked.connect(lambda: self.table.selectAll() if self.table.rowCount() > 0 else None)
        view_opts.addWidget(self.btn_select_all)

        view_opts.addStretch()
        center_layout.addLayout(view_opts)

        # Tabela
        self.table = QTableWidget()
        self.table.setColumnCount(7)
        self.table.setHorizontalHeaderLabels([
            "S", "Pacote", "Versão Instalada", "Versão Disponível",
            "Seção", "Tamanho", "Descrição"
        ])
        self.table.setColumnWidth(0, 28)
        self.table.setColumnWidth(1, 200)
        self.table.setColumnWidth(2, 120)
        self.table.setColumnWidth(3, 120)
        self.table.setColumnWidth(4, 100)
        self.table.setColumnWidth(5, 70)
        self.table.horizontalHeader().setSectionResizeMode(6, QHeaderView.Stretch)
        self.table.verticalHeader().setVisible(False)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.table.setAlternatingRowColors(True)
        self.table.setSortingEnabled(True)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.setStyleSheet("""
            QTableWidget {
                background-color: #0B0F19; color: #E2E8F0;
                border: 1px solid #1E293B; border-radius: 6px;
                gridline-color: #1E293B; font-size: 11px;
            }
            QTableWidget::item { padding: 4px 6px; }
            QTableWidget::item:selected { background-color: #6A11CB; color: #FFFFFF; }
            QHeaderView::section {
                background-color: #161E38; color: #22D3EE;
                padding: 5px 4px; border: 1px solid #1E293B;
                font-size: 10px; font-weight: bold;
            }
        """)
        self.table.cellDoubleClicked.connect(self._on_package_double_click)
        center_layout.addWidget(self.table)
        splitter.addWidget(center_widget)

        # ── Painel Direito ──
        right_widget = QWidget()
        right_layout = QVBoxLayout(right_widget)
        right_layout.setContentsMargins(6, 6, 6, 6)
        right_layout.setSpacing(6)

        lbl_details = QLabel("📋 DETALHES")
        lbl_details.setStyleSheet("color: #64748B; font-size: 10px; font-weight: bold; letter-spacing: 1px;")
        right_layout.addWidget(lbl_details)

        self.detail_tabs = QTabWidget()
        self.detail_tabs.setStyleSheet("""
            QTabWidget::pane { background-color: #0B0F19; border: 1px solid #1E293B; border-radius: 6px; }
            QTabBar::tab { background-color: #0F172A; color: #64748B; padding: 6px 12px; border: none; font-size: 10px; }
            QTabBar::tab:selected { background-color: #6A11CB; color: #FFFFFF; border-radius: 4px 4px 0 0; }
        """)

        self.info_tab = QTextEdit()
        self.info_tab.setReadOnly(True)
        self.info_tab.setStyleSheet("""
            QTextEdit { background-color: transparent; color: #E2E8F0; border: none; font-size: 11px; font-family: 'Consolas', monospace; }
        """)
        self.info_tab.setText("Selecione um pacote na tabela\npara ver seus detalhes.")
        self.detail_tabs.addTab(self.info_tab, "Info")

        self.desc_tab = QTextEdit()
        self.desc_tab.setReadOnly(True)
        self.desc_tab.setStyleSheet("""
            QTextEdit { background-color: transparent; color: #E2E8F0; border: none; font-size: 11px; }
        """)
        self.desc_tab.setText("Selecione um pacote para ver\na descrição completa.")
        self.detail_tabs.addTab(self.desc_tab, "Descrição")

        self.scripts_tab = QTextEdit()
        self.scripts_tab.setReadOnly(True)
        self.scripts_tab.setStyleSheet("""
            QTextEdit { background-color: transparent; color: #94A3B8; border: none; font-size: 10px; font-family: 'Consolas', monospace; }
        """)
        self.scripts_tab.setText("Scripts mantenedores disponíveis\npara pacotes instalados.")
        self.detail_tabs.addTab(self.scripts_tab, "Scripts")

        right_layout.addWidget(self.detail_tabs)

        gb_actions = QGroupBox("Ações")
        gb_actions.setStyleSheet("""
            QGroupBox {
                color: #64748B; font-size: 10px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 6px;
                margin-top: 12px; padding: 12px 8px 8px 8px;
            }
            QGroupBox::title {
                subcontrol-origin: margin; subcontrol-position: top left;
                padding: 2px 8px; color: #64748B;
            }
            QPushButton { background-color: #1E293B; color: #F8FAFC; border: 1px solid #334155; border-radius: 4px; padding: 5px; font-size: 10px; }
            QPushButton:hover { background-color: #6A11CB; }
        """)
        actions_layout = QGridLayout(gb_actions)
        actions_layout.setSpacing(4)

        btn_inst = QPushButton("📥 Instalar")
        btn_inst.clicked.connect(lambda: self._quick_action("install"))
        actions_layout.addWidget(btn_inst, 0, 0)

        btn_rem = QPushButton("🗑️ Remover")
        btn_rem.clicked.connect(lambda: self._quick_action("remove"))
        actions_layout.addWidget(btn_rem, 0, 1)

        btn_purge = QPushButton("🔥 Purgar")
        btn_purge.clicked.connect(lambda: self._quick_action("purge"))
        actions_layout.addWidget(btn_purge, 1, 0)

        btn_reinst = QPushButton("🔄 Reinstalar")
        btn_reinst.clicked.connect(lambda: self._quick_action("reinstall"))
        actions_layout.addWidget(btn_reinst, 1, 1)

        btn_info = QPushButton("📋 Detalhes APT")
        btn_info.clicked.connect(lambda: self._quick_action("show"))
        actions_layout.addWidget(btn_info, 2, 0, 1, 2)

        right_layout.addWidget(gb_actions)
        splitter.addWidget(right_widget)

        splitter.setSizes([180, 650, 250])
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setStretchFactor(2, 0)

        main_layout.addWidget(splitter)

        # ── Status Bar ──
        self.status_bar = QStatusBar()
        self.status_bar.setStyleSheet("""
            QStatusBar {
                background-color: #0F172A; color: #64748B;
                border-top: 1px solid #1E293B; font-size: 11px; padding: 2px 10px;
            }
        """)
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("✅ Pronto — aguardando dados do sistema...")

        # ── Popula seções ──
        self._populate_sections()

    # ══════════════════════════════════════════════════════════
    #  SEÇÕES
    # ══════════════════════════════════════════════════════════
    def _populate_sections(self):
        self.section_list.blockSignals(True)
        self.section_list.clear()

        sections = [
            ("📁 Todos os Pacotes", "all"),
            ("✅ Instalados", "installed"),
            ("⬜ Não Instalados", "not_installed"),
            ("↗️ Atualizáveis", "upgradable"),
            ("📦 Marcados p/ Instalar", "marked_install"),
            ("🗑️ Marcados p/ Remover", "marked_remove"),
        ] + [
            ("🌐 Internet & Rede", "net"),
            ("🛡️ Segurança", "security"),
            ("💻 Desenvolvimento", "devel"),
            ("🎮 Multimídia", "multimedia"),
            ("⚙️ Sistema Base", "base"),
            ("📚 Bibliotecas", "libs"),
            ("🖥️ Interface Gráfica", "x11"),
            ("🔧 Utilitários", "utils"),
            ("📡 Comunicação", "comm"),
            ("🗄️ Banco de Dados", "database"),
            ("☁️ Cloud & Virtualização", "virtualization"),
        ]

        for text, data in sections:
            item = QListWidgetItem(text)
            item.setData(Qt.UserRole, data)
            self.section_list.addItem(item)

        self.section_list.blockSignals(False)
        self.section_list.setCurrentRow(0)

    # ══════════════════════════════════════════════════════════
    #  CARREGAMENTO DE PACOTES (CORRIGIDO — sem QThread crash)
    # ══════════════════════════════════════════════════════════
    def _load_packages_async(self):
        """Carrega pacotes usando QThread com gerenciamento de ciclo de vida."""
        self.status_bar.showMessage("🔄 Carregando pacotes do sistema...")
        self.info_label.setText("Carregando pacotes...")

        # Se houver uma thread de load anterior, espera terminar
        if self._load_thread and self._load_thread.isRunning():
            self._load_thread.quit()
            self._load_thread.wait(3000)

        # Cria nova thread e worker
        self._load_thread = QThread(self)  # ← parent=self evita GC prematuro
        worker = QObject()

        # Move worker para a thread
        worker.moveToThread(self._load_thread)

        # Conecta sinais
        self._load_thread.started.connect(lambda: self._do_load_packages(worker))
        self._load_thread.finished.connect(self._on_load_finished)

        # Garante que a thread se limpe ao finalizar
        self._load_thread.finished.connect(self._load_thread.deleteLater)

        worker.destroyed.connect(self._load_thread.quit)

        self._load_thread.start()

    def _do_load_packages(self, worker):
        """Executa na thread secundária — busca pacotes reais do sistema."""
        packages = self._fetch_real_packages()
        # Armazena resultado no worker para acesso posterior
        worker._result = packages
        # Volta para a thread principal chamando o finished via signal
        # Como não temos signal customizado aqui, usamos QMetaObject.invokeMethod
        # Mas o mais simples: usa QTimer.singleShot para chamar na main thread
        from PyQt5.QtCore import QMetaObject, Q_ARG, Qt
        QMetaObject.invokeMethod(
            self, "_on_load_data_ready",
            Qt.QueuedConnection,
            Q_ARG(object, packages)
        )

    # Precisa ser um slot para aceitar Q_ARG(object)
    @pyqtSlot(object)
    def _on_load_data_ready(self, packages):
        """Recebe os dados na thread principal e finaliza."""
        self._all_packages = list(packages)
        self._filtered_packages = list(self._all_packages)
        self._refresh_table()
        self._update_info()
        self.status_bar.showMessage(f"✅ {len(self._all_packages)} pacotes carregados do sistema.")

        # Finaliza a thread
        if self._load_thread:
            self._load_thread.quit()

    def _on_load_finished(self):
        """Callback quando a thread termina."""
        self._load_thread = None

    def _fetch_real_packages(self):
        """Retorna lista real de pacotes do sistema (executado na thread secundária)."""
        packages = []

        try:
            # ── 1. Pacotes instalados via dpkg-query ──
            dpkg_out = subprocess.run(
                "dpkg-query -W -f='${Package}|${Version}|${Section}|${Installed-Size}|${Status}|${Description}\\n' 2>/dev/null",
                shell=True, capture_output=True, text=True, timeout=60
            )

            installed_map = OrderedDict()
            for line in dpkg_out.stdout.strip().split('\n'):
                if not line.strip():
                    continue
                parts = line.strip().split('|')
                if len(parts) >= 5:
                    name = parts[0].strip()
                    vers = parts[1].strip()
                    sect = parts[2].strip() if len(parts) > 2 else "unknown"
                    size = parts[3].strip() if len(parts) > 3 else "0"
                    desc = parts[5].strip() if len(parts) > 5 else ""
                    installed_map[name] = (vers, sect, size, desc)

            # ── 2. Pacotes disponíveis via apt-cache ──
            cache_out = subprocess.run(
                "apt-cache pkgnames 2>/dev/null | head -4000",
                shell=True, capture_output=True, text=True, timeout=120
            )
            available_names = set(cache_out.stdout.strip().split('\n'))

            # ── 3. Atualizáveis ──
            upgradable = set()
            upg_out = subprocess.run(
                "apt list --upgradable 2>/dev/null",
                shell=True, capture_output=True, text=True, timeout=30
            )
            for line in upg_out.stdout.strip().split('\n'):
                if '/now' in line:
                    name = line.split('/')[0]
                    upgradable.add(name)

            # ── 4. Para cada pacote disponível, coleta info do cache ──
            cache_details = {}
            if available_names:
                # Pega info em lote
                for chunk in self._chunks(list(available_names)[:3000], 200):
                    names_str = '|'.join(chunk)
                    cache_out2 = subprocess.run(
                        f"apt-cache show {names_str} 2>/dev/null | "
                        f"grep -E '^(Package|Version|Description-en|Description|Section|Installed-Size):' | head -5000",
                        shell=True, capture_output=True, text=True, timeout=60
                    )
                    current_pkg = None
                    for line in cache_out2.stdout.strip().split('\n'):
                        if line.startswith('Package:'):
                            current_pkg = line.split(':', 1)[1].strip()
                            if current_pkg not in cache_details:
                                cache_details[current_pkg] = {}
                        elif line.startswith('Version:') and current_pkg:
                            cache_details[current_pkg]['vers'] = line.split(':', 1)[1].strip()
                        elif line.startswith('Description-en:') and current_pkg:
                            cache_details[current_pkg]['desc'] = line.split(':', 1)[1].strip()
                        elif line.startswith('Description:') and current_pkg and 'desc' not in cache_details.get(current_pkg, {}):
                            cache_details[current_pkg]['desc'] = line.split(':', 1)[1].strip()
                        elif line.startswith('Section:') and current_pkg:
                            cache_details[current_pkg]['sect'] = line.split(':', 1)[1].strip()
                        elif line.startswith('Installed-Size:') and current_pkg:
                            cache_details[current_pkg]['size'] = line.split(':', 1)[1].strip()

            # ── 5. Monta lista final ──
            all_names = set(list(installed_map.keys()) + list(cache_details.keys()))
            all_names = sorted(all_names)

            count = 0
            for name in all_names:
                if count >= 3000:
                    break
                count += 1

                is_installed = name in installed_map
                is_upgradable = name in upgradable

                if is_installed:
                    inst_ver = installed_map[name][0]
                    sect = installed_map[name][1] if installed_map[name][1] != "unknown" else \
                           cache_details.get(name, {}).get('sect', 'unknown')
                    size = installed_map[name][2]
                    desc = installed_map[name][3] if installed_map[name][3] else \
                           cache_details.get(name, {}).get('desc', '')
                    disp_ver = cache_details.get(name, {}).get('vers', inst_ver)

                    if is_upgradable:
                        status = "↗️"
                    else:
                        status = "✅"
                else:
                    inst_ver = ""
                    sect = cache_details.get(name, {}).get('sect', 'unknown')
                    size = cache_details.get(name, {}).get('size', '0')
                    desc = cache_details.get(name, {}).get('desc', '')
                    disp_ver = cache_details.get(name, {}).get('vers', '')
                    status = "⬜"

                packages.append((
                    status, name, inst_ver, disp_ver,
                    sect, size, desc[:150]
                ))

        except Exception as e:
            self.status_bar.showMessage(f"⚠️ Usando dados simulados: {str(e)}")
            # Fallback
            packages = [
                ("✅", "fydelis-ai", "2.0.0", "2.1.0", "admin", "12400", "Assistente de IA local"),
                ("✅", "nmap", "7.93", "7.95", "net", "8500", "Scanner de rede"),
                ("⬜", "metasploit-framework", "", "6.3.0", "security", "350000", "Framework de exploração"),
                ("↗️", "hydra", "9.4", "9.6", "security", "3400", "Login brute-forcer"),
                ("✅", "wireshark", "4.0.5", "4.0.8", "net", "28000", "Analisador de protocolos"),
                ("⬜", "john", "", "1.9.0", "security", "5600", "John the Ripper"),
                ("✅", "python3", "3.11.2", "3.11.5", "interpreters", "45000", "Linguagem Python"),
                ("⬜", "burpsuite", "", "2023.1", "security", "280000", "Proxy de interceptação web"),
                ("✅", "vim", "9.0.1", "9.0.5", "editors", "6500", "Editor de texto avançado"),
                ("⬜", "docker.io", "", "24.0.0", "virtualization", "120000", "Plataforma de containers"),
            ]

        return packages

    @staticmethod
    def _chunks(lst, n):
        """Divide uma lista em pedaços de tamanho n."""
        for i in range(0, len(lst), n):
            yield lst[i:i + n]

    # ══════════════════════════════════════════════════════════
    #  REFRESH DA TABELA
    # ══════════════════════════════════════════════════════════
    def _refresh_table(self, packages=None):
        if packages is None:
            packages = self._filtered_packages

        self.table.setSortingEnabled(False)
        self.table.setRowCount(len(packages))

        for row, (status, name, inst_ver, disp_ver, sect, size, desc) in enumerate(packages):
            status_item = QTableWidgetItem(status)
            status_item.setTextAlignment(Qt.AlignCenter)
            if status == "✅":
                status_item.setForeground(QColor(52, 211, 153))
            elif status == "↗️":
                status_item.setForeground(QColor(251, 191, 36))
            elif status == "⬜":
                status_item.setForeground(QColor(148, 163, 184))
            elif status == "📥":
                status_item.setForeground(QColor(96, 165, 250))
            elif status == "🗑️":
                status_item.setForeground(QColor(239, 68, 68))
            self.table.setItem(row, 0, status_item)

            name_item = QTableWidgetItem(name)
            name_item.setForeground(QColor(248, 250, 252))
            self.table.setItem(row, 1, name_item)

            ver_item = QTableWidgetItem(inst_ver)
            ver_item.setForeground(QColor(148, 163, 184))
            self.table.setItem(row, 2, ver_item)

            disp_item = QTableWidgetItem(disp_ver)
            disp_item.setForeground(QColor(52, 211, 153) if disp_ver and disp_ver != inst_ver else QColor(148, 163, 184))
            self.table.setItem(row, 3, disp_item)

            sect_item = QTableWidgetItem(sect)
            sect_item.setForeground(QColor(147, 197, 253))
            self.table.setItem(row, 4, sect_item)

            try:
                size_int = int(size)
                if size_int > 1024:
                    size_str = f"{size_int/1024:.1f} MB"
                else:
                    size_str = f"{size_int} kB"
            except:
                size_str = size
            size_item = QTableWidgetItem(size_str)
            size_item.setForeground(QColor(196, 181, 253))
            size_item.setTextAlignment(Qt.AlignRight | Qt.AlignVCenter)
            self.table.setItem(row, 5, size_item)

            desc_item = QTableWidgetItem(desc)
            desc_item.setForeground(QColor(148, 163, 184))
            self.table.setItem(row, 6, desc_item)

        self.table.setSortingEnabled(True)
        self._update_info()

    def _update_info(self):
        total = len(self._all_packages)
        filtered = len(self._filtered_packages)
        installed = sum(1 for p in self._all_packages if p[0] in ("✅", "↗️"))
        upgradable = sum(1 for p in self._all_packages if p[0] == "↗️")
        marked_i = len(self._marked_for_install)
        marked_r = len(self._marked_for_remove)

        info = f"📦 {total} pacotes no repositório  • ✅ {installed} instalados  • ↗️ {upgradable} atualizáveis  "
        if filtered != total:
            info += f"• 🔍 {filtered} filtrados  "
        if marked_i or marked_r:
            info += f"• 📥 {marked_i} marcar instalar  • 🗑️ {marked_r} marcar remover"

        self.info_label.setText(info)

    # ══════════════════════════════════════════════════════════
    #  FILTROS
    # ══════════════════════════════════════════════════════════
    def _on_search_changed(self, text):
        self._apply_filters()

    def _on_section_changed(self, index):
        if index < 0:
            return
        item = self.section_list.item(index)
        if item:
            section_data = item.data(Qt.UserRole)
            self._current_category = section_data
            self._apply_filters()

    def _on_filter_changed(self, index):
        self._apply_filters()

    def _apply_filters(self):
        search_text = self.search_box.text().lower().strip()
        status_filter = self.combo_status_filter.currentIndex()
        category = self._current_category

        filtered = list(self._all_packages)

        if category and category not in ("all", "installed", "not_installed",
                                          "upgradable", "marked_install", "marked_remove"):
            filtered = [p for p in filtered if p[4].lower() == category.lower() or
                        p[4].lower().startswith(category.lower())]

        if status_filter == 1:
            filtered = [p for p in filtered if p[0] in ("✅", "↗️")]
        elif status_filter == 2:
            filtered = [p for p in filtered if p[0] == "⬜"]
        elif status_filter == 3:
            filtered = [p for p in filtered if p[0] == "↗️"]
        elif status_filter == 4:
            filtered = [p for p in filtered if p[1] in self._marked_for_install]
        elif status_filter == 5:
            filtered = [p for p in filtered if p[1] in self._marked_for_remove]

        if category == "installed":
            filtered = [p for p in filtered if p[0] in ("✅", "↗️")]
        elif category == "not_installed":
            filtered = [p for p in filtered if p[0] == "⬜"]
        elif category == "upgradable":
            filtered = [p for p in filtered if p[0] == "↗️"]
        elif category == "marked_install":
            filtered = [p for p in filtered if p[1] in self._marked_for_install]
        elif category == "marked_remove":
            filtered = [p for p in filtered if p[1] in self._marked_for_remove]

        if search_text:
            filtered = [
                p for p in filtered
                if search_text in p[1].lower()
                or search_text in p[6].lower()
                or search_text in p[4].lower()
            ]

        self._filtered_packages = filtered
        self._refresh_table(filtered)

    def _clear_filters(self):
        self.search_box.clear()
        self.combo_status_filter.setCurrentIndex(0)
        self.section_list.setCurrentRow(0)
        self._apply_filters()

    # ══════════════════════════════════════════════════════════
    #  MARCAÇÃO
    # ══════════════════════════════════════════════════════════
    def _get_selected_packages(self):
        rows = set()
        for idx in self.table.selectedIndexes():
            rows.add(idx.row())
        return [self._filtered_packages[r][1] for r in rows]

    def _mark_selected_for_install(self):
        pkgs = self._get_selected_packages()
        if not pkgs:
            QMessageBox.information(self, "Nada Selecionado",
                                    "Selecione um ou mais pacotes na tabela.")
            return
        for p in pkgs:
            self._marked_for_install.add(p)
            self._marked_for_remove.discard(p)
            self._update_package_status(p, "📥")
        self._update_info()
        self.status_bar.showMessage(f"📥 {len(pkgs)} pacote(s) marcado(s) para instalação.")

    def _mark_selected_for_remove(self):
        pkgs = self._get_selected_packages()
        if not pkgs:
            QMessageBox.information(self, "Nada Selecionado",
                                    "Selecione um ou mais pacotes na tabela.")
            return
        for p in pkgs:
            self._marked_for_remove.add(p)
            self._marked_for_install.discard(p)
            self._update_package_status(p, "🗑️")
        self._update_info()
        self.status_bar.showMessage(f"🗑️ {len(pkgs)} pacote(s) marcado(s) para remoção.")

    def _update_package_status(self, pkg_name, new_status):
        for i in range(self.table.rowCount()):
            item = self.table.item(i, 1)
            if item and item.text() == pkg_name:
                self.table.item(i, 0).setText(new_status)
                if new_status == "📥":
                    self.table.item(i, 0).setForeground(QColor(96, 165, 250))
                elif new_status == "🗑️":
                    self.table.item(i, 0).setForeground(QColor(239, 68, 68))
                break

    # ══════════════════════════════════════════════════════════
    #  AÇÕES
    # ══════════════════════════════════════════════════════════
    def _quick_action(self, action):
        pkgs = self._get_selected_packages()
        if not pkgs:
            QMessageBox.information(self, "Nada Selecionado",
                                    "Selecione um pacote na tabela.")
            return

        pkg = pkgs[0]

        if action == "install":
            self._run_apt_command(f"apt install -y {pkg}", f"Instalando {pkg}")
        elif action == "remove":
            self._run_apt_command(f"apt remove -y {pkg}", f"Removendo {pkg}")
        elif action == "purge":
            self._run_apt_command(f"apt purge -y {pkg}", f"Purgando {pkg}")
        elif action == "reinstall":
            self._run_apt_command(f"apt install --reinstall -y {pkg}", f"Reinstalando {pkg}")
        elif action == "show":
            self._run_apt_command(f"apt show {pkg} 2>/dev/null || dpkg -p {pkg} 2>/dev/null",
                                  f"Detalhes de {pkg}")

    def _run_apt_command(self, cmd, title):
        """Executa comando APT em thread gerenciada."""
        self.status_bar.showMessage(f"⏳ {title}...")

        progress = QProgressBar(self)
        progress.setRange(0, 0)
        progress.setMaximumHeight(4)
        progress.setStyleSheet("""
            QProgressBar { border: none; background-color: #1E293B; border-radius: 2px; }
            QProgressBar::chunk { background-color: #6A11CB; border-radius: 2px; }
        """)
        self.statusBar().addPermanentWidget(progress, 1)

        # Cria thread e worker (com parent para evitar GC)
        thread = QThread(self)
        worker = AptWorker(cmd)
        worker.moveToThread(thread)

        # Armazena para evitar GC
        self._action_threads.append(thread)

        def on_finished(text, code):
            progress.setVisible(False)
            self.statusBar().removeWidget(progress)
            if code == 0:
                self.status_bar.showMessage(f"✅ {title} — concluído com sucesso.")
            else:
                self.status_bar.showMessage(f"❌ {title} — código {code}")
            dialog = OutputDialog(f"{'✅' if code==0 else '❌'} {title}", text, self)
            dialog.exec_()
            self._reload_packages()
            # Limpa referência
            thread.quit()
            thread.wait()
            if thread in self._action_threads:
                self._action_threads.remove(thread)

        thread.started.connect(worker.run)
        worker.finished.connect(on_finished)
        thread.finished.connect(thread.deleteLater)

        thread.start()

    def _apply_changes(self):
        to_install = list(self._marked_for_install)
        to_remove = list(self._marked_for_remove)

        if not to_install and not to_remove:
            QMessageBox.information(self, "Nada a Fazer",
                                    "Nenhuma alteração marcada.\n"
                                    "Use 'Marcar p/ Instalar' ou 'Marcar p/ Remover' primeiro.")
            return

        msg = "As seguintes alterações serão aplicadas:\n\n"
        if to_install:
            msg += f"📥 Instalar ({len(to_install)}):\n" + "\n".join(f"  • {p}" for p in to_install[:10])
            if len(to_install) > 10:
                msg += f"\n  ... e mais {len(to_install)-10}"
            msg += "\n\n"
        if to_remove:
            msg += f"🗑️ Remover ({len(to_remove)}):\n" + "\n".join(f"  • {p}" for p in to_remove[:10])
            if len(to_remove) > 10:
                msg += f"\n  ... e mais {len(to_remove)-10}"

        resposta = QMessageBox.question(
            self, "⚡ Aplicar Alterações", msg,
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )

        if resposta != QMessageBox.Yes:
            return

        cmd_parts = []
        if to_install:
            cmd_parts.append(f"apt install -y {' '.join(to_install)}")
        if to_remove:
            cmd_parts.append(f"apt remove -y {' '.join(to_remove)}")

        full_cmd = " && ".join(cmd_parts) if len(cmd_parts) > 1 else cmd_parts[0]
        self._run_apt_command(full_cmd, "Aplicando Alterações")

        self._marked_for_install.clear()
        self._marked_for_remove.clear()

    def _reload_packages(self):
        # Limpa marcações ao recarregar
        self._marked_for_install.clear()
        self._marked_for_remove.clear()
        self._load_packages_async()

    # ══════════════════════════════════════════════════════════
    #  DETALHES
    # ══════════════════════════════════════════════════════════
    def _on_package_double_click(self, row, col):
        if row < len(self._filtered_packages):
            pkg = self._filtered_packages[row]
            self._show_package_details(pkg[1])

    def _show_package_details(self, pkg_name):
        self.info_tab.setText(f"🔍 Carregando detalhes de {pkg_name}...")
        self.desc_tab.setText("")
        self.scripts_tab.setText("")

        try:
            result = subprocess.run(
                f"apt show {pkg_name} 2>/dev/null",
                shell=True, capture_output=True, text=True, timeout=15
            )
            apt_output = result.stdout if result.returncode == 0 else ""

            if not apt_output:
                result2 = subprocess.run(
                    f"dpkg -s {pkg_name} 2>/dev/null",
                    shell=True, capture_output=True, text=True, timeout=15
                )
                apt_output = result2.stdout if result2.returncode == 0 else "Pacote não encontrado."

            info_text = ""
            desc_text = ""
            for line in apt_output.split('\n'):
                if line.startswith("Package:"):
                    info_text += f"📦 Pacote: {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Version:"):
                    info_text += f"📌 Versão: {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Section:"):
                    info_text += f"📂 Seção: {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Priority:"):
                    info_text += f"⭐ Prioridade: {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Architecture:"):
                    info_text += f"💻 Arquitetura: {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Installed-Size:"):
                    info_text += f"💾 Tamanho: {line.split(':',1)[1].strip()} kB\n"
                elif line.startswith("Maintainer:"):
                    info_text += f"👤 Mantenedor: {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Homepage:"):
                    info_text += f"🌐 Homepage: {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Depends:"):
                    info_text += f"🔗 Dependências:\n  {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Recommends:"):
                    info_text += f"👍 Recomenda:\n  {line.split(':',1)[1].strip()}\n"
                elif line.startswith("Suggests:"):
                    info_text += f"💡 Sugere:\n  {line.split(':',1)[1].strip()}\n"

            in_desc = False
            desc_lines = []
            for line in apt_output.split('\n'):
                if line.startswith("Description-en:") or line.startswith("Description:"):
                    in_desc = True
                    desc_lines.append(line.split(':',1)[1].strip())
                elif in_desc and line.startswith(" "):
                    desc_lines.append(line.strip())
                elif in_desc and not line.startswith(" "):
                    in_desc = False

            if desc_lines:
                desc_text = "\n".join(desc_lines)

            self.info_tab.setText(info_text if info_text else apt_output[:2000])
            self.desc_tab.setText(desc_text if desc_text else "Nenhuma descrição disponível.")

            # Scripts
            scripts_out = subprocess.run(
                f"dpkg-query --control-path {pkg_name} 2>/dev/null",
                shell=True, capture_output=True, text=True, timeout=10
            )
            scripts_text = ""
            if scripts_out.stdout.strip():
                for path in scripts_out.stdout.strip().split('\n'):
                    if os.path.exists(path):
                        with open(path, 'r') as f:
                            content = f.read()
                            scripts_text += f"── {os.path.basename(path)} ──\n{content[:500]}...\n\n"
            if not scripts_text:
                scripts_text = "Nenhum script mantenedor disponível ou pacote não instalado."
            self.scripts_tab.setText(scripts_text)

        except Exception as e:
            self.info_tab.setText(f"❌ Erro ao carregar detalhes: {str(e)}")
            self.desc_tab.setText("")
            self.scripts_tab.setText("")

    def _show_properties(self):
        pkgs = self._get_selected_packages()
        if not pkgs:
            QMessageBox.information(self, "Nada Selecionado",
                                    "Selecione um pacote na tabela para ver suas propriedades.")
            return
        self._show_package_details(pkgs[0])

    def _search_apt_repos(self):
        term, ok = QInputDialog.getText(
            self, "🔍 Buscar nos Repositórios APT",
            "Digite o termo de busca (nome ou descrição):"
        )
        if ok and term.strip():
            self.search_box.setText(term.strip())
            self._apply_filters()


# ═══════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if os.name == 'posix' and os.geteuid() != 0:
        print("❌ Erro: Este gerenciador precisa ser executado como ROOT (sudo).")
        print("   sudo python3 fydelis_synaptic.py")
        sys.exit(1)

    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    font = QFont("Segoe UI", 9)
    font.setHintingPreference(QFont.PreferFullHinting)
    app.setFont(font)

    window = FydelisSynaptic()
    window.show()

    sys.exit(app.exec_())