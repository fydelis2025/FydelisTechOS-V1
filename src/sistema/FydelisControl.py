#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FydelisControl.py - Painel de Controle Personalizado para FydelisTechOS
Versão 2.0 — com Gerenciador de Energia, Monitor de Rede, Processos e Firewall
"""

import sys
import os
import subprocess
import re
import socket
import platform
import psutil
import time
from datetime import datetime, timedelta
from functools import partial

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QTableWidget, QTableWidgetItem, QSplitter,
    QListWidget, QLineEdit, QMessageBox, QHeaderView, QCheckBox,
    QFrame, QTextEdit, QDialog, QProgressBar, QComboBox, QGroupBox,
    QGridLayout, QMenu, QAction, QStatusBar, QToolBar, QTabWidget,
    QAbstractItemView, QListWidgetItem, QSizePolicy, QSpacerItem,
    QInputDialog, QSlider, QDial, QProgressDialog, QScrollArea,
    QStackedWidget, QTreeWidget, QTreeWidgetItem, QRadioButton,
    QButtonGroup, QFormLayout, QSpinBox, QDateTimeEdit, QDateEdit,
    QSystemTrayIcon, QMenuBar
)
from PyQt5.QtCore import (
    Qt, QTimer, QSize, QThread, pyqtSignal, pyqtSlot, QObject,
    QDateTime, QDate, QTime, QUrl, QProcess
)
from PyQt5.QtGui import (
    QFont, QColor, QPalette, QIcon, QPixmap, QPainter,
    QLinearGradient, QBrush, QFontDatabase, QTextCharFormat,
    QSyntaxHighlighter
)


# ═══════════════════════════════════════════════════════════════
#  UTILITÁRIOS DE SISTEMA
# ═══════════════════════════════════════════════════════════════
class SystemUtils:
    """Coleção de métodos estáticos para informações do sistema."""

    @staticmethod
    def get_os_info():
        info = {}
        try:
            info['kernel'] = platform.uname().release
            info['hostname'] = socket.gethostname()
            info['arch'] = platform.machine()
            with open('/etc/debian_version', 'r') as f:
                info['debian_version'] = f.read().strip()
        except:
            info['debian_version'] = platform.version()
        try:
            with open('/etc/os-release', 'r') as f:
                for line in f:
                    if line.startswith('PRETTY_NAME='):
                        info['os_name'] = line.split('=')[1].strip().strip('"')
                        break
        except:
            info['os_name'] = f"Debian {info.get('debian_version', '')}"
        return info

    @staticmethod
    def get_uptime():
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            seconds = int(uptime_seconds % 60)
            parts = []
            if days > 0: parts.append(f"{days}d")
            if hours > 0: parts.append(f"{hours}h")
            parts.append(f"{minutes}m")
            parts.append(f"{seconds}s")
            return " ".join(parts)
        except:
            return "N/A"

    @staticmethod
    def get_cpu_info():
        info = {}
        try:
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if line.startswith('model name'):
                        info['model'] = line.split(':')[1].strip()
                        break
            info['cores'] = os.cpu_count()
            info['physical_cores'] = psutil.cpu_count(logical=False)
            freq = psutil.cpu_freq()
            if freq:
                info['freq_current'] = f"{freq.current:.0f} MHz"
                info['freq_max'] = f"{freq.max:.0f} MHz"
            info['usage_percent'] = psutil.cpu_percent(interval=0.5)
            with open('/proc/loadavg', 'r') as f:
                parts = f.read().strip().split()
                info['load_1'] = parts[0]
                info['load_5'] = parts[1]
                info['load_15'] = parts[2]
        except Exception as e:
            info['error'] = str(e)
        return info

    @staticmethod
    def get_memory_info():
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()
        return {
            'total': mem.total, 'available': mem.available,
            'used': mem.used, 'percent': mem.percent,
            'swap_total': swap.total, 'swap_used': swap.used,
            'swap_percent': swap.percent
        }

    @staticmethod
    def get_disk_info():
        disks = []
        for part in psutil.disk_partitions(all=False):
            if part.fstype and 'loop' not in part.device and 'snap' not in part.device:
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    disks.append({
                        'device': part.device, 'mountpoint': part.mountpoint,
                        'fstype': part.fstype, 'total': usage.total,
                        'used': usage.used, 'free': usage.free, 'percent': usage.percent
                    })
                except: pass
        return disks

    @staticmethod
    def get_network_info():
        interfaces = []
        addrs = psutil.net_if_addrs()
        stats = psutil.net_if_stats()
        for name, addr_list in addrs.items():
            if name == 'lo': continue
            info = {'name': name}
            for addr in addr_list:
                if addr.family == socket.AF_INET:
                    info['ipv4'] = addr.address
                    info['netmask'] = addr.netmask
                elif addr.family == socket.AF_INET6:
                    info['ipv6'] = addr.address
            if name in stats:
                info['speed'] = stats[name].speed
                info['isup'] = stats[name].isup
            interfaces.append(info)
        return interfaces

    @staticmethod
    def get_network_traffic():
        """Retorna tráfego de rede por interface."""
        net_io = psutil.net_io_counters(pernic=True)
        traffic = {}
        for name, io in net_io.items():
            if name == 'lo': continue
            traffic[name] = {
                'bytes_sent': io.bytes_sent,
                'bytes_recv': io.bytes_recv,
                'packets_sent': io.packets_sent,
                'packets_recv': io.packets_recv,
                'errin': io.errin,
                'errout': io.errout,
                'dropin': io.dropin,
                'dropout': io.dropout
            }
        return traffic

    @staticmethod
    def get_network_connections():
        """Retorna conexões de rede ativas."""
        conns = []
        try:
            for conn in psutil.net_connections(kind='inet'):
                if conn.status == 'ESTABLISHED' or conn.status == 'LISTEN':
                    laddr = f"{conn.laddr.ip}:{conn.laddr.port}" if conn.laddr else ""
                    raddr = f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else ""
                    conns.append({
                        'fd': conn.fd,
                        'family': 'IPv4' if conn.family == socket.AF_INET else 'IPv6',
                        'type': 'TCP' if conn.type == socket.SOCK_STREAM else 'UDP',
                        'local': laddr,
                        'remote': raddr,
                        'status': conn.status,
                        'pid': conn.pid
                    })
        except: pass
        return conns

    @staticmethod
    def get_services():
        services = []
        try:
            result = subprocess.run(
                "systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | head -200",
                shell=True, capture_output=True, text=True, timeout=10
            )
            for line in result.stdout.strip().split('\n'):
                if not line.strip(): continue
                parts = line.split()
                if len(parts) >= 4:
                    services.append({
                        'name': parts[0].replace('.service', ''),
                        'status': parts[2],
                        'description': ' '.join(parts[3:]),
                        'load': parts[1],
                        'active': parts[2]
                    })
        except: pass
        return services

    @staticmethod
    def get_users():
        users = []
        try:
            with open('/etc/passwd', 'r') as f:
                for line in f:
                    parts = line.strip().split(':')
                    if len(parts) >= 7:
                        uid = int(parts[2])
                        if uid >= 1000 or uid == 0:
                            users.append({
                                'name': parts[0], 'uid': uid, 'gid': int(parts[3]),
                                'home': parts[5], 'shell': parts[6], 'is_root': uid == 0
                            })
        except: pass
        return users

    @staticmethod
    def get_process_count():
        return len(psutil.pids())

    @staticmethod
    def get_package_count():
        try:
            result = subprocess.run(
                "dpkg -l 2>/dev/null | grep '^ii' | wc -l",
                shell=True, capture_output=True, text=True, timeout=10
            )
            return int(result.stdout.strip())
        except:
            return 0

    @staticmethod
    def get_uptime_seconds():
        try:
            with open('/proc/uptime', 'r') as f:
                return float(f.read().split()[0])
        except:
            return 0

    @staticmethod
    def get_battery_info():
        """Retorna informações da bateria (se disponível)."""
        battery = {}
        try:
            if hasattr(psutil, 'sensors_battery'):
                bat = psutil.sensors_battery()
                if bat:
                    battery['percent'] = bat.percent
                    battery['plugged'] = bat.power_plugged
                    battery['secsleft'] = bat.secsleft
                    battery['time_left'] = str(timedelta(seconds=bat.secsleft)) if bat.secsleft != -1 else "Calculando..."
        except:
            pass
        return battery

    @staticmethod
    def get_power_profile():
        """Retorna o perfil de energia atual."""
        try:
            result = subprocess.run(
                "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'powersave'",
                shell=True, capture_output=True, text=True, timeout=5
            )
            return result.stdout.strip()
        except:
            return "unknown"

    @staticmethod
    def get_ufw_status():
        """Retorna status do UFW."""
        try:
            result = subprocess.run(
                "ufw status 2>/dev/null",
                shell=True, capture_output=True, text=True, timeout=5
            )
            return result.stdout.strip()
        except:
            return "UFW não instalado"

    @staticmethod
    def get_ufw_rules():
        """Retorna regras do UFW."""
        try:
            result = subprocess.run(
                "ufw status numbered 2>/dev/null",
                shell=True, capture_output=True, text=True, timeout=5
            )
            return result.stdout.strip()
        except:
            return ""

    @staticmethod
    def format_bytes(n):
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if n < 1024:
                return f"{n:.1f} {unit}"
            n /= 1024
        return f"{n:.1f} PB"

    @staticmethod
    def format_bits_per_sec(bps):
        for unit in ['bps', 'Kbps', 'Mbps', 'Gbps']:
            if bps < 1000:
                return f"{bps:.1f} {unit}"
            bps /= 1000
        return f"{bps:.1f} Tbps"


# ═══════════════════════════════════════════════════════════════
#  WIDGETS PERSONALIZADOS
# ═══════════════════════════════════════════════════════════════

class InfoCard(QFrame):
    def __init__(self, title, value="", icon="📊", progress=None, color="#6A11CB"):
        super().__init__()
        self._title = title
        self._value = value
        self._icon = icon
        self._progress = progress
        self._color = color
        self._setup_ui()

    def _setup_ui(self):
        self.setStyleSheet(f"""
            InfoCard {{
                background-color: rgba(15, 23, 42, 200);
                border: 1px solid rgba(106, 17, 203, 60);
                border-radius: 14px;
            }}
        """)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 14, 16, 14)
        layout.setSpacing(6)

        header = QHBoxLayout()
        icon_label = QLabel(self._icon)
        icon_label.setFont(QFont("Segoe UI", 20))
        header.addWidget(icon_label)

        title_label = QLabel(self._title)
        title_label.setFont(QFont("Segoe UI", 10, QFont.Bold))
        title_label.setStyleSheet("color: #94A3B8; text-transform: uppercase; letter-spacing: 1px;")
        header.addWidget(title_label)
        header.addStretch()
        layout.addLayout(header)

        self.value_label = QLabel(self._value)
        self.value_label.setFont(QFont("Segoe UI", 22, QFont.Bold))
        self.value_label.setStyleSheet(f"color: {self._color};")
        layout.addWidget(self.value_label)

        if self._progress is not None:
            self.progress_bar = QProgressBar()
            self.progress_bar.setRange(0, 100)
            self.progress_bar.setValue(self._progress)
            self.progress_bar.setTextVisible(True)
            self.progress_bar.setFormat(f"{self._progress:.0f}%")
            self.progress_bar.setFixedHeight(12)
            self.progress_bar.setStyleSheet(f"""
                QProgressBar {{
                    background-color: #1E293B; border: none;
                    border-radius: 6px; text-align: center;
                    font-size: 8px; color: #FFFFFF;
                }}
                QProgressBar::chunk {{
                    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                        stop:0 {self._color}, stop:1 #22D3EE);
                    border-radius: 6px;
                }}
            """)
            layout.addWidget(self.progress_bar)

    def update_value(self, value, progress=None):
        self.value_label.setText(str(value))
        if progress is not None and hasattr(self, 'progress_bar'):
            self.progress_bar.setValue(int(progress))
            self.progress_bar.setFormat(f"{progress:.0f}%")


class TrafficMonitorThread(QThread):
    """Thread para monitorar tráfego de rede em background."""
    data_ready = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._running = True
        self._prev_traffic = {}
        self._prev_time = time.time()

    def run(self):
        while self._running:
            current = SystemUtils.get_network_traffic()
            current_time = time.time()
            elapsed = current_time - self._prev_time

            if self._prev_traffic and elapsed > 0:
                speeds = {}
                for iface, data in current.items():
                    if iface in self._prev_traffic:
                        prev = self._prev_traffic[iface]
                        sent_bps = (data['bytes_sent'] - prev['bytes_sent']) * 8 / elapsed
                        recv_bps = (data['bytes_recv'] - prev['bytes_recv']) * 8 / elapsed
                        speeds[iface] = {
                            'download': recv_bps,
                            'upload': sent_bps,
                            'total_sent': data['bytes_sent'],
                            'total_recv': data['bytes_recv']
                        }
                    else:
                        speeds[iface] = {
                            'download': 0, 'upload': 0,
                            'total_sent': data['bytes_sent'],
                            'total_recv': data['bytes_recv']
                        }
                self.data_ready.emit(speeds)

            self._prev_traffic = current
            self._prev_time = current_time
            self.msleep(1000)

    def stop(self):
        self._running = False
        self.wait()


# ═══════════════════════════════════════════════════════════════
#  PAINEL DE CONTROLE PRINCIPAL
# ═══════════════════════════════════════════════════════════════
class DebianControlPanel(QMainWindow):
    def __init__(self):
        super().__init__()
        self._setup_window()
        self._build_ui()
        self._apply_global_style()
        self._load_initial_data()

    def _setup_window(self):
        self.setWindowTitle("Painel de Controle — FydelisTechOS")
        self.setMinimumSize(1024, 720)
        self.resize(1280, 840)

    def _apply_global_style(self):
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

    def _build_ui(self):
        cw = QWidget()
        self.setCentralWidget(cw)
        main_layout = QVBoxLayout(cw)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # ── MENUBAR ──
        menubar = self.menuBar()
        menubar.setStyleSheet("""
            QMenuBar { background-color: #0F172A; color: #E2E8F0;
                border-bottom: 1px solid #1E293B; padding: 2px 8px; font-size: 12px; }
            QMenuBar::item { padding: 4px 12px; }
            QMenuBar::item:selected { background-color: #6A11CB; border-radius: 4px; }
            QMenu { background-color: #0F172A; color: #E2E8F0;
                border: 1px solid #1E293B; }
            QMenu::item:selected { background-color: #6A11CB; }
        """)

        sys_menu = menubar.addMenu("⚙️ Sistema")
        act_about = QAction("📋 Sobre o Sistema", self)
        act_about.triggered.connect(self._show_about)
        sys_menu.addAction(act_about)
        sys_menu.addSeparator()
        act_shutdown = QAction("⏻ Desligar", self)
        act_shutdown.triggered.connect(lambda: self._system_action("shutdown"))
        sys_menu.addAction(act_shutdown)
        act_reboot = QAction("🔄 Reiniciar", self)
        act_reboot.triggered.connect(lambda: self._system_action("reboot"))
        sys_menu.addAction(act_reboot)
        act_suspend = QAction("💤 Suspender", self)
        act_suspend.triggered.connect(lambda: self._system_action("suspend"))
        sys_menu.addAction(act_suspend)
        act_hibernate = QAction("🛌 Hibernar", self)
        act_hibernate.triggered.connect(lambda: self._system_action("hibernate"))
        sys_menu.addAction(act_hibernate)

        tools_menu = menubar.addMenu("🔧 Ferramentas")
        act_terminal = QAction("💻 Terminal", self)
        act_terminal.triggered.connect(lambda: self._run_command("x-terminal-emulator"))
        tools_menu.addAction(act_terminal)
        act_monitor = QAction("📊 Monitor de Sistema", self)
        act_monitor.triggered.connect(lambda: self._run_command("gnome-system-monitor"))
        tools_menu.addAction(act_monitor)
        act_update = QAction("🔄 Gerenciador de Pacotes", self)
        act_update.triggered.connect(lambda: self._run_command("apt upgrade"))
        tools_menu.addAction(act_update)

        help_menu = menubar.addMenu("❓ Ajuda")
        act_docs = QAction("📖 Documentação", self)
        act_docs.triggered.connect(self._show_docs)
        help_menu.addAction(act_docs)
        act_about_program = QAction("ℹ️ Sobre", self)
        act_about_program.triggered.connect(self._show_about)
        help_menu.addAction(act_about_program)

        # ── TOOLBAR ──
        toolbar = QToolBar()
        toolbar.setMovable(False)
        toolbar.setStyleSheet("""
            QToolBar { background-color: #0F172A; border-bottom: 1px solid #1E293B;
                padding: 4px 8px; spacing: 8px; }
            QPushButton { background-color: #1E293B; color: #22D3EE;
                border: 1px solid #334155; border-radius: 6px;
                padding: 6px 14px; font-size: 11px; font-weight: bold; }
            QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
            QPushButton:checked { background-color: #6A11CB; color: #FFFFFF; }
        """)
        self.addToolBar(toolbar)

        self.nav_buttons = {}
        nav_items = [
            ("🏠", "Início", self._show_dashboard),
            ("📊", "Monitor", self._show_monitor),
            ("⚡", "Serviços", self._show_services),
            ("⚡", "Energia", self._show_power),
            ("🌐", "Rede", self._show_network),
            ("📡", "Tráfego", self._show_traffic),
            ("🔌", "Conexões", self._show_connections),
            ("⚙️", "Processos", self._show_processes),
            ("🛡️", "Firewall", self._show_firewall),
            ("👥", "Usuários", self._show_users),
            ("💿", "Discos", self._show_disks),
            ("📦", "Pacotes", self._show_packages),
        ]

        for icon, text, callback in nav_items:
            btn = QPushButton(f"{icon} {text}")
            btn.setCheckable(True)
            btn.clicked.connect(callback)
            toolbar.addWidget(btn)
            self.nav_buttons[text] = btn

        toolbar.addSeparator()
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        toolbar.addWidget(spacer)

        self.clock_label = QLabel()
        self.clock_label.setStyleSheet("color: #64748B; font-size: 12px; font-weight: bold; padding: 0 10px;")
        toolbar.addWidget(self.clock_label)
        clock_timer = QTimer(self)
        clock_timer.timeout.connect(self._update_clock)
        clock_timer.start(1000)
        self._update_clock()

        # ── STACKED WIDGET ──
        self.stack = QStackedWidget()
        main_layout.addWidget(self.stack)

        # Constrói todas as páginas
        self._build_dashboard_page()
        self._build_monitor_page()
        self._build_services_page()
        self._build_power_page()
        self._build_network_page()
        self._build_traffic_page()
        self._build_connections_page()
        self._build_processes_page()
        self._build_firewall_page()
        self._build_users_page()
        self._build_disks_page()
        self._build_packages_page()

        self._show_dashboard()

        # Status Bar
        self.statusBar().setStyleSheet("""
            QStatusBar { background-color: #0F172A; color: #64748B;
                border-top: 1px solid #1E293B; font-size: 11px; padding: 2px 10px; }
        """)
        self.statusBar().showMessage("✅ Sistema pronto")

    def _update_clock(self):
        now = QDateTime.currentDateTime()
        self.clock_label.setText(now.toString("dddd, dd/MM/yyyy HH:mm:ss"))

    def _highlight_nav(self, active_text):
        for text, btn in self.nav_buttons.items():
            is_active = (text == active_text)
            btn.setChecked(is_active)
            if is_active:
                btn.setStyleSheet("""
                    QPushButton { background-color: #6A11CB; color: #FFFFFF;
                    border: 1px solid #8B5CF6; border-radius: 6px;
                    padding: 6px 14px; font-size: 11px; font-weight: bold; }
                """)
            else:
                btn.setStyleSheet("""
                    QPushButton { background-color: #1E293B; color: #22D3EE;
                    border: 1px solid #334155; border-radius: 6px;
                    padding: 6px 14px; font-size: 11px; font-weight: bold; }
                    QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
                """)

    # ══════════════════════════════════════════════════════════
    #  PÁGINAS — DASHBOARD, MONITOR, SERVIÇOS
    # ══════════════════════════════════════════════════════════

    def _build_dashboard_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        header = QHBoxLayout()
        icon = QLabel("🖥️")
        icon.setFont(QFont("Segoe UI", 36))
        header.addWidget(icon)
        title_block = QVBoxLayout()
        title = QLabel("Painel de Controle FydelisTechOS")
        title.setFont(QFont("Segoe UI", 22, QFont.Bold))
        title.setStyleSheet("color: #F8FAFC;")
        title_block.addWidget(title)
        os_info = SystemUtils.get_os_info()
        subtitle = QLabel(f"{os_info.get('os_name', 'FydelisTechOS')} • Kernel {os_info.get('kernel', '')} • {os_info.get('arch', '')}")
        subtitle.setStyleSheet("color: #64748B; font-size: 12px;")
        title_block.addWidget(subtitle)
        header.addLayout(title_block, 1)
        layout.addLayout(header)

        cards_grid = QGridLayout()
        cards_grid.setSpacing(12)

        self.cpu_card = InfoCard("CPU", "0%", "🧠", 0, "#22D3EE")
        cards_grid.addWidget(self.cpu_card, 0, 0)
        self.mem_card = InfoCard("Memória", "0%", "💾", 0, "#6A11CB")
        cards_grid.addWidget(self.mem_card, 0, 1)
        self.disk_card = InfoCard("Disco (/)", "0%", "💿", 0, "#10B981")
        cards_grid.addWidget(self.disk_card, 0, 2)
        self.uptime_card = InfoCard("Uptime", "0s", "⏱️", None, "#F8FAFC")
        cards_grid.addWidget(self.uptime_card, 0, 3)
        self.battery_card = InfoCard("Bateria", "N/A", "🔋", None, "#F59E0B")
        cards_grid.addWidget(self.battery_card, 1, 0)
        self.pkg_card = InfoCard("Pacotes Instalados", "0", "📦", None, "#F472B6")
        cards_grid.addWidget(self.pkg_card, 1, 1)
        self.proc_card = InfoCard("Processos Ativos", "0", "⚙️", None, "#F59E0B")
        cards_grid.addWidget(self.proc_card, 1, 2)
        self.net_card = InfoCard("Interfaces de Rede", "0", "🌐", None, "#EC4899")
        cards_grid.addWidget(self.net_card, 1, 3)
        layout.addLayout(cards_grid)

        # Ações rápidas
        actions_group = QGroupBox("⚡ Ações Rápidas")
        actions_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 13px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 12px;
                margin-top: 16px; padding: 20px 16px 16px 16px; }
            QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left;
                padding: 2px 12px; color: #94A3B8; }
            QPushButton { background-color: #1E293B; color: #F8FAFC;
                border: 1px solid #334155; border-radius: 8px;
                padding: 12px 20px; font-size: 12px; font-weight: bold; }
            QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
        """)
        actions_layout = QGridLayout(actions_group)
        actions_layout.setSpacing(10)
        btns = [
            ("🔄 Atualizar Repositórios", self._update_repos),
            ("⬆️ Upgrade do Sistema", self._system_upgrade),
            ("📥 Instalar Pacote", self._install_package),
            ("🗑️ Remover Pacote", self._remove_package),
            ("💻 Abrir Terminal", lambda: self._run_command("x-terminal-emulator")),
            ("📊 Monitor de Sistema", lambda: self._run_command("gnome-system-monitor")),
            ("💤 Suspender", lambda: self._system_action("suspend")),
            ("🔄 Reiniciar", lambda: self._system_action("reboot")),
            ("⏻ Desligar", lambda: self._system_action("shutdown")),
            ("🛡️ Status Firewall", self._show_firewall),
        ]
        for i, (text, callback) in enumerate(btns):
            btn = QPushButton(text)
            btn.clicked.connect(callback)
            actions_layout.addWidget(btn, i // 5, i % 5)
        layout.addWidget(actions_group)
        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._dashboard_page = QWidget()
        dash_layout = QVBoxLayout(self._dashboard_page)
        dash_layout.setContentsMargins(0, 0, 0, 0)
        dash_layout.addWidget(scroll)
        self.stack.addWidget(self._dashboard_page)

    def _show_dashboard(self):
        self._highlight_nav("Início")
        self.stack.setCurrentWidget(self._dashboard_page)
        self._update_dashboard_data()
        self.statusBar().showMessage("🏠 Página inicial")

    def _update_dashboard_data(self):
        try:
            cpu = SystemUtils.get_cpu_info()
            cpu_percent = cpu.get('usage_percent', 0)
            self.cpu_card.update_value(f"{cpu_percent:.1f}%", cpu_percent)

            mem = SystemUtils.get_memory_info()
            mem_percent = mem.get('percent', 0)
            used_str = SystemUtils.format_bytes(mem.get('used', 0))
            total_str = SystemUtils.format_bytes(mem.get('total', 0))
            self.mem_card.update_value(f"{used_str} / {total_str}", mem_percent)

            disks = SystemUtils.get_disk_info()
            if disks:
                root = next((d for d in disks if d['mountpoint'] == '/'), disks[0])
                disk_percent = root.get('percent', 0)
                used_str = SystemUtils.format_bytes(root.get('used', 0))
                total_str = SystemUtils.format_bytes(root.get('total', 0))
                self.disk_card.update_value(f"{used_str} / {total_str}", disk_percent)

            battery = SystemUtils.get_battery_info()
            if battery:
                bat_text = f"{battery.get('percent', 0):.0f}%"
                if battery.get('plugged'):
                    bat_text += " 🔌 Carregando"
                self.battery_card.update_value(bat_text, battery.get('percent', 0))
            else:
                self.battery_card.update_value("Sem bateria")

            self.uptime_card.update_value(SystemUtils.get_uptime())
            self.pkg_card.update_value(str(SystemUtils.get_package_count()))
            self.proc_card.update_value(str(SystemUtils.get_process_count()))
            self.net_card.update_value(str(len(SystemUtils.get_network_info())))
        except Exception as e:
            print(f"Dashboard update error: {e}")

    # ── MONITOR ──
    def _build_monitor_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        self.monitor_widget = SystemMonitorWidget()
        layout.addWidget(self.monitor_widget)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._monitor_page = QWidget()
        m_layout = QVBoxLayout(self._monitor_page)
        m_layout.setContentsMargins(0, 0, 0, 0)
        m_layout.addWidget(scroll)
        self.stack.addWidget(self._monitor_page)

    def _show_monitor(self):
        self._highlight_nav("Monitor")
        self.stack.setCurrentWidget(self._monitor_page)
        self.statusBar().showMessage("📊 Monitor do Sistema")

    # ── SERVIÇOS ──
    def _build_services_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        header = QHBoxLayout()
        header.addWidget(QLabel("⚡ Gerenciamento de Serviços"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Recarregar")
        btn_refresh.clicked.connect(self._refresh_services)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        self.service_filter = QLineEdit()
        self.service_filter.setPlaceholderText("🔍 Filtrar serviços...")
        self.service_filter.setFixedWidth(250)
        self.service_filter.setStyleSheet("background-color: #0B0F19; color: #F8FAFC; border: 1px solid #1E293B; border-radius: 6px; padding: 6px 12px;")
        self.service_filter.textChanged.connect(self._filter_services)
        header.addWidget(self.service_filter)
        layout.addLayout(header)

        self.services_table = QTableWidget()
        self.services_table.setColumnCount(5)
        self.services_table.setHorizontalHeaderLabels(["", "Serviço", "Status", "Ativo", "Descrição"])
        self.services_table.setColumnWidth(0, 36)
        self.services_table.setColumnWidth(1, 220)
        self.services_table.setColumnWidth(2, 80)
        self.services_table.setColumnWidth(3, 60)
        self.services_table.horizontalHeader().setSectionResizeMode(4, QHeaderView.Stretch)
        self.services_table.verticalHeader().setVisible(False)
        self.services_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.services_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.services_table.setStyleSheet("""
            QTableWidget { background-color: #0B0F19; color: #E2E8F0;
            border: 1px solid #1E293B; border-radius: 8px; font-size: 11px; }
            QTableWidget::item:selected { background-color: #6A11CB; color: #FFF; }
            QHeaderView::section { background-color: #161E38; color: #22D3EE; }
        """)
        layout.addWidget(self.services_table)

        actions = QHBoxLayout()
        for text, color, act in [
            ("▶️ Iniciar", "#10B981", "start"), ("⏹️ Parar", "#EF4444", "stop"),
            ("🔄 Reiniciar", "#F59E0B", "restart"), ("✅ Habilitar", "#22D3EE", "enable"),
            ("❌ Desabilitar", "#64748B", "disable"), ("📋 Status", "#6A11CB", "status")
        ]:
            btn = QPushButton(text)
            btn.clicked.connect(lambda checked, a=act: self._service_action(a))
            btn.setStyleSheet(f"background-color: {color}; color: #FFF; border: none; border-radius: 6px; padding: 8px 16px; font-size: 11px; font-weight: bold;")
            actions.addWidget(btn)
        actions.addStretch()
        layout.addLayout(actions)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._services_page = QWidget()
        s_layout = QVBoxLayout(self._services_page)
        s_layout.setContentsMargins(0, 0, 0, 0)
        s_layout.addWidget(scroll)
        self.stack.addWidget(self._services_page)

        self._all_services = []
        self._refresh_services()

    def _refresh_services(self):
        self._all_services = SystemUtils.get_services()
        self._filter_services()

    def _filter_services(self):
        text = self.service_filter.text().lower().strip()
        filtered = [s for s in self._all_services
                    if not text or text in s['name'].lower() or text in s.get('description', '').lower()]
        self._populate_services_table(filtered)

    def _populate_services_table(self, services):
        self.services_table.setRowCount(len(services))
        for i, svc in enumerate(services):
            status_icon = "✅" if svc['status'] == 'active' else "❌" if svc['status'] == 'inactive' else "⚠️"
            si = QTableWidgetItem(status_icon)
            si.setTextAlignment(Qt.AlignCenter)
            si.setForeground(QColor(52, 211, 153) if svc['status'] == 'active' else QColor(239, 68, 68))
            self.services_table.setItem(i, 0, si)
            ni = QTableWidgetItem(svc['name'])
            ni.setForeground(QColor(248, 250, 252))
            self.services_table.setItem(i, 1, ni)
            si2 = QTableWidgetItem(svc.get('active', svc['status']))
            si2.setForeground(QColor(52, 211, 153) if svc.get('active') == 'active' else QColor(148, 163, 184))
            self.services_table.setItem(i, 2, si2)
            li = QTableWidgetItem(svc.get('load', ''))
            li.setForeground(QColor(147, 197, 253))
            self.services_table.setItem(i, 3, li)
            di = QTableWidgetItem(svc.get('description', ''))
            di.setForeground(QColor(100, 116, 139))
            self.services_table.setItem(i, 4, di)

    def _get_selected_service(self):
        rows = set()
        for idx in self.services_table.selectedIndexes():
            rows.add(idx.row())
        if not rows:
            QMessageBox.information(self, "Nada Selecionado", "Selecione um serviço na tabela.")
            return None
        return self.services_table.item(list(rows)[0], 1).text()

    def _service_action(self, action):
        service = self._get_selected_service()
        if not service: return
        cmd_map = {
            'start': f"systemctl start {service}",
            'stop': f"systemctl stop {service}",
            'restart': f"systemctl restart {service}",
            'enable': f"systemctl enable {service}",
            'disable': f"systemctl disable {service}",
            'status': f"systemctl status {service} --no-pager -n 30"
        }
        cmd = cmd_map.get(action)
        if not cmd: return
        self.statusBar().showMessage(f"⚡ Executando: {cmd[:60]}...")
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            output = result.stdout if result.returncode == 0 else result.stderr
            if action == 'status':
                dlg = QDialog(self)
                dlg.setWindowTitle(f"📋 Status: {service}")
                dlg.setMinimumSize(700, 450)
                dlg.setStyleSheet("background-color: #0F172A;")
                dl = QVBoxLayout(dlg)
                te = QTextEdit()
                te.setReadOnly(True)
                te.setPlainText(output)
                te.setStyleSheet("background-color: #0B0F19; color: #E2E8F0; border: 1px solid #1E293B; border-radius: 6px; font-family: monospace; font-size: 11px;")
                dl.addWidget(te)
                b = QPushButton("✕ Fechar")
                b.clicked.connect(dlg.accept)
                b.setStyleSheet("background-color: #1E293B; color: #22D3EE; border: 1px solid #334155; border-radius: 6px; padding: 8px 20px;")
                dl.addWidget(b, alignment=Qt.AlignRight)
                dlg.exec_()
            else:
                QMessageBox.information(self, f"{'✅' if result.returncode == 0 else '❌'} {action}", f"Serviço: {service}\n\n{output[:500]}")
            self._refresh_services()
            self.statusBar().showMessage(f"✅ {action} concluído em {service}")
        except Exception as e:
            QMessageBox.critical(self, "Erro", f"Falha: {str(e)}")

    def _show_services(self):
        self._highlight_nav("Serviços")
        self.stack.setCurrentWidget(self._services_page)
        self._refresh_services()
        self.statusBar().showMessage("⚡ Serviços Systemd")

    # ══════════════════════════════════════════════════════════
    #  NOVA PÁGINA: GERENCIADOR DE ENERGIA
    # ══════════════════════════════════════════════════════════
    def _build_power_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Título
        header = QHBoxLayout()
        header.addWidget(self._title_label("⚡ Gerenciador de Energia"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Atualizar")
        btn_refresh.clicked.connect(self._refresh_power_info)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        layout.addLayout(header)

        # Cards de energia
        cards = QGridLayout()
        cards.setSpacing(12)

        self.power_profile_card = InfoCard("Perfil de Energia", "N/A", "⚡", None, "#22D3EE")
        cards.addWidget(self.power_profile_card, 0, 0)

        self.battery_status_card = InfoCard("Bateria", "N/A", "🔋", 0, "#F59E0B")
        cards.addWidget(self.battery_status_card, 0, 1)

        self.power_consumption_card = InfoCard("Consumo Estimado", "N/A", "💡", None, "#10B981")
        cards.addWidget(self.power_consumption_card, 0, 2)

        self.temperature_card = InfoCard("Temperatura CPU", "N/A", "🌡️", None, "#EF4444")
        cards.addWidget(self.temperature_card, 1, 0)

        self.fan_speed_card = InfoCard("Velocidade Ventoinhas", "N/A", "🌀", None, "#64748B")
        cards.addWidget(self.fan_speed_card, 1, 1)

        self.uptime_power_card = InfoCard("Uptime desde Boot", "N/A", "⏱️", None, "#F8FAFC")
        cards.addWidget(self.uptime_power_card, 1, 2)

        layout.addLayout(cards)

        # Controles de energia
        ctrl_group = QGroupBox("🎮 Controles de Energia")
        ctrl_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 13px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 12px;
                padding: 20px 16px 16px 16px; margin-top: 12px; }
            QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left;
                padding: 2px 12px; color: #94A3B8; }
            QPushButton { border: none; border-radius: 8px; padding: 14px 24px;
                font-size: 13px; font-weight: bold; color: #FFF; }
        """)
        ctrl_layout = QGridLayout(ctrl_group)
        ctrl_layout.setSpacing(12)

        power_btns = [
            ("💤 Suspender", self._suspend_system, "#6A11CB"),
            ("🛌 Hibernar", self._hibernate_system, "#7C3AED"),
            ("⏻ Desligar", lambda: self._system_action("shutdown"), "#EF4444"),
            ("🔄 Reiniciar", lambda: self._system_action("reboot"), "#F59E0B"),
            ("🔒 Bloquear Tela", self._lock_screen, "#64748B"),
            ("👤 Trocar Usuário", self._switch_user, "#3B82F6"),
        ]

        for i, (text, callback, color) in enumerate(power_btns):
            btn = QPushButton(text)
            btn.clicked.connect(callback)
            btn.setStyleSheet(f"background-color: {color};")
            ctrl_layout.addWidget(btn, i // 3, i % 3)

        # Agendamento
        sched_group = QGroupBox("⏰ Agendamento")
        sched_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px;
                padding: 16px; margin-top: 8px; }
            QGroupBox::title { padding: 2px 8px; color: #94A3B8; }
            QPushButton { border: none; border-radius: 6px; padding: 8px 16px;
                font-size: 11px; font-weight: bold; color: #FFF; }
            QDateTimeEdit { background-color: #0B0F19; color: #F8FAFC;
                border: 1px solid #1E293B; border-radius: 6px; padding: 6px; }
        """)
        sched_layout = QHBoxLayout(sched_group)

        sched_layout.addWidget(QLabel("Desligar em:"))
        self.sched_datetime = QDateTimeEdit(QDateTime.currentDateTime().addSecs(3600))
        self.sched_datetime.setDisplayFormat("dd/MM/yyyy HH:mm")
        self.sched_datetime.setMinimumDateTime(QDateTime.currentDateTime())
        sched_layout.addWidget(self.sched_datetime)

        btn_sched_shutdown = QPushButton("⏻ Agendar Desligamento")
        btn_sched_shutdown.clicked.connect(self._schedule_shutdown)
        btn_sched_shutdown.setStyleSheet("background-color: #EF4444;")
        sched_layout.addWidget(btn_sched_shutdown)

        btn_sched_cancel = QPushButton("❌ Cancelar Agendamento")
        btn_sched_cancel.clicked.connect(self._cancel_scheduled)
        btn_sched_cancel.setStyleSheet("background-color: #64748B;")
        sched_layout.addWidget(btn_sched_cancel)

        layout.addWidget(ctrl_group)
        layout.addWidget(sched_group)
        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._power_page = QWidget()
        p_layout = QVBoxLayout(self._power_page)
        p_layout.setContentsMargins(0, 0, 0, 0)
        p_layout.addWidget(scroll)
        self.stack.addWidget(self._power_page)

        self._refresh_power_info()

    def _refresh_power_info(self):
        try:
            profile = SystemUtils.get_power_profile()
            self.power_profile_card.update_value(profile)

            battery = SystemUtils.get_battery_info()
            if battery:
                bat_text = f"{battery.get('percent', 0):.0f}%"
                if battery.get('plugged'):
                    bat_text += " 🔌 Carregando"
                self.battery_status_card.update_value(bat_text, battery.get('percent', 0))
            else:
                self.battery_status_card.update_value("Sem bateria (desktop)")

            # Temperatura CPU
            try:
                temps = psutil.sensors_temperatures()
                if 'coretemp' in temps:
                    core = temps['coretemp'][0]
                    temp_str = f"{core.current:.1f}°C"
                    self.temperature_card.update_value(temp_str, min(core.current, 100))
                elif 'cpu_thermal' in temps:
                    temp_str = f"{temps['cpu_thermal'][0].current:.1f}°C"
                    self.temperature_card.update_value(temp_str)
                else:
                    self.temperature_card.update_value("N/A")
            except:
                self.temperature_card.update_value("N/A")

            self.uptime_power_card.update_value(SystemUtils.get_uptime())
            self.power_consumption_card.update_value("~15-65W (estimado)")

            # Fan speed
            try:
                fans = psutil.sensors_fans()
                if fans:
                    fan_text = ", ".join(f"{v[0].current} RPM" for v in fans.values() if v)
                    self.fan_speed_card.update_value(fan_text or "N/A")
                else:
                    self.fan_speed_card.update_value("N/A")
            except:
                self.fan_speed_card.update_value("N/A")

        except Exception as e:
            print(f"Power info error: {e}")

    def _suspend_system(self):
        self._system_action("suspend")

    def _hibernate_system(self):
        self._system_action("hibernate")

    def _lock_screen(self):
        try:
            subprocess.Popen(["dm-tool", "lock"], shell=True)
        except:
            try:
                subprocess.Popen(["gnome-screensaver-command", "-l"], shell=True)
            except:
                QMessageBox.warning(self, "Erro", "Não foi possível bloquear a tela.")

    def _switch_user(self):
        try:
            subprocess.Popen(["dm-tool", "switch-to-greeter"], shell=True)
        except:
            QMessageBox.warning(self, "Erro", "Não foi possível trocar de usuário.")

    def _schedule_shutdown(self):
        dt = self.sched_datetime.dateTime()
        now = QDateTime.currentDateTime()
        secs = now.secsTo(dt)
        if secs <= 0:
            QMessageBox.warning(self, "Erro", "A data/hora deve ser futura.")
            return
        resposta = QMessageBox.question(self, "⏻ Agendar Desligamento",
                                        f"Desligar o sistema em {dt.toString('dd/MM/yyyy HH:mm')}?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            try:
                subprocess.run(f"shutdown -h +{secs // 60}", shell=True, timeout=5)
                QMessageBox.information(self, "✅ Agendado",
                                        f"Desligamento agendado para {dt.toString('dd/MM/yyyy HH:mm')}")
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))

    def _cancel_scheduled(self):
        resposta = QMessageBox.question(self, "❌ Cancelar Agendamento",
                                        "Cancelar desligamento agendado?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            try:
                subprocess.run("shutdown -c", shell=True, timeout=5)
                QMessageBox.information(self, "✅ Cancelado", "Desligamento agendado cancelado.")
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))

    def _show_power(self):
        self._highlight_nav("Energia")
        self.stack.setCurrentWidget(self._power_page)
        self._refresh_power_info()
        self.statusBar().showMessage("⚡ Gerenciador de Energia")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: REDE (Info)
    # ══════════════════════════════════════════════════════════
    def _build_network_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        header.addWidget(self._title_label("🌐 Informações de Rede"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Recarregar")
        btn_refresh.clicked.connect(self._refresh_network)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        layout.addLayout(header)

        self.network_table = QTableWidget()
        self.network_table.setColumnCount(6)
        self.network_table.setHorizontalHeaderLabels(["Interface", "IPv4", "Máscara", "IPv6", "Velocidade", "Status"])
        self.network_table.setColumnWidth(0, 120)
        self.network_table.setColumnWidth(1, 150)
        self.network_table.setColumnWidth(2, 120)
        self.network_table.setColumnWidth(3, 200)
        self.network_table.setColumnWidth(4, 80)
        self.network_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.Stretch)
        self.network_table.verticalHeader().setVisible(False)
        self.network_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.network_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.network_table.setStyleSheet(self._table_style())
        layout.addWidget(self.network_table)

        info_group = QGroupBox("📡 Informações Adicionais")
        info_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px; padding: 16px; margin-top: 12px; }
            QGroupBox::title { padding: 2px 8px; color: #94A3B8; }
            QLabel { color: #E2E8F0; font-size: 11px; }
        """)
        info_layout = QFormLayout(info_group)
        self.hostname_label = QLabel(socket.gethostname())
        info_layout.addRow("Hostname:", self.hostname_label)
        try: domain = socket.getfqdn()
        except: domain = "N/A"
        info_layout.addRow("FQDN:", QLabel(domain))
        self.gateway_label = QLabel("...")
        info_layout.addRow("Gateway:", self.gateway_label)
        self.dns_label = QLabel("...")
        info_layout.addRow("DNS:", self.dns_label)
        self.mac_label = QLabel("...")
        info_layout.addRow("MAC:", self.mac_label)
        layout.addWidget(info_group)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._network_page = QWidget()
        n_layout = QVBoxLayout(self._network_page)
        n_layout.setContentsMargins(0, 0, 0, 0)
        n_layout.addWidget(scroll)
        self.stack.addWidget(self._network_page)
        self._refresh_network()

    def _refresh_network(self):
        interfaces = SystemUtils.get_network_info()
        self.network_table.setRowCount(len(interfaces))
        for i, iface in enumerate(interfaces):
            ni = QTableWidgetItem(iface['name'])
            ni.setForeground(QColor(248, 250, 252))
            ni.setFont(QFont("Segoe UI", 10, QFont.Bold))
            self.network_table.setItem(i, 0, ni)
            ip = QTableWidgetItem(iface.get('ipv4', '—'))
            ip.setForeground(QColor(52, 211, 153))
            self.network_table.setItem(i, 1, ip)
            mk = QTableWidgetItem(iface.get('netmask', '—'))
            mk.setForeground(QColor(148, 163, 184))
            self.network_table.setItem(i, 2, mk)
            ip6 = QTableWidgetItem(iface.get('ipv6', '—'))
            ip6.setForeground(QColor(147, 197, 253))
            self.network_table.setItem(i, 3, ip6)
            speed = iface.get('speed', 0)
            sp = QTableWidgetItem(f"{speed} Mbps" if speed else "—")
            sp.setForeground(QColor(196, 181, 253))
            self.network_table.setItem(i, 4, sp)
            st = QTableWidgetItem("🟢 Ativa" if iface.get('isup') else "🔴 Inativa")
            st.setForeground(QColor(52, 211, 153) if iface.get('isup') else QColor(239, 68, 68))
            self.network_table.setItem(i, 5, st)
        try:
            r = subprocess.run("ip route | grep default | awk '{print $3}' | head -1", shell=True, capture_output=True, text=True, timeout=5)
            self.gateway_label.setText(r.stdout.strip() or "N/A")
            r = subprocess.run("cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\\n' ' '", shell=True, capture_output=True, text=True, timeout=5)
            self.dns_label.setText(r.stdout.strip() or "N/A")
            # MAC
            for iface in interfaces:
                if iface.get('ipv4'):
                    try:
                        r2 = subprocess.run(f"cat /sys/class/net/{iface['name']}/address", shell=True, capture_output=True, text=True, timeout=5)
                        if r2.stdout.strip():
                            self.mac_label.setText(r2.stdout.strip())
                            break
                    except: pass
        except:
            pass

    def _show_network(self):
        self._highlight_nav("Rede")
        self.stack.setCurrentWidget(self._network_page)
        self._refresh_network()
        self.statusBar().showMessage("🌐 Informações de Rede")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: MONITOR DE TRÁFEGO
    # ══════════════════════════════════════════════════════════
    def _build_traffic_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        header = QHBoxLayout()
        header.addWidget(self._title_label("📡 Monitor de Tráfego de Rede"))
        header.addStretch()
        self.traffic_status_label = QLabel("🔄 Monitorando...")
        self.traffic_status_label.setStyleSheet("color: #22D3EE; font-size: 12px; font-weight: bold;")
        header.addWidget(self.traffic_status_label)
        layout.addLayout(header)

        # Cards de tráfego
        traffic_cards = QGridLayout()
        traffic_cards.setSpacing(12)

        self.download_speed_card = InfoCard("Download (atual)", "0 bps", "⬇️", None, "#22D3EE")
        traffic_cards.addWidget(self.download_speed_card, 0, 0)
        self.upload_speed_card = InfoCard("Upload (atual)", "0 bps", "⬆️", None, "#6A11CB")
        traffic_cards.addWidget(self.upload_speed_card, 0, 1)
        self.total_download_card = InfoCard("Total Download", "0 B", "📥", None, "#10B981")
        traffic_cards.addWidget(self.total_download_card, 0, 2)
        self.total_upload_card = InfoCard("Total Upload", "0 B", "📤", None, "#F59E0B")
        traffic_cards.addWidget(self.total_upload_card, 1, 0)
        self.active_conns_card = InfoCard("Conexões Ativas", "0", "🔌", None, "#EC4899")
        traffic_cards.addWidget(self.active_conns_card, 1, 1)
        self.interface_selector_card = InfoCard("Interface Ativa", "N/A", "🌐", None, "#F8FAFC")
        traffic_cards.addWidget(self.interface_selector_card, 1, 2)

        layout.addLayout(traffic_cards)

        # Tabela de tráfego por interface
        self.traffic_table = QTableWidget()
        self.traffic_table.setColumnCount(7)
        self.traffic_table.setHorizontalHeaderLabels([
            "Interface", "Download Atual", "Upload Atual", "Total Recebido",
            "Total Enviado", "Erros RX", "Erros TX"
        ])
        self.traffic_table.setColumnWidth(0, 120)
        self.traffic_table.setColumnWidth(1, 120)
        self.traffic_table.setColumnWidth(2, 120)
        self.traffic_table.setColumnWidth(3, 120)
        self.traffic_table.setColumnWidth(4, 120)
        self.traffic_table.setColumnWidth(5, 80)
        self.traffic_table.setColumnWidth(6, 80)
        self.traffic_table.verticalHeader().setVisible(False)
        self.traffic_table.setStyleSheet(self._table_style())
        layout.addWidget(self.traffic_table)

        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._traffic_page = QWidget()
        t_layout = QVBoxLayout(self._traffic_page)
        t_layout.setContentsMargins(0, 0, 0, 0)
        t_layout.addWidget(scroll)
        self.stack.addWidget(self._traffic_page)

        # Thread de monitoramento
        self._traffic_thread = TrafficMonitorThread(self)
        self._traffic_thread.data_ready.connect(self._update_traffic_display)
        self._traffic_thread.start()

    def _update_traffic_display(self, speeds):
        """Atualiza a UI com dados de tráfego."""
        try:
            # Totaliza todas as interfaces
            total_download = 0
            total_upload = 0
            interface_data = []

            for iface, data in speeds.items():
                down_bps = data['download']
                up_bps = data['upload']
                total_download += down_bps
                total_upload += up_bps
                interface_data.append((
                    iface, down_bps, up_bps,
                    data['total_recv'], data['total_sent']
                ))

            # Atualiza cards
            self.download_speed_card.update_value(SystemUtils.format_bits_per_sec(total_download))
            self.upload_speed_card.update_value(SystemUtils.format_bits_per_sec(total_upload))

            if interface_data:
                main_iface = interface_data[0][0]
                self.interface_selector_card.update_value(main_iface)

                # Total acumulado (da primeira interface monitorada)
                total_recv = interface_data[0][3]
                total_sent = interface_data[0][4]
                self.total_download_card.update_value(SystemUtils.format_bytes(total_recv))
                self.total_upload_card.update_value(SystemUtils.format_bytes(total_sent))

            # Conexões ativas
            conns = SystemUtils.get_network_connections()
            estab = sum(1 for c in conns if c['status'] == 'ESTABLISHED')
            self.active_conns_card.update_value(f"{estab} estabelecidas / {len(conns)} total")

            # Preenche tabela
            self.traffic_table.setRowCount(len(interface_data))
            for i, (iface, down, up, recv, sent) in enumerate(interface_data):
                items = [
                    (iface, QColor(248, 250, 252)),
                    (SystemUtils.format_bits_per_sec(down), QColor(52, 211, 153)),
                    (SystemUtils.format_bits_per_sec(up), QColor(96, 165, 250)),
                    (SystemUtils.format_bytes(recv), QColor(147, 197, 253)),
                    (SystemUtils.format_bytes(sent), QColor(196, 181, 253)),
                    ("0", QColor(148, 163, 184)),  # erros simplificados
                    ("0", QColor(148, 163, 184)),
                ]
                for j, (text, color) in enumerate(items):
                    item = QTableWidgetItem(text)
                    item.setForeground(color)
                    self.traffic_table.setItem(i, j, item)

        except Exception as e:
            print(f"Traffic update error: {e}")

    def _show_traffic(self):
        self._highlight_nav("Tráfego")
        self.stack.setCurrentWidget(self._traffic_page)
        self.statusBar().showMessage("📡 Monitor de Tráfego em tempo real")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: CONEXÕES DE REDE
    # ══════════════════════════════════════════════════════════
    def _build_connections_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        header.addWidget(self._title_label("🔌 Conexões de Rede Ativas"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Atualizar")
        btn_refresh.clicked.connect(self._refresh_connections)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        self.conn_filter = QLineEdit()
        self.conn_filter.setPlaceholderText("🔍 Filtrar...")
        self.conn_filter.setFixedWidth(200)
        self.conn_filter.setStyleSheet("background-color: #0B0F19; color: #F8FAFC; border: 1px solid #1E293B; border-radius: 6px; padding: 6px 12px;")
        self.conn_filter.textChanged.connect(self._filter_connections)
        header.addWidget(self.conn_filter)

        layout.addLayout(header)

        self.connections_table = QTableWidget()
        self.connections_table.setColumnCount(7)
        self.connections_table.setHorizontalHeaderLabels([
            "Protocolo", "Endereço Local", "Porta Local",
            "Endereço Remoto", "Porta Remota", "Status", "PID"
        ])
        self.connections_table.setColumnWidth(0, 60)
        self.connections_table.setColumnWidth(1, 160)
        self.connections_table.setColumnWidth(2, 70)
        self.connections_table.setColumnWidth(3, 160)
        self.connections_table.setColumnWidth(4, 70)
        self.connections_table.setColumnWidth(5, 100)
        self.connections_table.setColumnWidth(6, 60)
        self.connections_table.verticalHeader().setVisible(False)
        self.connections_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.connections_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.connections_table.setStyleSheet(self._table_style())
        layout.addWidget(self.connections_table)

        self.conn_count_label = QLabel("Nenhuma conexão")
        self.conn_count_label.setStyleSheet("color: #64748B; font-size: 11px;")
        layout.addWidget(self.conn_count_label)
        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._connections_page = QWidget()
        c_layout = QVBoxLayout(self._connections_page)
        c_layout.setContentsMargins(0, 0, 0, 0)
        c_layout.addWidget(scroll)
        self.stack.addWidget(self._connections_page)

        self._all_connections = []
        self._refresh_connections()

    def _refresh_connections(self):
        self._all_connections = SystemUtils.get_network_connections()
        self._filter_connections()

    def _filter_connections(self):
        text = self.conn_filter.text().lower().strip()
        filtered = [c for c in self._all_connections
                    if not text or text in str(c['local']).lower() or text in str(c['remote']).lower() or text in c['status'].lower()]
        self._populate_connections_table(filtered)
        estab = sum(1 for c in filtered if c['status'] == 'ESTABLISHED')
        listen = sum(1 for c in filtered if c['status'] == 'LISTEN')
        self.conn_count_label.setText(f"{len(filtered)} conexões • {estab} estabelecidas • {listen} escutando")

    def _populate_connections_table(self, conns):
        self.connections_table.setRowCount(len(conns))
        for i, c in enumerate(conns):
            proto = f"{c['family'][-2:]}/{c['type']}"
            pi = QTableWidgetItem(proto)
            pi.setForeground(QColor(147, 197, 253))
            self.connections_table.setItem(i, 0, pi)

            if ':' in c['local']:
                local_parts = c['local'].rsplit(':', 1)
                local_addr = local_parts[0]
                local_port = local_parts[1] if len(local_parts) > 1 else ""
            else:
                local_addr = c['local']
                local_port = ""

            la = QTableWidgetItem(local_addr)
            la.setForeground(QColor(248, 250, 252))
            self.connections_table.setItem(i, 1, la)
            lp = QTableWidgetItem(local_port)
            lp.setForeground(QColor(52, 211, 153))
            lp.setTextAlignment(Qt.AlignCenter)
            self.connections_table.setItem(i, 2, lp)

            remote = c.get('remote', '')
            if ':' in remote:
                rem_parts = remote.rsplit(':', 1)
                rem_addr = rem_parts[0]
                rem_port = rem_parts[1] if len(rem_parts) > 1 else ""
            else:
                rem_addr = remote
                rem_port = ""

            ra = QTableWidgetItem(rem_addr)
            ra.setForeground(QColor(226, 232, 240))
            self.connections_table.setItem(i, 3, ra)
            rp = QTableWidgetItem(rem_port)
            rp.setForeground(QColor(251, 191, 36))
            rp.setTextAlignment(Qt.AlignCenter)
            self.connections_table.setItem(i, 4, rp)

            status = c.get('status', '')
            si = QTableWidgetItem(status)
            if status == 'ESTABLISHED':
                si.setForeground(QColor(52, 211, 153))
            elif status == 'LISTEN':
                si.setForeground(QColor(96, 165, 250))
            else:
                si.setForeground(QColor(148, 163, 184))
            self.connections_table.setItem(i, 5, si)

            pid = str(c.get('pid', '')) if c.get('pid') else ''
            pi2 = QTableWidgetItem(pid)
            pi2.setForeground(QColor(196, 181, 253))
            pi2.setTextAlignment(Qt.AlignCenter)
            self.connections_table.setItem(i, 6, pi2)

    def _show_connections(self):
        self._highlight_nav("Conexões")
        self.stack.setCurrentWidget(self._connections_page)
        self._refresh_connections()
        self.statusBar().showMessage("🔌 Conexões de Rede")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: GERENCIADOR DE PROCESSOS
    # ══════════════════════════════════════════════════════════
    def _build_processes_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        header = QHBoxLayout()
        header.addWidget(self._title_label("⚙️ Gerenciador de Processos"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Atualizar")
        btn_refresh.clicked.connect(self._refresh_processes)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        self.proc_filter = QLineEdit()
        self.proc_filter.setPlaceholderText("🔍 Filtrar processos...")
        self.proc_filter.setFixedWidth(250)
        self.proc_filter.setStyleSheet("background-color: #0B0F19; color: #F8FAFC; border: 1px solid #1E293B; border-radius: 6px; padding: 6px 12px;")
        self.proc_filter.textChanged.connect(self._filter_processes)
        header.addWidget(self.proc_filter)
        layout.addLayout(header)

        self.process_table = QTableWidget()
        self.process_table.setColumnCount(8)
        self.process_table.setHorizontalHeaderLabels([
            "PID", "Nome", "Usuário", "CPU%", "Mem%", "Mem (MB)", "Status", "Prioridade"
        ])
        self.process_table.setColumnWidth(0, 60)
        self.process_table.setColumnWidth(1, 180)
        self.process_table.setColumnWidth(2, 80)
        self.process_table.setColumnWidth(3, 60)
        self.process_table.setColumnWidth(4, 60)
        self.process_table.setColumnWidth(5, 80)
        self.process_table.setColumnWidth(6, 80)
        self.process_table.setColumnWidth(7, 70)
        self.process_table.verticalHeader().setVisible(False)
        self.process_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.process_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.process_table.setSortingEnabled(True)
        self.process_table.setStyleSheet(self._table_style())
        layout.addWidget(self.process_table)

        # Ações
        actions = QHBoxLayout()
        for text, color, cb in [
            ("⛔ Matar Processo", "#EF4444", self._kill_process),
            ("💀 Matar Forçado (SIGKILL)", "#DC2626", self._kill_process_force),
            ("⏸️ Pausar (SIGSTOP)", "#F59E0B", self._stop_process),
            ("▶️ Continuar (SIGCONT)", "#10B981", self._cont_process),
            ("📋 Detalhes", "#6A11CB", self._process_details),
        ]:
            btn = QPushButton(text)
            btn.clicked.connect(cb)
            btn.setStyleSheet(f"background-color: {color}; color: #FFF; border: none; border-radius: 6px; padding: 8px 16px; font-size: 11px; font-weight: bold;")
            actions.addWidget(btn)
        actions.addStretch()
        layout.addLayout(actions)

        # Label de contagem
        self.proc_count_label = QLabel("Carregando processos...")
        self.proc_count_label.setStyleSheet("color: #64748B; font-size: 11px;")
        layout.addWidget(self.proc_count_label)
        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._processes_page = QWidget()
        p_layout = QVBoxLayout(self._processes_page)
        p_layout.setContentsMargins(0, 0, 0, 0)
        p_layout.addWidget(scroll)
        self.stack.addWidget(self._processes_page)

        self._all_processes = []
        self._refresh_processes()

    def _refresh_processes(self):
        self._all_processes = []
        try:
            for proc in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_percent', 'memory_info', 'status', 'nice']):
                try:
                    info = proc.info
                    self._all_processes.append((
                        info['pid'],
                        info['name'] or '?',
                        info['username'] or '?',
                        info['cpu_percent'] or 0,
                        info['memory_percent'] or 0,
                        (info['memory_info'].rss if info['memory_info'] else 0) / 1024 / 1024,
                        info['status'] or '?',
                        info['nice'] if info['nice'] is not None else 0
                    ))
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
        except: pass
        self._filter_processes()

    def _filter_processes(self):
        text = self.proc_filter.text().lower().strip()
        filtered = [p for p in self._all_processes
                    if not text or text in str(p[1]).lower() or text in str(p[2]).lower()]
        self._populate_process_table(filtered)
        self.proc_count_label.setText(f"{len(filtered)} processos (total: {len(self._all_processes)})")

    def _populate_process_table(self, procs):
        procs_sorted = sorted(procs, key=lambda x: x[3], reverse=True)[:200]
        self.process_table.setRowCount(len(procs_sorted))
        for i, (pid, name, user, cpu, mem_per, mem_mb, status, nice) in enumerate(procs_sorted):
            pi = QTableWidgetItem(str(pid))
            pi.setForeground(QColor(148, 163, 184))
            self.process_table.setItem(i, 0, pi)

            ni = QTableWidgetItem(name[:40])
            ni.setForeground(QColor(248, 250, 252))
            self.process_table.setItem(i, 1, ni)

            ui = QTableWidgetItem(user[:15])
            ui.setForeground(QColor(147, 197, 253))
            self.process_table.setItem(i, 2, ui)

            ci = QTableWidgetItem(f"{cpu:.1f}")
            ci.setForeground(QColor(52, 211, 153))
            ci.setTextAlignment(Qt.AlignCenter)
            self.process_table.setItem(i, 3, ci)

            mi = QTableWidgetItem(f"{mem_per:.1f}")
            mi.setForeground(QColor(251, 191, 36))
            mi.setTextAlignment(Qt.AlignCenter)
            self.process_table.setItem(i, 4, mi)

            mbi = QTableWidgetItem(f"{mem_mb:.0f}")
            mbi.setForeground(QColor(196, 181, 253))
            mbi.setTextAlignment(Qt.AlignCenter)
            self.process_table.setItem(i, 5, mbi)

            si = QTableWidgetItem(status)
            if status == 'running':
                si.setForeground(QColor(52, 211, 153))
            elif status == 'sleeping':
                si.setForeground(QColor(148, 163, 184))
            elif status == 'stopped':
                si.setForeground(QColor(239, 68, 68))
            else:
                si.setForeground(QColor(100, 116, 139))
            self.process_table.setItem(i, 6, si)

            ni2 = QTableWidgetItem(str(nice))
            ni2.setForeground(QColor(147, 197, 253))
            ni2.setTextAlignment(Qt.AlignCenter)
            self.process_table.setItem(i, 7, ni2)

    def _get_selected_pid(self):
        rows = set()
        for idx in self.process_table.selectedIndexes():
            rows.add(idx.row())
        if not rows:
            QMessageBox.information(self, "Nada Selecionado", "Selecione um processo na tabela.")
            return None
        try:
            return int(self.process_table.item(list(rows)[0], 0).text())
        except:
            return None

    def _kill_process(self):
        pid = self._get_selected_pid()
        if not pid: return
        name = self.process_table.item(self.process_table.currentRow(), 1).text()
        resposta = QMessageBox.question(self, "⛔ Matar Processo",
                                        f"Encerrar o processo '{name}' (PID {pid})?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            try:
                os.kill(pid, 15)  # SIGTERM
                QMessageBox.information(self, "✅ OK", f"Sinal SIGTERM enviado para PID {pid}")
                self._refresh_processes()
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))

    def _kill_process_force(self):
        pid = self._get_selected_pid()
        if not pid: return
        name = self.process_table.item(self.process_table.currentRow(), 1).text()
        resposta = QMessageBox.question(self, "💀 Matar Forçado",
                                        f"Matar FORÇADAMENTE '{name}' (PID {pid})?\nIsso pode causar perda de dados!",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            try:
                os.kill(pid, 9)  # SIGKILL
                QMessageBox.information(self, "✅ OK", f"Sinal SIGKILL enviado para PID {pid}")
                self._refresh_processes()
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))

    def _stop_process(self):
        pid = self._get_selected_pid()
        if not pid: return
        try:
            os.kill(pid, 19)  # SIGSTOP
            QMessageBox.information(self, "⏸️ Pausado", f"Processo PID {pid} pausado.")
            self._refresh_processes()
        except Exception as e:
            QMessageBox.critical(self, "Erro", str(e))

    def _cont_process(self):
        pid = self._get_selected_pid()
        if not pid: return
        try:
            os.kill(pid, 18)  # SIGCONT
            QMessageBox.information(self, "▶️ Continuado", f"Processo PID {pid} continuado.")
            self._refresh_processes()
        except Exception as e:
            QMessageBox.critical(self, "Erro", str(e))

    def _process_details(self):
        pid = self._get_selected_pid()
        if not pid: return
        try:
            proc = psutil.Process(pid)
            info = f"""
📋 Detalhes do Processo
{'='*40}

PID: {pid}
Nome: {proc.name()}
Usuário: {proc.username()}
Status: {proc.status()}
Prioridade (nice): {proc.nice()}
CPU%: {proc.cpu_percent():.1f}%
Memória: {SystemUtils.format_bytes(proc.memory_info().rss)}
Memória Virtual: {SystemUtils.format_bytes(proc.memory_info().vms)}
Threads: {proc.num_threads()}
Arquivos abertos: {len(proc.open_files())}
Conexões: {len(proc.connections())}
Tempo de CPU: {timedelta(seconds=proc.cpu_times().user + proc.cpu_times().system)}
Criado em: {datetime.fromtimestamp(proc.create_time()).strftime('%Y-%m-%d %H:%M:%S')}
Linha de comando: {' '.join(proc.cmdline()[:5])}
Diretório de trabalho: {proc.cwd()}
"""
            if hasattr(proc, 'children'):
                children = proc.children()
                info += f"Processos filhos: {len(children)}\n"

            dlg = QDialog(self)
            dlg.setWindowTitle(f"📋 Detalhes: {proc.name()} (PID {pid})")
            dlg.setMinimumSize(600, 500)
            dlg.setStyleSheet("background-color: #0F172A;")
            dl = QVBoxLayout(dlg)
            te = QTextEdit()
            te.setReadOnly(True)
            te.setPlainText(info)
            te.setStyleSheet("background-color: #0B0F19; color: #E2E8F0; border: 1px solid #1E293B; border-radius: 6px; font-family: monospace; font-size: 11px; padding: 10px;")
            dl.addWidget(te)
            b = QPushButton("✕ Fechar")
            b.clicked.connect(dlg.accept)
            b.setStyleSheet("background-color: #1E293B; color: #22D3EE; border: 1px solid #334155; border-radius: 6px; padding: 8px 20px;")
            dl.addWidget(b, alignment=Qt.AlignRight)
            dlg.exec_()
        except psutil.NoSuchProcess:
            QMessageBox.warning(self, "Erro", "Processo não encontrado.")
        except Exception as e:
            QMessageBox.critical(self, "Erro", str(e))

    def _show_processes(self):
        self._highlight_nav("Processos")
        self.stack.setCurrentWidget(self._processes_page)
        self._refresh_processes()
        self.statusBar().showMessage("⚙️ Gerenciador de Processos")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: FIREWALL (UFW)
    # ══════════════════════════════════════════════════════════
    def _build_firewall_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        header = QHBoxLayout()
        header.addWidget(self._title_label("🛡️ Firewall (UFW)"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Atualizar")
        btn_refresh.clicked.connect(self._refresh_firewall)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        layout.addLayout(header)

        # Status
        self.firewall_status_label = QLabel("Verificando status do UFW...")
        self.firewall_status_label.setFont(QFont("Segoe UI", 14, QFont.Bold))
        self.firewall_status_label.setStyleSheet("color: #F8FAFC; padding: 10px;")
        layout.addWidget(self.firewall_status_label)

        # Controles
        ctrl_group = QGroupBox("🎮 Controles")
        ctrl_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px; padding: 16px; }
            QGroupBox::title { padding: 2px 8px; color: #94A3B8; }
            QPushButton { border: none; border-radius: 6px; padding: 10px 20px;
                font-size: 12px; font-weight: bold; color: #FFF; }
        """)
        ctrl_layout = QHBoxLayout(ctrl_group)

        btn_enable = QPushButton("🟢 Ativar UFW")
        btn_enable.clicked.connect(self._ufw_enable)
        btn_enable.setStyleSheet("background-color: #10B981;")
        ctrl_layout.addWidget(btn_enable)

        btn_disable = QPushButton("🔴 Desativar UFW")
        btn_disable.clicked.connect(self._ufw_disable)
        btn_disable.setStyleSheet("background-color: #EF4444;")
        ctrl_layout.addWidget(btn_disable)

        btn_reload = QPushButton("🔄 Recarregar UFW")
        btn_reload.clicked.connect(self._ufw_reload)
        btn_reload.setStyleSheet("background-color: #F59E0B;")
        ctrl_layout.addWidget(btn_reload)

        btn_reset = QPushButton("🔄 Resetar UFW")
        btn_reset.clicked.connect(self._ufw_reset)
        btn_reset.setStyleSheet("background-color: #DC2626;")
        ctrl_layout.addWidget(btn_reset)

        layout.addWidget(ctrl_group)

        # Regras
        rules_group = QGroupBox("📋 Regras Atuais")
        rules_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px; padding: 16px; margin-top: 8px; }
            QGroupBox::title { padding: 2px 8px; color: #94A3B8; }
        """)
        rules_layout = QVBoxLayout(rules_group)
        self.rules_text = QTextEdit()
        self.rules_text.setReadOnly(True)
        self.rules_text.setStyleSheet("""
            QTextEdit { background-color: #0B0F19; color: #E2E8F0;
            border: 1px solid #1E293B; border-radius: 6px;
            font-family: 'Consolas', monospace; font-size: 11px; padding: 8px; }
        """)
        self.rules_text.setMaximumHeight(250)
        rules_layout.addWidget(self.rules_text)

        btn_add_rule = QPushButton("➕ Adicionar Regra...")
        btn_add_rule.clicked.connect(self._ufw_add_rule)
        btn_add_rule.setStyleSheet("""
            QPushButton { background-color: #6A11CB; color: #FFF;
            border: none; border-radius: 6px; padding: 10px 20px;
            font-size: 12px; font-weight: bold; }
            QPushButton:hover { background-color: #8B5CF6; }
        """)
        rules_layout.addWidget(btn_add_rule, alignment=Qt.AlignRight)

        layout.addWidget(rules_group)

        # Logs
        log_group = QGroupBox("📄 Logs do Firewall")
        log_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px; padding: 16px; margin-top: 8px; }
            QGroupBox::title { padding: 2px 8px; color: #94A3B8; }
        """)
        log_layout = QVBoxLayout(log_group)
        self.firewall_log = QTextEdit()
        self.firewall_log.setReadOnly(True)
        self.firewall_log.setStyleSheet("""
            QTextEdit { background-color: #0B0F19; color: #94A3B8;
            border: 1px solid #1E293B; border-radius: 6px;
            font-family: 'Consolas', monospace; font-size: 10px; padding: 8px; }
        """)
        self.firewall_log.setMaximumHeight(120)
        log_layout.addWidget(self.firewall_log)
        layout.addWidget(log_group)

        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._firewall_page = QWidget()
        f_layout = QVBoxLayout(self._firewall_page)
        f_layout.setContentsMargins(0, 0, 0, 0)
        f_layout.addWidget(scroll)
        self.stack.addWidget(self._firewall_page)

        self._refresh_firewall()

    def _refresh_firewall(self):
        try:
            status = SystemUtils.get_ufw_status()
            if "Status: active" in status:
                self.firewall_status_label.setText("🟢 Firewall ATIVO")
                self.firewall_status_label.setStyleSheet("color: #10B981; font-size: 14px; font-weight: bold; padding: 10px;")
            elif "Status: inactive" in status:
                self.firewall_status_label.setText("🔴 Firewall INATIVO")
                self.firewall_status_label.setStyleSheet("color: #EF4444; font-size: 14px; font-weight: bold; padding: 10px;")
            else:
                self.firewall_status_label.setText(f"⚠️ {status[:80]}")
                self.firewall_status_label.setStyleSheet("color: #F59E0B; font-size: 14px; font-weight: bold; padding: 10px;")

            rules = SystemUtils.get_ufw_rules()
            self.rules_text.setPlainText(rules if rules else "Nenhuma regra configurada.")

            # Log
            try:
                result = subprocess.run(
                    "tail -20 /var/log/ufw.log 2>/dev/null || echo 'Sem logs disponíveis'",
                    shell=True, capture_output=True, text=True, timeout=5
                )
                self.firewall_log.setPlainText(result.stdout.strip()[:2000])
            except:
                self.firewall_log.setPlainText("Sem logs disponíveis.")

        except Exception as e:
            self.firewall_status_label.setText(f"❌ Erro: {str(e)}")
            self.rules_text.setPlainText("")
            self.firewall_log.setPlainText("")

    def _ufw_enable(self):
        self._run_fw_command("ufw --force enable", "Ativando UFW...")

    def _ufw_disable(self):
        self._run_fw_command("ufw disable", "Desativando UFW...")

    def _ufw_reload(self):
        self._run_fw_command("ufw reload", "Recarregando UFW...")

    def _ufw_reset(self):
        resposta = QMessageBox.question(self, "🔄 Resetar UFW",
                                        "Resetar TODAS as regras do UFW para padrão?\nIsso desativará o firewall.",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            self._run_fw_command("ufw --force reset", "Resetando UFW...")

    def _ufw_add_rule(self):
        items = ("Permitir porta (tcp)", "Permitir porta (udp)", "Negar porta (tcp)",
                 "Permitir IP", "Negar IP", "Permitir serviço (por nome)")
        item, ok = QInputDialog.getItem(self, "➕ Nova Regra", "Tipo de regra:", items, 0, False)
        if not ok: return

        if "porta" in item:
            port, ok = QInputDialog.getInt(self, "Porta", "Número da porta:", 80, 1, 65535)
            if not ok: return
            proto = "tcp" if "tcp" in item else "udp"
            action = "allow" if "Permitir" in item else "deny"
            self._run_fw_command(f"ufw {action} {port}/{proto}",
                                 f"Adicionando regra: {action} {port}/{proto}...")
        elif "IP" in item:
            ip, ok = QInputDialog.getText(self, "Endereço IP", "Digite o IP:")
            if not ok or not ip.strip(): return
            action = "allow" if "Permitir" in item else "deny"
            self._run_fw_command(f"ufw {action} from {ip.strip()}",
                                 f"Adicionando regra: {action} from {ip.strip()}...")
        elif "serviço" in item:
            svc, ok = QInputDialog.getText(self, "Nome do Serviço", "Ex: ssh, http, https:")
            if not ok or not svc.strip(): return
            self._run_fw_command(f"ufw allow {svc.strip()}",
                                 f"Adicionando regra: allow {svc.strip()}...")

    def _run_fw_command(self, cmd, title):
        self.statusBar().showMessage(f"⏳ {title}")
        QApplication.processEvents()
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            output = result.stdout if result.returncode == 0 else result.stderr
            if result.returncode == 0:
                QMessageBox.information(self, "✅ Sucesso", f"{title}\n\n{output[:500]}")
            else:
                QMessageBox.critical(self, "❌ Erro", f"{title}\n\n{output[:500]}")
            self._refresh_firewall()
            self.statusBar().showMessage(f"✅ {title} concluído")
        except Exception as e:
            QMessageBox.critical(self, "Erro", str(e))

    def _show_firewall(self):
        self._highlight_nav("Firewall")
        self.stack.setCurrentWidget(self._firewall_page)
        self._refresh_firewall()
        self.statusBar().showMessage("🛡️ Firewall UFW")

    # ══════════════════════════════════════════════════════════
    #  PÁGINAS EXISTENTES — USUÁRIOS, DISCOS, PACOTES
    # ══════════════════════════════════════════════════════════

    # (Mantidas do código original — resumidas aqui por brevidade)

    def _build_users_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        header = QHBoxLayout()
        header.addWidget(self._title_label("👥 Gerenciamento de Usuários"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Recarregar")
        btn_refresh.clicked.connect(self._refresh_users)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        layout.addLayout(header)

        self.users_table = QTableWidget()
        self.users_table.setColumnCount(6)
        self.users_table.setHorizontalHeaderLabels(["", "Usuário", "UID", "GID", "Home", "Shell"])
        self.users_table.setColumnWidth(0, 36)
        self.users_table.setColumnWidth(1, 150)
        self.users_table.setColumnWidth(2, 60)
        self.users_table.setColumnWidth(3, 60)
        self.users_table.setColumnWidth(4, 200)
        self.users_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.Stretch)
        self.users_table.verticalHeader().setVisible(False)
        self.users_table.setStyleSheet(self._table_style())
        layout.addWidget(self.users_table)

        actions = QHBoxLayout()
        for text, color, cb in [
            ("➕ Adicionar", "#10B981", self._add_user),
            ("🗑️ Remover", "#EF4444", self._remove_user),
            ("🔑 Senha", "#F59E0B", self._change_password),
        ]:
            btn = QPushButton(text)
            btn.clicked.connect(cb)
            btn.setStyleSheet(f"background-color: {color}; color: #FFF; border: none; border-radius: 6px; padding: 8px 16px; font-size: 11px; font-weight: bold;")
            actions.addWidget(btn)
        actions.addStretch()
        layout.addLayout(actions)
        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._users_page = QWidget()
        u_layout = QVBoxLayout(self._users_page)
        u_layout.setContentsMargins(0, 0, 0, 0)
        u_layout.addWidget(scroll)
        self.stack.addWidget(self._users_page)
        self._refresh_users()

    def _refresh_users(self):
        users = SystemUtils.get_users()
        self.users_table.setRowCount(len(users))
        for i, user in enumerate(users):
            icon = "👑" if user['is_root'] else "👤"
            ii = QTableWidgetItem(icon)
            ii.setTextAlignment(Qt.AlignCenter)
            ii.setForeground(QColor(251, 191, 36) if user['is_root'] else QColor(148, 163, 184))
            self.users_table.setItem(i, 0, ii)
            ni = QTableWidgetItem(user['name'])
            ni.setForeground(QColor(248, 250, 252))
            self.users_table.setItem(i, 1, ni)
            ui = QTableWidgetItem(str(user['uid']))
            ui.setForeground(QColor(147, 197, 253))
            self.users_table.setItem(i, 2, ui)
            gi = QTableWidgetItem(str(user['gid']))
            gi.setForeground(QColor(147, 197, 253))
            self.users_table.setItem(i, 3, gi)
            hi = QTableWidgetItem(user['home'])
            hi.setForeground(QColor(196, 181, 253))
            self.users_table.setItem(i, 4, hi)
            si = QTableWidgetItem(user['shell'])
            si.setForeground(QColor(148, 163, 184))
            self.users_table.setItem(i, 5, si)

    def _add_user(self):
        name, ok = QInputDialog.getText(self, "➕ Adicionar Usuário", "Nome:")
        if ok and name.strip():
            self._run_system_cmd(f"useradd -m -s /bin/bash {name.strip()}",
                                 f"Usuário {name.strip()} criado")

    def _remove_user(self):
        rows = set()
        for idx in self.users_table.selectedIndexes():
            rows.add(idx.row())
        if not rows: return
        username = self.users_table.item(list(rows)[0], 1).text()
        resposta = QMessageBox.question(self, "🗑️ Remover", f"Remover '{username}'?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            self._run_system_cmd(f"userdel -r {username}", f"Usuário {username} removido")

    def _change_password(self):
        rows = set()
        for idx in self.users_table.selectedIndexes():
            rows.add(idx.row())
        if not rows: return
        username = self.users_table.item(list(rows)[0], 1).text()
        pwd, ok = QInputDialog.getText(self, "🔑 Senha", f"Nova senha para {username}:", QLineEdit.Password)
        if ok and pwd.strip():
            try:
                proc = subprocess.run(f"echo '{username}:{pwd}' | chpasswd", shell=True, capture_output=True, text=True, timeout=10)
                if proc.returncode == 0:
                    QMessageBox.information(self, "✅ OK", f"Senha de {username} alterada.")
                    self._refresh_users()
                else:
                    QMessageBox.critical(self, "❌ Erro", f"Falha: {proc.stderr}")
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))

    def _show_users(self):
        self._highlight_nav("Usuários")
        self.stack.setCurrentWidget(self._users_page)
        self._refresh_users()
        self.statusBar().showMessage("👥 Usuários")

    def _build_disks_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        header = QHBoxLayout()
        header.addWidget(self._title_label("💿 Discos"))
        header.addStretch()
        btn_refresh = QPushButton("🔄 Atualizar")
        btn_refresh.clicked.connect(self._refresh_disks)
        btn_refresh.setStyleSheet("background-color: #2563EB; color: #FFF; border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold;")
        header.addWidget(btn_refresh)
        layout.addLayout(header)

        self.disks_table = QTableWidget()
        self.disks_table.setColumnCount(6)
        self.disks_table.setHorizontalHeaderLabels(["Dispositivo", "Montagem", "Tipo", "Usado", "Total", "Uso%"])
        self.disks_table.setColumnWidth(0, 150)
        self.disks_table.setColumnWidth(1, 180)
        self.disks_table.setColumnWidth(2, 80)
        self.disks_table.setColumnWidth(3, 100)
        self.disks_table.setColumnWidth(4, 100)
        self.disks_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.Stretch)
        self.disks_table.verticalHeader().setVisible(False)
        self.disks_table.setStyleSheet(self._table_style())
        layout.addWidget(self.disks_table)
        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._disks_page = QWidget()
        d_layout = QVBoxLayout(self._disks_page)
        d_layout.setContentsMargins(0, 0, 0, 0)
        d_layout.addWidget(scroll)
        self.stack.addWidget(self._disks_page)
        self._refresh_disks()

    def _refresh_disks(self):
        disks = SystemUtils.get_disk_info()
        self.disks_table.setRowCount(len(disks))
        for i, disk in enumerate(disks):
            di = QTableWidgetItem(disk['device'])
            di.setForeground(QColor(248, 250, 252))
            self.disks_table.setItem(i, 0, di)
            mi = QTableWidgetItem(disk['mountpoint'])
            mi.setForeground(QColor(147, 197, 253))
            self.disks_table.setItem(i, 1, mi)
            fi = QTableWidgetItem(disk['fstype'])
            fi.setForeground(QColor(196, 181, 253))
            self.disks_table.setItem(i, 2, fi)
            ui = QTableWidgetItem(SystemUtils.format_bytes(disk['used']))
            ui.setForeground(QColor(251, 191, 36))
            self.disks_table.setItem(i, 3, ui)
            ti = QTableWidgetItem(SystemUtils.format_bytes(disk['total']))
            ti.setForeground(QColor(52, 211, 153))
            self.disks_table.setItem(i, 4, ti)
            p = disk['percent']
            pi = QTableWidgetItem(f"{p:.1f}%")
            pi.setForeground(QColor(239, 68, 68) if p > 90 else QColor(251, 191, 36) if p > 70 else QColor(52, 211, 153))
            self.disks_table.setItem(i, 5, pi)

    def _show_disks(self):
        self._highlight_nav("Discos")
        self.stack.setCurrentWidget(self._disks_page)
        self._refresh_disks()
        self.statusBar().showMessage("💿 Discos")

    def _build_packages_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        header.addWidget(self._title_label("📦 Pacotes"))
        header.addStretch()
        for text, color, cb in [
            ("🔄 Atualizar Repositórios", "#2563EB", self._update_repos),
            ("⬆️ Upgrade Sistema", "#6A11CB", self._system_upgrade),
            ("🧹 Limpar Cache", "#0D9488", self._clean_cache),
        ]:
            btn = QPushButton(text)
            btn.clicked.connect(cb)
            btn.setStyleSheet(f"background-color: {color}; color: #FFF; border: none; border-radius: 6px; padding: 8px 16px; font-weight: bold;")
            header.addWidget(btn)
        layout.addLayout(header)

        info_group = QGroupBox("📊 Status")
        info_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px; padding: 16px; margin-top: 12px; }
            QGroupBox::title { padding: 2px 8px; color: #94A3B8; }
        """)
        info_layout = QFormLayout(info_group)
        self.pkg_info_label = QLabel("N/A")
        info_layout.addRow("Pacotes instalados:", self.pkg_info_label)
        self.pkg_upgradable_label = QLabel("N/A")
        info_layout.addRow("Atualizáveis:", self.pkg_upgradable_label)
        self.pkg_cache_label = QLabel("N/A")
        info_layout.addRow("Cache APT:", self.pkg_cache_label)
        layout.addWidget(info_group)

        actions_group = QGroupBox("⚡ Ações")
        actions_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px; padding: 16px; margin-top: 8px; }
            QGroupBox::title { padding: 2px 8px; color: #94A3B8; }
            QPushButton { background-color: #1E293B; color: #F8FAFC;
                border: 1px solid #334155; border-radius: 8px;
                padding: 10px 20px; font-size: 12px; font-weight: bold; }
            QPushButton:hover { background-color: #6A11CB; }
        """)
        actions_layout = QGridLayout(actions_group)
        for i, (text, cb) in enumerate([
            ("📥 Instalar", self._install_package),
            ("🗑️ Remover", self._remove_package),
            ("🔍 Buscar", self._search_package),
            ("📋 Detalhes", self._package_details),
            ("🧹 Autoremove", self._autoremove),
            ("📦 dpkg --configure -a", self._configure_dpkg),
        ]):
            btn = QPushButton(text)
            btn.clicked.connect(cb)
            actions_layout.addWidget(btn, i // 3, i % 3)
        layout.addWidget(actions_group)

        self.pkg_output = QTextEdit()
        self.pkg_output.setReadOnly(True)
        self.pkg_output.setStyleSheet("background-color: #0B0F19; color: #E2E8F0; border: 1px solid #1E293B; border-radius: 6px; font-family: monospace; font-size: 11px; padding: 8px;")
        self.pkg_output.setMaximumHeight(180)
        layout.addWidget(self.pkg_output)
        layout.addStretch()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)
        self._packages_page = QWidget()
        p_layout = QVBoxLayout(self._packages_page)
        p_layout.setContentsMargins(0, 0, 0, 0)
        p_layout.addWidget(scroll)
        self.stack.addWidget(self._packages_page)
        self._update_package_info()

    def _update_package_info(self):
        try:
            self.pkg_info_label.setText(str(SystemUtils.get_package_count()))
            r = subprocess.run("apt list --upgradable 2>/dev/null | grep -c upgradable || true", shell=True, capture_output=True, text=True, timeout=10)
            self.pkg_upgradable_label.setText(f"{r.stdout.strip()} pacote(s)")
            r = subprocess.run("du -sh /var/cache/apt/archives/ 2>/dev/null | cut -f1", shell=True, capture_output=True, text=True, timeout=10)
            self.pkg_cache_label.setText(r.stdout.strip() or "N/A")
        except:
            pass

    def _install_package(self):
        pkg, ok = QInputDialog.getText(self, "📥 Instalar", "Nome do pacote:")
        if ok and pkg.strip():
            self._run_pkg_cmd(f"apt install -y {pkg.strip()}", f"Instalando {pkg.strip()}...")

    def _remove_package(self):
        pkg, ok = QInputDialog.getText(self, "🗑️ Remover", "Nome do pacote:")
        if ok and pkg.strip():
            self._run_pkg_cmd(f"apt remove -y {pkg.strip()}", f"Removendo {pkg.strip()}...")

    def _search_package(self):
        term, ok = QInputDialog.getText(self, "🔍 Buscar", "Termo:")
        if ok and term.strip():
            self._run_pkg_cmd(f"apt search {term.strip()} 2>/dev/null | head -50", f"Buscando '{term.strip()}'...")

    def _package_details(self):
        pkg, ok = QInputDialog.getText(self, "📋 Detalhes", "Nome do pacote:")
        if ok and pkg.strip():
            self._run_pkg_cmd(f"apt show {pkg.strip()} 2>/dev/null || dpkg -s {pkg.strip()} 2>/dev/null", f"Detalhes de {pkg.strip()}...")

    def _update_repos(self):
        self._run_pkg_cmd("apt update 2>&1", "Atualizando repositórios...")

    def _system_upgrade(self):
        resposta = QMessageBox.question(self, "⬆️ Upgrade", "Realizar upgrade completo?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            self._run_pkg_cmd("apt full-upgrade -y 2>&1", "Upgrade completo...")

    def _autoremove(self):
        resposta = QMessageBox.question(self, "🧹 Autoremove", "Remover pacotes órfãos?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            self._run_pkg_cmd("apt autoremove -y 2>&1", "Removendo órfãos...")

    def _clean_cache(self):
        self._run_pkg_cmd("apt clean 2>&1", "Limpando cache...")

    def _configure_dpkg(self):
        self._run_pkg_cmd("dpkg --configure -a 2>&1", "Reconfigurando pendentes...")

    def _run_pkg_cmd(self, cmd, title):
        self.pkg_output.append(f"\n{'='*60}\n⏳ {title}\n$ {cmd}")
        self.statusBar().showMessage(f"⏳ {title}")
        QApplication.processEvents()
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
            output = result.stdout if result.returncode == 0 else result.stderr
            self.pkg_output.append(output[:3000])
            if result.returncode == 0:
                self.pkg_output.append(f"\n✅ Concluído (código {result.returncode})")
                self.statusBar().showMessage(f"✅ {title}")
            else:
                self.pkg_output.append(f"\n❌ Falhou (código {result.returncode})")
                self.statusBar().showMessage(f"❌ {title}")
            self._update_package_info()
        except subprocess.TimeoutExpired:
            self.pkg_output.append("\n⏱️ Tempo limite excedido.")
        except Exception as e:
            self.pkg_output.append(f"\n❌ Erro: {str(e)}")

    def _show_packages(self):
        self._highlight_nav("Pacotes")
        self.stack.setCurrentWidget(self._packages_page)
        self._update_package_info()
        self.statusBar().showMessage("📦 Pacotes")

    # ══════════════════════════════════════════════════════════
    #  UTILITÁRIOS GERAIS
    # ══════════════════════════════════════════════════════════

    def _title_label(self, text):
        lbl = QLabel(text)
        lbl.setFont(QFont("Segoe UI", 16, QFont.Bold))
        lbl.setStyleSheet("color: #F8FAFC;")
        return lbl

    def _table_style(self):
        return """
            QTableWidget { background-color: #0B0F19; color: #E2E8F0;
            border: 1px solid #1E293B; border-radius: 8px; font-size: 11px; }
            QTableWidget::item { padding: 4px 6px; }
            QTableWidget::item:selected { background-color: #6A11CB; color: #FFF; }
            QHeaderView::section { background-color: #161E38; color: #22D3EE;
            border: 1px solid #1E293B; font-size: 10px; font-weight: bold; }
        """

    def _run_command(self, cmd):
        try:
            subprocess.Popen(cmd, shell=True)
        except Exception as e:
            QMessageBox.critical(self, "Erro", str(e))

    def _system_action(self, action):
        actions = {
            'shutdown': ("Desligar", "shutdown -h now"),
            'reboot': ("Reiniciar", "shutdown -r now"),
            'suspend': ("Suspender", "systemctl suspend"),
            'hibernate': ("Hibernar", "systemctl hibernate"),
        }
        name, cmd = actions.get(action, ("", ""))
        if not name:
            return
        resposta = QMessageBox.question(self, f"⚠️ {name}",
                                        f"{name} o sistema agora?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            try:
                subprocess.run(cmd, shell=True, timeout=5)
            except:
                pass

    def _run_system_cmd(self, cmd, success_msg):
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                QMessageBox.information(self, "✅ Sucesso", success_msg)
                self._refresh_users() if 'user' in cmd else None
            else:
                QMessageBox.critical(self, "❌ Erro", result.stderr[:500])
        except Exception as e:
            QMessageBox.critical(self, "Erro", str(e))

    def _load_initial_data(self):
        self._update_dashboard_data()

    def _show_about(self):
        os_info = SystemUtils.get_os_info()
        QMessageBox.about(self, "ℹ️ Sobre",
            f"""<h2>🖥️ Painel de Controle Debian</h2>
            <p>Versão 2.0 — Gerenciamento completo do sistema</p>
            <hr>
            <p><b>Sistema:</b> {os_info.get('os_name', 'N/A')}</p>
            <p><b>Kernel:</b> {os_info.get('kernel', 'N/A')}</p>
            <p><b>Arquitetura:</b> {os_info.get('arch', 'N/A')}</p>
            <hr>
            <p>12 abas de gerenciamento:</p>
            <ul>
                <li>Início (Dashboard), Monitor, Serviços</li>
                <li><b>⚡ Energia</b> — Suspender, hibernar, agendar, stats</li>
                <li><b>🌐 Rede</b> — Interfaces, IPs, gateway</li>
                <li><b>📡 Tráfego</b> — Download/upload em tempo real</li>
                <li><b>🔌 Conexões</b> — Todas as conexões ativas</li>
                <li><b>⚙️ Processos</b> — Matar, pausar, detalhes</li>
                <li><b>🛡️ Firewall</b> — UFW: ativar, regras, logs</li>
                <li>Usuários, Discos, Pacotes</li>
            </ul>
            <p><i>Desenvolvido para FydelisTechOS</i></p>""")

    def _show_docs(self):
        QMessageBox.information(self, "📖 Documentação",
            "Painel de Controle FydelisTechOS v2.0\n\n"
            "Abas disponíveis:\n"
            "🏠 Início — Dashboard com cards e ações rápidas\n"
            "📊 Monitor — CPU, memória, swap, disco, processos\n"
            "⚡ Serviços — Gerenciar serviços systemd\n"
            "⚡ Energia — Suspender, hibernar, desligar, agendar\n"
            "🌐 Rede — Interfaces, IPs, gateway, DNS\n"
            "📡 Tráfego — Monitor de tráfego em tempo real\n"
            "🔌 Conexões — Todas as conexões TCP/UDP\n"
            "⚙️ Processos — Gerenciar processos do sistema\n"
            "🛡️ Firewall — Ativar/desativar UFW, regras\n"
            "👥 Usuários — Adicionar, remover, senhas\n"
            "💿 Discos — Partições e uso\n"
            "📦 Pacotes — APT: instalar, remover, upgrade")


# ═══════════════════════════════════════════════════════════════
#  MONITOR WIDGET (versão simplificada)
# ═══════════════════════════════════════════════════════════════
class SystemMonitorWidget(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        title = QLabel("📈 Monitor do Sistema")
        title.setFont(QFont("Segoe UI", 14, QFont.Bold))
        title.setStyleSheet("color: #F8FAFC;")
        layout.addWidget(title)

        # Cards
        grid = QGridLayout()
        grid.setSpacing(10)

        # CPU
        cpu_card = self._metric_card("🧠 CPU", "0%", "#22D3EE")
        self.cpu_percent_label = cpu_card['value']
        self.cpu_bar = cpu_card['bar']
        self.cpu_model = cpu_card['extra']
        grid.addWidget(cpu_card['frame'], 0, 0)

        # Memória
        mem_card = self._metric_card("💾 Memória", "0%", "#6A11CB")
        self.mem_percent_label = mem_card['value']
        self.mem_bar = mem_card['bar']
        self.mem_detail = mem_card['extra']
        grid.addWidget(mem_card['frame'], 0, 1)

        # Disco
        disk_card = self._metric_card("💿 Disco", "0%", "#10B981")
        self.disk_percent_label = disk_card['value']
        self.disk_bar = disk_card['bar']
        self.disk_detail = disk_card['extra']
        grid.addWidget(disk_card['frame'], 1, 0)

        # Uptime
        uptime_card = self._metric_card("⏱️ Uptime", "0s", "#F8FAFC")
        self.uptime_label = uptime_card['value']
        grid.addWidget(uptime_card['frame'], 1, 1)

        # Swap
        swap_card = self._metric_card("🔄 Swap", "0%", "#F59E0B")
        self.swap_percent_label = swap_card['value']
        self.swap_bar = swap_card['bar']
        self.swap_detail = swap_card['extra']
        grid.addWidget(swap_card['frame'], 0, 2)

        # Processos
        proc_card = self._metric_card("⚙️ Processos", "0", "#EC4899")
        self.proc_count_label = proc_card['value']
        grid.addWidget(proc_card['frame'], 1, 2)

        layout.addLayout(grid)

        # Tabela de processos
        self.proc_table = QTableWidget()
        self.proc_table.setColumnCount(4)
        self.proc_table.setHorizontalHeaderLabels(["PID", "Nome", "CPU%", "Mem%"])
        self.proc_table.setColumnWidth(0, 60)
        self.proc_table.setColumnWidth(1, 200)
        self.proc_table.setColumnWidth(2, 70)
        self.proc_table.setColumnWidth(3, 70)
        self.proc_table.verticalHeader().setVisible(False)
        self.proc_table.setMaximumHeight(250)
        self.proc_table.setStyleSheet("""
            QTableWidget { background-color: #0B0F19; color: #E2E8F0;
            border: 1px solid #1E293B; border-radius: 6px; font-size: 10px; }
            QHeaderView::section { background-color: #161E38; color: #22D3EE; font-size: 9px; }
        """)
        layout.addWidget(QLabel("🔝 Top Processos:"))
        layout.addWidget(self.proc_table)

        # Timer
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update_data)
        self._timer.start(2000)

    def _metric_card(self, icon_title, default, color):
        frame = QFrame()
        frame.setStyleSheet(f"""
            QFrame {{ background-color: rgba(15, 23, 42, 180);
            border: 1px solid #1E293B; border-radius: 10px; }}
        """)
        fl = QVBoxLayout(frame)
        fl.setContentsMargins(12, 10, 12, 10)
        fl.addWidget(QLabel(icon_title))
        value = QLabel(default)
        value.setFont(QFont("Segoe UI", 16, QFont.Bold))
        value.setStyleSheet(f"color: {color};")
        fl.addWidget(value)
        bar = QProgressBar()
        bar.setRange(0, 100)
        bar.setFixedHeight(8)
        bar.setVisible(False)
        bar.setStyleSheet(f"""
            QProgressBar {{ background-color: #1E293B; border: none; border-radius: 4px; }}
            QProgressBar::chunk {{ background-color: {color}; border-radius: 4px; }}
        """)
        fl.addWidget(bar)
        extra = QLabel("")
        extra.setStyleSheet("color: #64748B; font-size: 10px;")
        fl.addWidget(extra)
        return {'frame': frame, 'value': value, 'bar': bar, 'extra': extra}

    def _update_data(self):
        try:
            cpu = SystemUtils.get_cpu_info()
            cpu_percent = cpu.get('usage_percent', 0)
            self.cpu_percent_label.setText(f"{cpu_percent:.1f}%")
            self.cpu_bar.setVisible(True)
            self.cpu_bar.setValue(int(cpu_percent))
            self.cpu_model.setText(cpu.get('model', '')[:40])

            mem = SystemUtils.get_memory_info()
            mem_percent = mem.get('percent', 0)
            self.mem_percent_label.setText(f"{mem_percent:.1f}%")
            self.mem_bar.setVisible(True)
            self.mem_bar.setValue(int(mem_percent))
            used_str = SystemUtils.format_bytes(mem.get('used', 0))
            total_str = SystemUtils.format_bytes(mem.get('total', 0))
            self.mem_detail.setText(f"{used_str} / {total_str}")

            swap_percent = mem.get('swap_percent', 0)
            self.swap_percent_label.setText(f"{swap_percent:.1f}%")
            self.swap_bar.setVisible(True)
            self.swap_bar.setValue(int(swap_percent))
            swap_used = SystemUtils.format_bytes(mem.get('swap_used', 0))
            swap_total = SystemUtils.format_bytes(mem.get('swap_total', 0))
            self.swap_detail.setText(f"{swap_used} / {swap_total}")

            disks = SystemUtils.get_disk_info()
            if disks:
                root = next((d for d in disks if d['mountpoint'] == '/'), disks[0])
                dp = root.get('percent', 0)
                self.disk_percent_label.setText(f"{dp:.1f}%")
                self.disk_bar.setVisible(True)
                self.disk_bar.setValue(int(dp))
                used_str = SystemUtils.format_bytes(root.get('used', 0))
                total_str = SystemUtils.format_bytes(root.get('total', 0))
                self.disk_detail.setText(f"{used_str} / {total_str} ({root['device']})")

            self.uptime_label.setText(SystemUtils.get_uptime())
            self.proc_count_label.setText(str(SystemUtils.get_process_count()))

            # Top processos
            procs = []
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
                try:
                    p = proc.info
                    procs.append((p['pid'], p['name'], p['cpu_percent'] or 0, p['memory_percent'] or 0))
                except: pass
            procs.sort(key=lambda x: x[2], reverse=True)
            top = procs[:8]
            self.proc_table.setRowCount(len(top))
            for i, (pid, name, cpu_per, mem_per) in enumerate(top):
                self.proc_table.setItem(i, 0, QTableWidgetItem(str(pid)))
                self.proc_table.setItem(i, 1, QTableWidgetItem(name[:25]))
                self.proc_table.setItem(i, 2, QTableWidgetItem(f"{cpu_per:.1f}"))
                self.proc_table.setItem(i, 3, QTableWidgetItem(f"{mem_per:.1f}"))

        except Exception as e:
            print(f"Monitor update error: {e}")


# ═══════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if os.name == 'posix' and os.geteuid() != 0:
        print("❌ Erro: Painel precisa ser executado como ROOT (sudo).")
        print("   sudo python3 FydelisControl.py")
        sys.exit(1)

    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    font = QFont("Segoe UI", 9)
    font.setHintingPreference(QFont.PreferFullHinting)
    app.setFont(font)

    window = DebianControlPanel()
    window.show()

    sys.exit(app.exec_())