#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FydelisControl_Panel.py - Painel de Controle Personalizado para FydelisTechOS
Estilo: Moderno, Responsivo, Integrado ao Sistema
"""

import sys
import os
import subprocess
import re
import socket
import platform
import psutil
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
    QButtonGroup, QFormLayout, QSpinBox, QDateTimeEdit, QDateEdit
)
from PyQt5.QtCore import (
    Qt, QTimer, QSize, QThread, pyqtSignal, pyqtSlot, QObject,
    QDateTime, QDate, QTime, QUrl
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
        """Retorna informações detalhadas do SO."""
        info = {}
        try:
            # Kernel
            info['kernel'] = platform.uname().release
            info['hostname'] = socket.gethostname()
            info['arch'] = platform.machine()

            # Debian version
            with open('/etc/debian_version', 'r') as f:
                info['debian_version'] = f.read().strip()
        except:
            info['debian_version'] = platform.version()

        # OS name from /etc/os-release
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
        """Retorna uptime formatado."""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            seconds = int(uptime_seconds % 60)

            parts = []
            if days > 0:
                parts.append(f"{days}d")
            if hours > 0:
                parts.append(f"{hours}h")
            parts.append(f"{minutes}m")
            parts.append(f"{seconds}s")
            return " ".join(parts)
        except:
            return "N/A"

    @staticmethod
    def get_cpu_info():
        """Retorna informações detalhadas da CPU."""
        info = {}
        try:
            # Modelo
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if line.startswith('model name'):
                        info['model'] = line.split(':')[1].strip()
                        break

            # Contagem de cores
            info['cores'] = os.cpu_count()
            info['physical_cores'] = psutil.cpu_count(logical=False)

            # Frequência
            freq = psutil.cpu_freq()
            if freq:
                info['freq_current'] = f"{freq.current:.0f} MHz"
                info['freq_max'] = f"{freq.max:.0f} MHz"

            # Uso percentual
            info['usage_percent'] = psutil.cpu_percent(interval=0.5)

            # Load average
            try:
                with open('/proc/loadavg', 'r') as f:
                    parts = f.read().strip().split()
                    info['load_1'] = parts[0]
                    info['load_5'] = parts[1]
                    info['load_15'] = parts[2]
            except:
                pass

        except Exception as e:
            info['error'] = str(e)

        return info

    @staticmethod
    def get_memory_info():
        """Retorna informações detalhadas de memória."""
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()

        info = {
            'total': mem.total,
            'available': mem.available,
            'used': mem.used,
            'percent': mem.percent,
            'swap_total': swap.total,
            'swap_used': swap.used,
            'swap_percent': swap.percent
        }

        return info

    @staticmethod
    def get_disk_info():
        """Retorna informações de discos/partições."""
        disks = []
        for part in psutil.disk_partitions(all=False):
            if part.fstype and 'loop' not in part.device and 'snap' not in part.device:
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    disks.append({
                        'device': part.device,
                        'mountpoint': part.mountpoint,
                        'fstype': part.fstype,
                        'total': usage.total,
                        'used': usage.used,
                        'free': usage.free,
                        'percent': usage.percent
                    })
                except:
                    pass
        return disks

    @staticmethod
    def get_network_info():
        """Retorna informações de rede."""
        interfaces = []
        addrs = psutil.net_if_addrs()
        stats = psutil.net_if_stats()

        for name, addr_list in addrs.items():
            if name == 'lo':
                continue
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
    def get_services():
        """Retorna lista de serviços systemd."""
        services = []
        try:
            result = subprocess.run(
                "systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | head -200",
                shell=True, capture_output=True, text=True, timeout=10
            )
            for line in result.stdout.strip().split('\n'):
                if not line.strip():
                    continue
                parts = line.split()
                if len(parts) >= 4:
                    services.append({
                        'name': parts[0].replace('.service', ''),
                        'status': parts[2],
                        'description': ' '.join(parts[3:]) if len(parts) > 3 else '',
                        'load': parts[1] if len(parts) > 1 else '',
                        'active': parts[2] if len(parts) > 2 else ''
                    })
        except:
            pass
        return services

    @staticmethod
    def get_users():
        """Retorna lista de usuários do sistema."""
        users = []
        try:
            with open('/etc/passwd', 'r') as f:
                for line in f:
                    parts = line.strip().split(':')
                    if len(parts) >= 7:
                        uid = int(parts[2])
                        if uid >= 1000 or uid == 0:  # Usuários reais + root
                            users.append({
                                'name': parts[0],
                                'uid': uid,
                                'gid': int(parts[3]),
                                'home': parts[5],
                                'shell': parts[6],
                                'is_root': uid == 0
                            })
        except:
            pass
        return users

    @staticmethod
    def get_process_count():
        """Contagem de processos."""
        return len(psutil.pids())

    @staticmethod
    def get_package_count():
        """Contagem de pacotes instalados."""
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
        """Retorna uptime em segundos."""
        try:
            with open('/proc/uptime', 'r') as f:
                return float(f.read().split()[0])
        except:
            return 0

    @staticmethod
    def format_bytes(n):
        """Formata bytes para unidade legível."""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if n < 1024:
                return f"{n:.1f} {unit}"
            n /= 1024
        return f"{n:.1f} PB"


# ═══════════════════════════════════════════════════════════════
#  WIDGETS PERSONALIZADOS
# ═══════════════════════════════════════════════════════════════

class InfoCard(QFrame):
    """Card de informação com ícone, título, valor e barra de progresso opcional."""

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

        # Header: ícone + título
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

        # Valor principal
        self.value_label = QLabel(self._value)
        self.value_label.setFont(QFont("Segoe UI", 22, QFont.Bold))
        self.value_label.setStyleSheet(f"color: {self._color};")
        layout.addWidget(self.value_label)

        # Barra de progresso (se houver)
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


class SystemMonitorWidget(QWidget):
    """Widget com gráficos de monitoramento em tempo real."""

    update_signal = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._cpu_history = []
        self._mem_history = []
        self._max_history = 60
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._collect_data)
        self._timer.start(2000)

        self._setup_ui()

    def _setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        # Título
        title = QLabel("📈 Monitor do Sistema (tempo real)")
        title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        title.setStyleSheet("color: #F8FAFC;")
        layout.addWidget(title)

        # Grid de métricas
        grid = QGridLayout()
        grid.setSpacing(10)

        # CPU
        cpu_card = QFrame()
        cpu_card.setStyleSheet("""
            QFrame { background-color: rgba(15, 23, 42, 180);
            border: 1px solid #1E293B; border-radius: 10px; }
        """)
        cpu_layout = QVBoxLayout(cpu_card)
        cpu_layout.setContentsMargins(12, 10, 12, 10)
        cpu_layout.addWidget(QLabel("🧠 CPU"))
        self.cpu_percent_label = QLabel("0%")
        self.cpu_percent_label.setFont(QFont("Segoe UI", 18, QFont.Bold))
        self.cpu_percent_label.setStyleSheet("color: #22D3EE;")
        cpu_layout.addWidget(self.cpu_percent_label)
        self.cpu_bar = QProgressBar()
        self.cpu_bar.setRange(0, 100)
        self.cpu_bar.setFixedHeight(10)
        self.cpu_bar.setStyleSheet("""
            QProgressBar { background-color: #1E293B; border: none; border-radius: 5px; }
            QProgressBar::chunk { background-color: #22D3EE; border-radius: 5px; }
        """)
        cpu_layout.addWidget(self.cpu_bar)
        self.cpu_model_label = QLabel("")
        self.cpu_model_label.setStyleSheet("color: #64748B; font-size: 10px;")
        cpu_layout.addWidget(self.cpu_model_label)
        grid.addWidget(cpu_card, 0, 0)

        # Memória
        mem_card = QFrame()
        mem_card.setStyleSheet("""
            QFrame { background-color: rgba(15, 23, 42, 180);
            border: 1px solid #1E293B; border-radius: 10px; }
        """)
        mem_layout = QVBoxLayout(mem_card)
        mem_layout.setContentsMargins(12, 10, 12, 10)
        mem_layout.addWidget(QLabel("💾 Memória"))
        self.mem_percent_label = QLabel("0%")
        self.mem_percent_label.setFont(QFont("Segoe UI", 18, QFont.Bold))
        self.mem_percent_label.setStyleSheet("color: #6A11CB;")
        mem_layout.addWidget(self.mem_percent_label)
        self.mem_bar = QProgressBar()
        self.mem_bar.setRange(0, 100)
        self.mem_bar.setFixedHeight(10)
        self.mem_bar.setStyleSheet("""
            QProgressBar { background-color: #1E293B; border: none; border-radius: 5px; }
            QProgressBar::chunk { background-color: #6A11CB; border-radius: 5px; }
        """)
        mem_layout.addWidget(self.mem_bar)
        self.mem_detail_label = QLabel("")
        self.mem_detail_label.setStyleSheet("color: #64748B; font-size: 10px;")
        mem_layout.addWidget(self.mem_detail_label)
        grid.addWidget(mem_card, 0, 1)

        # Swap
        swap_card = QFrame()
        swap_card.setStyleSheet("""
            QFrame { background-color: rgba(15, 23, 42, 180);
            border: 1px solid #1E293B; border-radius: 10px; }
        """)
        swap_layout = QVBoxLayout(swap_card)
        swap_layout.setContentsMargins(12, 10, 12, 10)
        swap_layout.addWidget(QLabel("🔄 Swap"))
        self.swap_percent_label = QLabel("0%")
        self.swap_percent_label.setFont(QFont("Segoe UI", 18, QFont.Bold))
        self.swap_percent_label.setStyleSheet("color: #F59E0B;")
        swap_layout.addWidget(self.swap_percent_label)
        self.swap_bar = QProgressBar()
        self.swap_bar.setRange(0, 100)
        self.swap_bar.setFixedHeight(10)
        self.swap_bar.setStyleSheet("""
            QProgressBar { background-color: #1E293B; border: none; border-radius: 5px; }
            QProgressBar::chunk { background-color: #F59E0B; border-radius: 5px; }
        """)
        swap_layout.addWidget(self.swap_bar)
        self.swap_detail_label = QLabel("")
        self.swap_detail_label.setStyleSheet("color: #64748B; font-size: 10px;")
        swap_layout.addWidget(self.swap_detail_label)
        grid.addWidget(swap_card, 0, 2)

        # Disco
        disk_card = QFrame()
        disk_card.setStyleSheet("""
            QFrame { background-color: rgba(15, 23, 42, 180);
            border: 1px solid #1E293B; border-radius: 10px; }
        """)
        disk_layout = QVBoxLayout(disk_card)
        disk_layout.setContentsMargins(12, 10, 12, 10)
        disk_layout.addWidget(QLabel("💿 Disco"))
        self.disk_percent_label = QLabel("0%")
        self.disk_percent_label.setFont(QFont("Segoe UI", 18, QFont.Bold))
        self.disk_percent_label.setStyleSheet("color: #10B981;")
        disk_layout.addWidget(self.disk_percent_label)
        self.disk_bar = QProgressBar()
        self.disk_bar.setRange(0, 100)
        self.disk_bar.setFixedHeight(10)
        self.disk_bar.setStyleSheet("""
            QProgressBar { background-color: #1E293B; border: none; border-radius: 5px; }
            QProgressBar::chunk { background-color: #10B981; border-radius: 5px; }
        """)
        disk_layout.addWidget(self.disk_bar)
        self.disk_detail_label = QLabel("")
        self.disk_detail_label.setStyleSheet("color: #64748B; font-size: 10px;")
        disk_layout.addWidget(self.disk_detail_label)
        grid.addWidget(disk_card, 1, 0)

        # Uptime
        uptime_card = QFrame()
        uptime_card.setStyleSheet("""
            QFrame { background-color: rgba(15, 23, 42, 180);
            border: 1px solid #1E293B; border-radius: 10px; }
        """)
        uptime_layout = QVBoxLayout(uptime_card)
        uptime_layout.setContentsMargins(12, 10, 12, 10)
        uptime_layout.addWidget(QLabel("⏱️ Uptime"))
        self.uptime_label = QLabel("0s")
        self.uptime_label.setFont(QFont("Segoe UI", 18, QFont.Bold))
        self.uptime_label.setStyleSheet("color: #F8FAFC;")
        uptime_layout.addWidget(self.uptime_label)
        self.boot_time_label = QLabel("")
        self.boot_time_label.setStyleSheet("color: #64748B; font-size: 10px;")
        uptime_layout.addWidget(self.boot_time_label)
        grid.addWidget(uptime_card, 1, 1)

        # Processos / Pacotes
        proc_card = QFrame()
        proc_card.setStyleSheet("""
            QFrame { background-color: rgba(15, 23, 42, 180);
            border: 1px solid #1E293B; border-radius: 10px; }
        """)
        proc_layout = QVBoxLayout(proc_card)
        proc_layout.setContentsMargins(12, 10, 12, 10)
        proc_layout.addWidget(QLabel("📦 Pacotes"))
        self.pkg_label = QLabel("0")
        self.pkg_label.setFont(QFont("Segoe UI", 18, QFont.Bold))
        self.pkg_label.setStyleSheet("color: #F472B6;")
        proc_layout.addWidget(self.pkg_label)
        self.proc_label = QLabel("Processos: 0")
        self.proc_label.setStyleSheet("color: #64748B; font-size: 10px;")
        proc_layout.addWidget(self.proc_label)
        grid.addWidget(proc_card, 1, 2)

        layout.addLayout(grid)

        # Tabela de processos (top 8)
        self.process_table = QTableWidget()
        self.process_table.setColumnCount(4)
        self.process_table.setHorizontalHeaderLabels(["PID", "Nome", "CPU%", "Mem%"])
        self.process_table.setColumnWidth(0, 60)
        self.process_table.setColumnWidth(1, 200)
        self.process_table.setColumnWidth(2, 70)
        self.process_table.setColumnWidth(3, 70)
        self.process_table.verticalHeader().setVisible(False)
        self.process_table.setMaximumHeight(220)
        self.process_table.setStyleSheet("""
            QTableWidget { background-color: #0B0F19; color: #E2E8F0;
            border: 1px solid #1E293B; border-radius: 6px; font-size: 10px; }
            QHeaderView::section { background-color: #161E38; color: #22D3EE;
            border: 1px solid #1E293B; font-size: 9px; font-weight: bold; }
        """)
        layout.addWidget(QLabel("🔝 Processos Ativos:"))
        layout.addWidget(self.process_table)

    def _collect_data(self):
        """Coleta dados do sistema e atualiza a UI."""
        try:
            # CPU
            cpu = SystemUtils.get_cpu_info()
            cpu_percent = cpu.get('usage_percent', 0)
            self.cpu_percent_label.setText(f"{cpu_percent:.1f}%")
            self.cpu_bar.setValue(int(cpu_percent))
            self.cpu_model_label.setText(cpu.get('model', '')[:45])

            # Memória
            mem = SystemUtils.get_memory_info()
            mem_percent = mem.get('percent', 0)
            self.mem_percent_label.setText(f"{mem_percent:.1f}%")
            self.mem_bar.setValue(int(mem_percent))
            used_str = SystemUtils.format_bytes(mem.get('used', 0))
            total_str = SystemUtils.format_bytes(mem.get('total', 0))
            self.mem_detail_label.setText(f"{used_str} / {total_str}")

            # Swap
            swap_percent = mem.get('swap_percent', 0)
            self.swap_percent_label.setText(f"{swap_percent:.1f}%")
            self.swap_bar.setValue(int(swap_percent))
            swap_used_str = SystemUtils.format_bytes(mem.get('swap_used', 0))
            swap_total_str = SystemUtils.format_bytes(mem.get('swap_total', 0))
            self.swap_detail_label.setText(f"{swap_used_str} / {swap_total_str}")

            # Disco
            disks = SystemUtils.get_disk_info()
            if disks:
                root = next((d for d in disks if d['mountpoint'] == '/'), disks[0])
                disk_percent = root.get('percent', 0)
                self.disk_percent_label.setText(f"{disk_percent:.1f}%")
                self.disk_bar.setValue(int(disk_percent))
                used_str = SystemUtils.format_bytes(root.get('used', 0))
                total_str = SystemUtils.format_bytes(root.get('total', 0))
                self.disk_detail_label.setText(f"{used_str} / {total_str} ({root['device']})")
            else:
                self.disk_percent_label.setText("N/A")
                self.disk_bar.setValue(0)

            # Uptime
            uptime = SystemUtils.get_uptime()
            self.uptime_label.setText(uptime)
            boot_time = datetime.now() - timedelta(seconds=SystemUtils.get_uptime_seconds())
            self.boot_time_label.setText(f"Boot: {boot_time.strftime('%Y-%m-%d %H:%M')}")

            # Pacotes
            pkg_count = SystemUtils.get_package_count()
            self.pkg_label.setText(str(pkg_count))
            proc_count = SystemUtils.get_process_count()
            self.proc_label.setText(f"Processos: {proc_count}")

            # Tabela de processos (top 8 por CPU)
            self._update_process_table()

        except Exception as e:
            print(f"Monitor error: {e}")

    def _update_process_table(self):
        """Atualiza a tabela com os top processos."""
        try:
            processes = []
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
                try:
                    info = proc.info
                    processes.append((
                        info['pid'],
                        info['name'],
                        info['cpu_percent'] or 0,
                        info['memory_percent'] or 0
                    ))
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass

            processes.sort(key=lambda x: x[2], reverse=True)
            top = processes[:10]

            self.process_table.setRowCount(len(top))
            for i, (pid, name, cpu_per, mem_per) in enumerate(top):
                pid_item = QTableWidgetItem(str(pid))
                pid_item.setForeground(QColor(148, 163, 184))
                self.process_table.setItem(i, 0, pid_item)

                name_item = QTableWidgetItem(name[:30])
                name_item.setForeground(QColor(248, 250, 252))
                self.process_table.setItem(i, 1, name_item)

                cpu_item = QTableWidgetItem(f"{cpu_per:.1f}")
                cpu_item.setForeground(QColor(52, 211, 153))
                self.process_table.setItem(i, 2, cpu_item)

                mem_item = QTableWidgetItem(f"{mem_per:.1f}")
                mem_item.setForeground(QColor(147, 197, 253))
                self.process_table.setItem(i, 3, mem_item)
        except:
            pass


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

        self.setStyleSheet("""
            QMainWindow { background-color: #0F172A; }
            QMenuBar { background-color: #0F172A; color: #E2E8F0;
                border-bottom: 1px solid #1E293B; padding: 2px; }
            QMenuBar::item:selected { background-color: #6A11CB; }
            QMenu { background-color: #0F172A; color: #E2E8F0;
                border: 1px solid #1E293B; }
            QMenu::item:selected { background-color: #6A11CB; }
            QScrollBar:vertical { background-color: #0B0F19; width: 10px;
                border: none; border-radius: 5px; }
            QScrollBar::handle:vertical { background-color: #1E293B;
                border-radius: 5px; min-height: 30px; }
            QScrollBar::handle:vertical:hover { background-color: #6A11CB; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
        """)

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
        """)

        # Menu Sistema
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

        # Menu Ferramentas
        tools_menu = menubar.addMenu("🔧 Ferramentas")
        act_terminal = QAction("💻 Terminal", self)
        act_terminal.triggered.connect(lambda: self._run_command("x-terminal-emulator"))
        tools_menu.addAction(act_terminal)
        act_monitor = QAction("📊 Monitor de Sistema", self)
        act_monitor.triggered.connect(lambda: self._run_command("gnome-system-monitor"))
        tools_menu.addAction(act_monitor)
        tools_menu.addSeparator()
        act_update = QAction("🔄 Gerenciador de Pacotes", self)
        act_update.triggered.connect(lambda: self._run_command("apt upgrade"))
        tools_menu.addAction(act_update)

        # Menu Ajuda
        help_menu = menubar.addMenu("❓ Ajuda")
        act_docs = QAction("📖 Documentação", self)
        act_docs.triggered.connect(lambda: QMessageBox.information(self, "Documentação",
            "Painel de Controle Debian v1.0\n\n"
            "Este painel oferece monitoramento e gerenciamento do sistema.\n"
            "Funcionalidades:\n"
            "• Monitor de CPU, Memória, Disco e Rede\n"
            "• Gerenciamento de Serviços Systemd\n"
            "• Gerenciamento de Usuários\n"
            "• Informações do Sistema\n"
            "• Gerenciamento de Rede\n"
            "• Atualizações de Pacotes"))
        help_menu.addAction(act_docs)
        act_about_program = QAction("ℹ️ Sobre", self)
        act_about_program.triggered.connect(self._show_about)
        help_menu.addAction(act_about_program)

        # ── TOOLBAR ──
        toolbar = QToolBar()
        toolbar.setMovable(False)
        toolbar.setStyleSheet("""
            QToolBar {
                background-color: #0F172A; border-bottom: 1px solid #1E293B;
                padding: 4px 8px; spacing: 8px;
            }
            QPushButton {
                background-color: #1E293B; color: #22D3EE;
                border: 1px solid #334155; border-radius: 6px;
                padding: 6px 14px; font-size: 11px; font-weight: bold;
            }
            QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
        """)
        self.addToolBar(toolbar)

        # Barra de navegação (abas)
        self.nav_buttons = {}
        nav_items = [
            ("🏠", "Início", self._show_dashboard),
            ("📊", "Monitor", self._show_monitor),
            ("⚡", "Serviços", self._show_services),
            ("👥", "Usuários", self._show_users),
            ("🌐", "Rede", self._show_network),
            ("💿", "Discos", self._show_disks),
            ("📦", "Pacotes", self._show_packages),
        ]

        for icon, text, callback in nav_items:
            btn = QPushButton(f"{icon} {text}")
            btn.setCheckable(True)
            btn.setChecked(False)
            btn.clicked.connect(callback)
            toolbar.addWidget(btn)
            self.nav_buttons[text] = btn

        # Separador + Relógio
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

        # ── STACKED WIDGET (CONTEÚDO PRINCIPAL) ──
        self.stack = QStackedWidget()
        main_layout.addWidget(self.stack)

        # Páginas
        self._build_dashboard_page()
        self._build_monitor_page()
        self._build_services_page()
        self._build_users_page()
        self._build_network_page()
        self._build_disks_page()
        self._build_packages_page()

        # Mostra dashboard inicialmente
        self._show_dashboard()

        # ── STATUS BAR ──
        self.status_bar = QStatusBar()
        self.statusBar().setStyleSheet("""
            QStatusBar {
                background-color: #0F172A; color: #64748B;
                border-top: 1px solid #1E293B; font-size: 11px; padding: 2px 10px;
            }
        """)
        self.statusBar().showMessage("✅ Sistema pronto")

    def _update_clock(self):
        now = QDateTime.currentDateTime()
        self.clock_label.setText(now.toString("dddd, dd/MM/yyyy HH:mm:ss"))

    def _highlight_nav(self, active_text):
        for text, btn in self.nav_buttons.items():
            btn.setChecked(text == active_text)
            if text == active_text:
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
    #  PÁGINA: DASHBOARD (INÍCIO)
    # ══════════════════════════════════════════════════════════
    def _build_dashboard_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Header
        header = QHBoxLayout()
        icon = QLabel("🖥️")
        icon.setFont(QFont("Segoe UI", 36))
        header.addWidget(icon)

        title_block = QVBoxLayout()
        title = QLabel("Painel de Controle Debian")
        title.setFont(QFont("Segoe UI", 22, QFont.Bold))
        title.setStyleSheet("color: #F8FAFC;")
        title_block.addWidget(title)

        os_info = SystemUtils.get_os_info()
        subtitle = QLabel(f"{os_info.get('os_name', 'Debian')} • Kernel {os_info.get('kernel', '')} • {os_info.get('arch', '')}")
        subtitle.setStyleSheet("color: #64748B; font-size: 12px;")
        title_block.addWidget(subtitle)
        header.addLayout(title_block, 1)
        layout.addLayout(header)

        # Cards principais
        cards_grid = QGridLayout()
        cards_grid.setSpacing(12)

        # CPU Card
        self.cpu_card = InfoCard("CPU", "0%", "🧠", 0, "#22D3EE")
        cards_grid.addWidget(self.cpu_card, 0, 0)

        # Memória Card
        self.mem_card = InfoCard("Memória", "0%", "💾", 0, "#6A11CB")
        cards_grid.addWidget(self.mem_card, 0, 1)

        # Disco Card
        self.disk_card = InfoCard("Disco (/)", "0%", "💿", 0, "#10B981")
        cards_grid.addWidget(self.disk_card, 0, 2)

        # Uptime Card
        self.uptime_card = InfoCard("Uptime", "0s", "⏱️", None, "#F8FAFC")
        cards_grid.addWidget(self.uptime_card, 0, 3)

        # Pacotes Card
        self.pkg_card = InfoCard("Pacotes Instalados", "0", "📦", None, "#F472B6")
        cards_grid.addWidget(self.pkg_card, 1, 0)

        # Processos Card
        self.proc_card = InfoCard("Processos Ativos", "0", "⚙️", None, "#F59E0B")
        cards_grid.addWidget(self.proc_card, 1, 1)

        # Serviços Card
        self.svc_card = InfoCard("Serviços Systemd", "0", "⚡", None, "#3B82F6")
        cards_grid.addWidget(self.svc_card, 1, 2)

        # Rede Card
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
            ("🔄 Reiniciar Sistema", lambda: self._system_action("reboot")),
            ("⏻ Desligar", lambda: self._system_action("shutdown")),
        ]

        for i, (text, callback) in enumerate(btns):
            btn = QPushButton(text)
            btn.clicked.connect(callback)
            actions_layout.addWidget(btn, i // 4, i % 4)

        layout.addWidget(actions_group)
        layout.addStretch()

        # Área de scroll
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        scroll.setWidget(page)

        # Adiciona ao stack
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
        """Atualiza todos os cards do dashboard."""
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

            self.uptime_card.update_value(SystemUtils.get_uptime())
            self.pkg_card.update_value(str(SystemUtils.get_package_count()))
            self.proc_card.update_value(str(SystemUtils.get_process_count()))

            services = SystemUtils.get_services()
            self.svc_card.update_value(str(len(services)))

            interfaces = SystemUtils.get_network_info()
            self.net_card.update_value(str(len(interfaces)))

        except Exception as e:
            print(f"Dashboard update error: {e}")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: MONITOR
    # ══════════════════════════════════════════════════════════
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
        self.statusBar().showMessage("📊 Monitor do Sistema — atualizando a cada 2s")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: SERVIÇOS
    # ══════════════════════════════════════════════════════════
    def _build_services_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        # Header
        header = QHBoxLayout()
        header.addWidget(QLabel("⚡ Gerenciamento de Serviços"))
        header.addStretch()

        btn_refresh = QPushButton("🔄 Recarregar")
        btn_refresh.clicked.connect(self._refresh_services)
        btn_refresh.setStyleSheet("""
            QPushButton { background-color: #2563EB; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold; }
            QPushButton:hover { background-color: #3B82F6; }
        """)
        header.addWidget(btn_refresh)

        self.service_filter = QLineEdit()
        self.service_filter.setPlaceholderText("🔍 Filtrar serviços...")
        self.service_filter.setFixedWidth(250)
        self.service_filter.setStyleSheet("""
            QLineEdit { background-color: #0B0F19; color: #F8FAFC;
            border: 1px solid #1E293B; border-radius: 6px; padding: 6px 12px; }
        """)
        self.service_filter.textChanged.connect(self._filter_services)
        header.addWidget(self.service_filter)

        layout.addLayout(header)

        # Tabela de serviços
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
            QTableWidget::item { padding: 4px; }
            QTableWidget::item:selected { background-color: #6A11CB; color: #FFFFFF; }
            QHeaderView::section { background-color: #161E38; color: #22D3EE;
            border: 1px solid #1E293B; font-size: 10px; font-weight: bold; }
        """)
        layout.addWidget(self.services_table)

        # Ações de serviço
        actions = QHBoxLayout()
        actions.setSpacing(10)

        btn_start = QPushButton("▶️ Iniciar")
        btn_start.clicked.connect(lambda: self._service_action("start"))
        btn_start.setStyleSheet(self._service_btn_style("#10B981"))
        actions.addWidget(btn_start)

        btn_stop = QPushButton("⏹️ Parar")
        btn_stop.clicked.connect(lambda: self._service_action("stop"))
        btn_stop.setStyleSheet(self._service_btn_style("#EF4444"))
        actions.addWidget(btn_stop)

        btn_restart = QPushButton("🔄 Reiniciar")
        btn_restart.clicked.connect(lambda: self._service_action("restart"))
        btn_restart.setStyleSheet(self._service_btn_style("#F59E0B"))
        actions.addWidget(btn_restart)

        btn_enable = QPushButton("✅ Habilitar")
        btn_enable.clicked.connect(lambda: self._service_action("enable"))
        btn_enable.setStyleSheet(self._service_btn_style("#22D3EE"))
        actions.addWidget(btn_enable)

        btn_disable = QPushButton("❌ Desabilitar")
        btn_disable.clicked.connect(lambda: self._service_action("disable"))
        btn_disable.setStyleSheet(self._service_btn_style("#64748B"))
        actions.addWidget(btn_disable)

        btn_status = QPushButton("📋 Status")
        btn_status.clicked.connect(lambda: self._service_action("status"))
        btn_status.setStyleSheet(self._service_btn_style("#6A11CB"))
        actions.addWidget(btn_status)

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

        # Carrega serviços
        self._all_services = []
        self._refresh_services()

    def _service_btn_style(self, color):
        return f"""
            QPushButton {{ background-color: {color}; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 16px; font-size: 11px; font-weight: bold; }}
            QPushButton:hover {{ opacity: 0.8; }}
        """

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
            # Ícone de status
            status_icon = "✅" if svc['status'] == 'active' else \
                          "❌" if svc['status'] == 'inactive' else \
                          "⚠️" if svc['status'] == 'failed' else "⬜"
            status_item = QTableWidgetItem(status_icon)
            status_item.setTextAlignment(Qt.AlignCenter)
            if svc['status'] == 'active':
                status_item.setForeground(QColor(52, 211, 153))
            elif svc['status'] == 'failed':
                status_item.setForeground(QColor(239, 68, 68))
            else:
                status_item.setForeground(QColor(148, 163, 184))
            self.services_table.setItem(i, 0, status_item)

            name_item = QTableWidgetItem(svc['name'])
            name_item.setForeground(QColor(248, 250, 252))
            self.services_table.setItem(i, 1, name_item)

            status_str = svc.get('active', svc['status'])
            status_item2 = QTableWidgetItem(status_str)
            if status_str == 'active':
                status_item2.setForeground(QColor(52, 211, 153))
            elif status_str in ('failed', 'error'):
                status_item2.setForeground(QColor(239, 68, 68))
            else:
                status_item2.setForeground(QColor(148, 163, 184))
            self.services_table.setItem(i, 2, status_item2)

            load_item = QTableWidgetItem(svc.get('load', ''))
            load_item.setForeground(QColor(147, 197, 253))
            self.services_table.setItem(i, 3, load_item)

            desc_item = QTableWidgetItem(svc.get('description', ''))
            desc_item.setForeground(QColor(100, 116, 139))
            self.services_table.setItem(i, 4, desc_item)

    def _get_selected_service(self):
        rows = set()
        for idx in self.services_table.selectedIndexes():
            rows.add(idx.row())
        if not rows:
            QMessageBox.information(self, "Nada Selecionado", "Selecione um serviço na tabela.")
            return None
        row = list(rows)[0]
        return self.services_table.item(row, 1).text()

    def _service_action(self, action):
        service = self._get_selected_service()
        if not service:
            return

        cmd_map = {
            'start': f"systemctl start {service}",
            'stop': f"systemctl stop {service}",
            'restart': f"systemctl restart {service}",
            'enable': f"systemctl enable {service}",
            'disable': f"systemctl disable {service}",
            'status': f"systemctl status {service} --no-pager -n 30"
        }

        cmd = cmd_map.get(action)
        if not cmd:
            return

        self.status_bar.showMessage(f"⚡ Executando: {cmd[:60]}...")

        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            output = result.stdout if result.returncode == 0 else result.stderr

            # Se for status, mostra num diálogo
            if action == 'status':
                dialog = QDialog(self)
                dialog.setWindowTitle(f"📋 Status: {service}")
                dialog.setMinimumSize(700, 450)
                dialog.setStyleSheet("background-color: #0F172A;")
                layout = QVBoxLayout(dialog)
                text = QTextEdit()
                text.setReadOnly(True)
                text.setPlainText(output)
                text.setStyleSheet("""
                    QTextEdit { background-color: #0B0F19; color: #E2E8F0;
                    border: 1px solid #1E293B; border-radius: 6px;
                    font-family: 'Consolas', monospace; font-size: 11px; }
                """)
                layout.addWidget(text)
                btn = QPushButton("✕ Fechar")
                btn.clicked.connect(dialog.accept)
                btn.setStyleSheet("""
                    QPushButton { background-color: #1E293B; color: #22D3EE;
                    border: 1px solid #334155; border-radius: 6px;
                    padding: 8px 20px; font-weight: bold; }
                    QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
                """)
                layout.addWidget(btn, alignment=Qt.AlignRight)
                dialog.exec_()
            else:
                QMessageBox.information(self, f"{'✅' if result.returncode == 0 else '❌'} {action}",
                                        f"Serviço: {service}\n\n{output[:500]}")

            self._refresh_services()
            self.status_bar.showMessage(f"✅ {action} concluído em {service}")
        except Exception as e:
            QMessageBox.critical(self, "Erro", f"Falha ao {action} {service}:\n{str(e)}")

    def _show_services(self):
        self._highlight_nav("Serviços")
        self.stack.setCurrentWidget(self._services_page)
        self._refresh_services()
        self.status_bar.showMessage("⚡ Gerenciamento de Serviços Systemd")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: USUÁRIOS
    # ══════════════════════════════════════════════════════════
    def _build_users_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        header.addWidget(QLabel("👥 Gerenciamento de Usuários"))
        header.addStretch()

        btn_refresh = QPushButton("🔄 Recarregar")
        btn_refresh.clicked.connect(self._refresh_users)
        btn_refresh.setStyleSheet("""
            QPushButton { background-color: #2563EB; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold; }
            QPushButton:hover { background-color: #3B82F6; }
        """)
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
        self.users_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.users_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.users_table.setStyleSheet(self._table_style())
        layout.addWidget(self.users_table)

        # Ações
        actions = QHBoxLayout()
        btn_add = QPushButton("➕ Adicionar Usuário")
        btn_add.clicked.connect(self._add_user)
        btn_add.setStyleSheet(self._action_btn_style("#10B981"))
        actions.addWidget(btn_add)

        btn_del = QPushButton("🗑️ Remover Usuário")
        btn_del.clicked.connect(self._remove_user)
        btn_del.setStyleSheet(self._action_btn_style("#EF4444"))
        actions.addWidget(btn_del)

        btn_passwd = QPushButton("🔑 Alterar Senha")
        btn_passwd.clicked.connect(self._change_password)
        btn_passwd.setStyleSheet(self._action_btn_style("#F59E0B"))
        actions.addWidget(btn_passwd)

        actions.addStretch()
        layout.addLayout(actions)

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
            icon_item = QTableWidgetItem(icon)
            icon_item.setTextAlignment(Qt.AlignCenter)
            icon_item.setForeground(QColor(251, 191, 36) if user['is_root'] else QColor(148, 163, 184))
            self.users_table.setItem(i, 0, icon_item)

            name_item = QTableWidgetItem(user['name'])
            name_item.setForeground(QColor(248, 250, 252))
            self.users_table.setItem(i, 1, name_item)

            uid_item = QTableWidgetItem(str(user['uid']))
            uid_item.setForeground(QColor(147, 197, 253))
            self.users_table.setItem(i, 2, uid_item)

            gid_item = QTableWidgetItem(str(user['gid']))
            gid_item.setForeground(QColor(147, 197, 253))
            self.users_table.setItem(i, 3, gid_item)

            home_item = QTableWidgetItem(user['home'])
            home_item.setForeground(QColor(196, 181, 253))
            self.users_table.setItem(i, 4, home_item)

            shell_item = QTableWidgetItem(user['shell'])
            shell_item.setForeground(QColor(148, 163, 184))
            self.users_table.setItem(i, 5, shell_item)

    def _add_user(self):
        name, ok = QInputDialog.getText(self, "➕ Adicionar Usuário", "Nome do usuário:")
        if ok and name.strip():
            self._run_system_command(f"useradd -m -s /bin/bash {name.strip()}",
                                     f"Usuário {name.strip()} criado")

    def _remove_user(self):
        rows = set()
        for idx in self.users_table.selectedIndexes():
            rows.add(idx.row())
        if not rows:
            QMessageBox.information(self, "Nada Selecionado", "Selecione um usuário.")
            return
        row = list(rows)[0]
        username = self.users_table.item(row, 1).text()

        resposta = QMessageBox.question(self, "🗑️ Remover Usuário",
                                        f"Remover usuário '{username}' e sua home?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            self._run_system_command(f"userdel -r {username}",
                                     f"Usuário {username} removido")

    def _change_password(self):
        rows = set()
        for idx in self.users_table.selectedIndexes():
            rows.add(idx.row())
        if not rows:
            QMessageBox.information(self, "Nada Selecionado", "Selecione um usuário.")
            return
        row = list(rows)[0]
        username = self.users_table.item(row, 1).text()

        pwd, ok = QInputDialog.getText(self, "🔑 Alterar Senha",
                                       f"Nova senha para {username}:",
                                       QLineEdit.Password)
        if ok and pwd.strip():
            try:
                proc = subprocess.run(f"echo '{username}:{pwd}' | chpasswd",
                                      shell=True, capture_output=True, text=True, timeout=10)
                if proc.returncode == 0:
                    QMessageBox.information(self, "✅ Sucesso", f"Senha de {username} alterada.")
                else:
                    QMessageBox.critical(self, "❌ Erro", f"Falha: {proc.stderr}")
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))

    def _show_users(self):
        self._highlight_nav("Usuários")
        self.stack.setCurrentWidget(self._users_page)
        self._refresh_users()
        self.status_bar.showMessage("👥 Gerenciamento de Usuários")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: REDE
    # ══════════════════════════════════════════════════════════
    def _build_network_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        header.addWidget(QLabel("🌐 Configuração de Rede"))
        header.addStretch()

        btn_refresh = QPushButton("🔄 Recarregar")
        btn_refresh.clicked.connect(self._refresh_network)
        btn_refresh.setStyleSheet("""
            QPushButton { background-color: #2563EB; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold; }
            QPushButton:hover { background-color: #3B82F6; }
        """)
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

        # Informações adicionais
        info_group = QGroupBox("📡 Informações de Rede")
        info_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px;
                margin-top: 12px; padding: 16px; }
            QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left;
                padding: 2px 8px; color: #94A3B8; }
            QLabel { color: #E2E8F0; font-size: 11px; }
        """)
        info_layout = QFormLayout(info_group)

        # Hostname
        self.hostname_label = QLabel(socket.gethostname())
        info_layout.addRow("Hostname:", self.hostname_label)

        # Domínio (tenta resolver)
        try:
            domain = socket.getfqdn()
        except:
            domain = "N/A"
        self.domain_label = QLabel(domain)
        info_layout.addRow("FQDN:", self.domain_label)

        # Gateway padrão
        self.gateway_label = QLabel("...")
        info_layout.addRow("Gateway:", self.gateway_label)

        # DNS
        self.dns_label = QLabel("...")
        info_layout.addRow("DNS:", self.dns_label)

        layout.addWidget(info_group)
        layout.addStretch()

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
            name_item = QTableWidgetItem(iface['name'])
            name_item.setForeground(QColor(248, 250, 252))
            name_item.setFont(QFont("Segoe UI", 10, QFont.Bold))
            self.network_table.setItem(i, 0, name_item)

            ip_item = QTableWidgetItem(iface.get('ipv4', '—'))
            ip_item.setForeground(QColor(52, 211, 153))
            self.network_table.setItem(i, 1, ip_item)

            mask_item = QTableWidgetItem(iface.get('netmask', '—'))
            mask_item.setForeground(QColor(148, 163, 184))
            self.network_table.setItem(i, 2, mask_item)

            ip6_item = QTableWidgetItem(iface.get('ipv6', '—'))
            ip6_item.setForeground(QColor(147, 197, 253))
            self.network_table.setItem(i, 3, ip6_item)

            speed = iface.get('speed', 0)
            speed_str = f"{speed} Mbps" if speed else "—"
            speed_item = QTableWidgetItem(speed_str)
            speed_item.setForeground(QColor(196, 181, 253))
            self.network_table.setItem(i, 4, speed_item)

            status = "🟢 Ativa" if iface.get('isup') else "🔴 Inativa"
            status_item = QTableWidgetItem(status)
            status_item.setForeground(QColor(52, 211, 153) if iface.get('isup') else QColor(239, 68, 68))
            self.network_table.setItem(i, 5, status_item)

        # Informações extras
        try:
            # Gateway
            result = subprocess.run("ip route | grep default | awk '{print $3}' | head -1",
                                    shell=True, capture_output=True, text=True, timeout=5)
            self.gateway_label.setText(result.stdout.strip() or "N/A")

            # DNS
            result = subprocess.run("cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\\n' ' '",
                                    shell=True, capture_output=True, text=True, timeout=5)
            self.dns_label.setText(result.stdout.strip() or "N/A")
        except:
            self.gateway_label.setText("N/A")
            self.dns_label.setText("N/A")

    def _show_network(self):
        self._highlight_nav("Rede")
        self.stack.setCurrentWidget(self._network_page)
        self._refresh_network()
        self.status_bar.showMessage("🌐 Informações de Rede")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: DISCOS
    # ══════════════════════════════════════════════════════════
    def _build_disks_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        header.addWidget(QLabel("💿 Gerenciamento de Discos"))
        header.addStretch()

        btn_refresh = QPushButton("🔄 Recarregar")
        btn_refresh.clicked.connect(self._refresh_disks)
        btn_refresh.setStyleSheet("""
            QPushButton { background-color: #2563EB; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 20px; font-weight: bold; }
            QPushButton:hover { background-color: #3B82F6; }
        """)
        header.addWidget(btn_refresh)
        layout.addLayout(header)

        self.disks_table = QTableWidget()
        self.disks_table.setColumnCount(6)
        self.disks_table.setHorizontalHeaderLabels(["Dispositivo", "Ponto Montagem", "Tipo", "Usado", "Total", "Uso%"])
        self.disks_table.setColumnWidth(0, 150)
        self.disks_table.setColumnWidth(1, 180)
        self.disks_table.setColumnWidth(2, 80)
        self.disks_table.setColumnWidth(3, 100)
        self.disks_table.setColumnWidth(4, 100)
        self.disks_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.Stretch)
        self.disks_table.verticalHeader().setVisible(False)
        self.disks_table.setStyleSheet(self._table_style())
        layout.addWidget(self.disks_table)

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
            dev_item = QTableWidgetItem(disk['device'])
            dev_item.setForeground(QColor(248, 250, 252))
            self.disks_table.setItem(i, 0, dev_item)

            mount_item = QTableWidgetItem(disk['mountpoint'])
            mount_item.setForeground(QColor(147, 197, 253))
            self.disks_table.setItem(i, 1, mount_item)

            fs_item = QTableWidgetItem(disk['fstype'])
            fs_item.setForeground(QColor(196, 181, 253))
            self.disks_table.setItem(i, 2, fs_item)

            used_item = QTableWidgetItem(SystemUtils.format_bytes(disk['used']))
            used_item.setForeground(QColor(251, 191, 36))
            self.disks_table.setItem(i, 3, used_item)

            total_item = QTableWidgetItem(SystemUtils.format_bytes(disk['total']))
            total_item.setForeground(QColor(52, 211, 153))
            self.disks_table.setItem(i, 4, total_item)

            percent = disk['percent']
            percent_item = QTableWidgetItem(f"{percent:.1f}%")
            if percent > 90:
                percent_item.setForeground(QColor(239, 68, 68))
            elif percent > 70:
                percent_item.setForeground(QColor(251, 191, 36))
            else:
                percent_item.setForeground(QColor(52, 211, 153))
            self.disks_table.setItem(i, 5, percent_item)

    def _show_disks(self):
        self._highlight_nav("Discos")
        self.stack.setCurrentWidget(self._disks_page)
        self._refresh_disks()
        self.status_bar.showMessage("💿 Informações de Discos")

    # ══════════════════════════════════════════════════════════
    #  PÁGINA: PACOTES
    # ══════════════════════════════════════════════════════════
    def _build_packages_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        header.addWidget(QLabel("📦 Gerenciamento de Pacotes"))
        header.addStretch()

        btn_update = QPushButton("🔄 Atualizar Repositórios")
        btn_update.clicked.connect(self._update_repos)
        btn_update.setStyleSheet("""
            QPushButton { background-color: #2563EB; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 16px; font-weight: bold; }
            QPushButton:hover { background-color: #3B82F6; }
        """)
        header.addWidget(btn_update)

        btn_upgrade = QPushButton("⬆️ Atualizar Sistema")
        btn_upgrade.clicked.connect(self._system_upgrade)
        btn_upgrade.setStyleSheet("""
            QPushButton { background-color: #6A11CB; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 16px; font-weight: bold; }
            QPushButton:hover { background-color: #8B5CF6; }
        """)
        header.addWidget(btn_upgrade)

        btn_clean = QPushButton("🧹 Limpar Cache")
        btn_clean.clicked.connect(self._clean_cache)
        btn_clean.setStyleSheet("""
            QPushButton { background-color: #0D9488; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 16px; font-weight: bold; }
            QPushButton:hover { background-color: #14B8A6; }
        """)
        header.addWidget(btn_clean)

        layout.addLayout(header)

        # Info de pacotes
        info_group = QGroupBox("📊 Status dos Repositórios")
        info_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px;
                margin-top: 12px; padding: 16px; }
            QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left;
                padding: 2px 8px; color: #94A3B8; }
        """)
        info_layout = QFormLayout(info_group)

        self.pkg_info_label = QLabel("N/A")
        info_layout.addRow("Pacotes instalados:", self.pkg_info_label)

        self.pkg_upgradable_label = QLabel("N/A")
        info_layout.addRow("Atualizáveis:", self.pkg_upgradable_label)

        self.pkg_cache_label = QLabel("N/A")
        info_layout.addRow("Tamanho do cache APT:", self.pkg_cache_label)

        layout.addWidget(info_group)

        # Ações
        actions_group = QGroupBox("⚡ Ações")
        actions_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px;
                margin-top: 12px; padding: 16px; }
            QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left;
                padding: 2px 8px; color: #94A3B8; }
            QPushButton { background-color: #1E293B; color: #F8FAFC;
                border: 1px solid #334155; border-radius: 8px;
                padding: 10px 20px; font-size: 12px; font-weight: bold; }
            QPushButton:hover { background-color: #6A11CB; color: #FFFFFF; }
        """)
        actions_layout = QGridLayout(actions_group)

        pkg_btns = [
            ("📥 Instalar Pacote", self._install_package),
            ("🗑️ Remover Pacote", self._remove_package),
            ("🔍 Buscar Pacote", self._search_package),
            ("📋 Detalhes do Pacote", self._package_details),
            ("🧹 Autoremove", self._autoremove),
            ("📦 dpkg --configure -a", self._configure_dpkg),
        ]

        for i, (text, callback) in enumerate(pkg_btns):
            btn = QPushButton(text)
            btn.clicked.connect(callback)
            actions_layout.addWidget(btn, i // 3, i % 3)

        layout.addWidget(actions_group)

        # Log de saída
        output_group = QGroupBox("📄 Log de Saída")
        output_group.setStyleSheet("""
            QGroupBox { color: #F8FAFC; font-size: 12px; font-weight: bold;
                border: 1px solid #1E293B; border-radius: 10px;
                margin-top: 12px; padding: 16px; }
            QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left;
                padding: 2px 8px; color: #94A3B8; }
        """)
        output_layout = QVBoxLayout(output_group)
        self.pkg_output = QTextEdit()
        self.pkg_output.setReadOnly(True)
        self.pkg_output.setStyleSheet("""
            QTextEdit { background-color: #0B0F19; color: #E2E8F0;
            border: 1px solid #1E293B; border-radius: 6px;
            font-family: 'Consolas', monospace; font-size: 11px; padding: 8px; }
        """)
        self.pkg_output.setMaximumHeight(200)
        output_layout.addWidget(self.pkg_output)
        layout.addWidget(output_group)

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
            pkg_count = SystemUtils.get_package_count()
            self.pkg_info_label.setText(str(pkg_count))

            result = subprocess.run("apt list --upgradable 2>/dev/null | grep -c upgradable || true",
                                    shell=True, capture_output=True, text=True, timeout=10)
            count = result.stdout.strip()
            self.pkg_upgradable_label.setText(f"{count} pacote(s)")

            result = subprocess.run("du -sh /var/cache/apt/archives/ 2>/dev/null | cut -f1",
                                    shell=True, capture_output=True, text=True, timeout=10)
            self.pkg_cache_label.setText(result.stdout.strip() or "N/A")
        except:
            self.pkg_info_label.setText("N/A")
            self.pkg_upgradable_label.setText("N/A")
            self.pkg_cache_label.setText("N/A")

    def _install_package(self):
        pkg, ok = QInputDialog.getText(self, "📥 Instalar Pacote",
                                       "Nome do pacote para instalar:")
        if ok and pkg.strip():
            self._run_pkg_command(f"apt install -y {pkg.strip()}",
                                  f"Instalando {pkg.strip()}...")

    def _remove_package(self):
        pkg, ok = QInputDialog.getText(self, "🗑️ Remover Pacote",
                                       "Nome do pacote para remover:")
        if ok and pkg.strip():
            self._run_pkg_command(f"apt remove -y {pkg.strip()}",
                                  f"Removendo {pkg.strip()}...")

    def _search_package(self):
        term, ok = QInputDialog.getText(self, "🔍 Buscar Pacote",
                                        "Termo de busca:")
        if ok and term.strip():
            self._run_pkg_command(f"apt search {term.strip()} 2>/dev/null | head -50",
                                  f"Buscando '{term.strip()}'...")

    def _package_details(self):
        pkg, ok = QInputDialog.getText(self, "📋 Detalhes do Pacote",
                                       "Nome do pacote:")
        if ok and pkg.strip():
            self._run_pkg_command(f"apt show {pkg.strip()} 2>/dev/null || dpkg -s {pkg.strip()} 2>/dev/null",
                                  f"Detalhes de {pkg.strip()}...")

    def _update_repos(self):
        self._run_pkg_command("apt update 2>&1", "Atualizando repositórios...")

    def _system_upgrade(self):
        resposta = QMessageBox.question(self, "⬆️ Upgrade do Sistema",
                                        "Deseja realizar o upgrade completo do sistema?\n\n"
                                        "Isso instalará todas as atualizações disponíveis.",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            self._run_pkg_command("apt full-upgrade -y 2>&1",
                                  "Realizando upgrade completo...")

    def _autoremove(self):
        resposta = QMessageBox.question(self, "🧹 Autoremove",
                                        "Remover pacotes órfãos não mais necessários?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if resposta == QMessageBox.Yes:
            self._run_pkg_command("apt autoremove -y 2>&1",
                                  "Removendo pacotes órfãos...")

    def _clean_cache(self):
        self._run_pkg_command("apt clean 2>&1", "Limpando cache APT...")

    def _configure_dpkg(self):
        self._run_pkg_command("dpkg --configure -a 2>&1",
                              "Reconfigurando pacotes pendentes...")

    def _run_pkg_command(self, cmd, title):
        self.pkg_output.append(f"\n{'='*60}")
        self.pkg_output.append(f"⏳ {title}")
        self.pkg_output.append(f"$ {cmd}")
        self.status_bar.showMessage(f"⏳ {title}")
        QApplication.processEvents()

        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
            output = result.stdout if result.returncode == 0 else result.stderr
            self.pkg_output.append(output[:5000])

            if result.returncode == 0:
                self.pkg_output.append(f"\n✅ Comando concluído com sucesso (código {result.returncode})")
                self.status_bar.showMessage(f"✅ {title} concluído")
            else:
                self.pkg_output.append(f"\n❌ Comando falhou (código {result.returncode})")
                self.status_bar.showMessage(f"❌ {title} falhou")

            self._update_package_info()
        except subprocess.TimeoutExpired:
            self.pkg_output.append("\n⏱️ Comando excedeu o tempo limite.")
        except Exception as e:
            self.pkg_output.append(f"\n❌ Erro: {str(e)}")

    def _show_packages(self):
        self._highlight_nav("Pacotes")
        self.stack.setCurrentWidget(self._packages_page)
        self._update_package_info()
        self.status_bar.showMessage("📦 Gerenciamento de Pacotes")

    # ══════════════════════════════════════════════════════════
    #  UTILITÁRIOS
    # ══════════════════════════════════════════════════════════

    def _table_style(self):
        return """
            QTableWidget { background-color: #0B0F19; color: #E2E8F0;
            border: 1px solid #1E293B; border-radius: 8px; font-size: 11px; }
            QTableWidget::item { padding: 4px 6px; }
            QTableWidget::item:selected { background-color: #6A11CB; color: #FFFFFF; }
            QHeaderView::section { background-color: #161E38; color: #22D3EE;
            border: 1px solid #1E293B; font-size: 10px; font-weight: bold; }
        """

    def _action_btn_style(self, color):
        return f"""
            QPushButton {{ background-color: {color}; color: #FFFFFF;
            border: none; border-radius: 6px; padding: 8px 16px;
            font-size: 11px; font-weight: bold; }}
            QPushButton:hover {{ opacity: 0.8; }}
        """

    def _run_command(self, cmd):
        """Executa um comando shell em terminal externo."""
        try:
            subprocess.Popen(cmd, shell=True)
            self.status_bar.showMessage(f"💻 Executando: {cmd}")
        except Exception as e:
            QMessageBox.critical(self, "Erro", f"Não foi possível executar:\n{str(e)}")

    def _system_action(self, action):
        """Ações de sistema (shutdown/reboot)."""
        action_map = {
            'shutdown': ("Desligar", "shutdown -h now"),
            'reboot': ("Reiniciar", "shutdown -r now")
        }
        name, cmd = action_map.get(action, ("", ""))

        resposta = QMessageBox.question(
            self, f"⚠️ {name} Sistema",
            f"Tem certeza que deseja {name.lower()} o sistema agora?\n\n"
            "Todos os aplicativos serão fechados.",
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if resposta == QMessageBox.Yes:
            try:
                subprocess.run(cmd, shell=True, timeout=5)
            except:
                pass

    def _run_system_command(self, cmd, success_msg):
        """Executa comando e exibe resultado."""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                QMessageBox.information(self, "✅ Sucesso", success_msg)
                self._refresh_users()
            else:
                QMessageBox.critical(self, "❌ Erro", result.stderr[:500])
        except Exception as e:
            QMessageBox.critical(self, "Erro", str(e))

    def _load_initial_data(self):
        """Carrega dados iniciais do dashboard."""
        self._update_dashboard_data()

    def _show_about(self):
        os_info = SystemUtils.get_os_info()
        QMessageBox.about(self, "ℹ️ Sobre o Painel de Controle",
                          f"""
            <h2>🖥️ Painel de Controle FydelisTechOS</h2>
            <p>Versão 1.0</p>
            <p>Painel personalizado em Python/PyQt5 para gerenciamento completo do sistema FydelisTechOS.</p>
            <hr>
            <p><b>Sistema:</b> {os_info.get('os_name', 'N/A')}</p>
            <p><b>Kernel:</b> {os_info.get('kernel', 'N/A')}</p>
            <p><b>Arquitetura:</b> {os_info.get('arch', 'N/A')}</p>
            <p><b>Hostname:</b> {os_info.get('hostname', 'N/A')}</p>
            <hr>
            <p>Funcionalidades:</p>
            <ul>
                <li>Monitor de CPU, Memória, Disco e Rede</li>
                <li>Gerenciamento de Serviços Systemd</li>
                <li>Gerenciamento de Usuários</li>
                <li>Configuração de Rede</li>
                <li>Gerenciamento de Discos</li>
                <li>Gerenciamento de Pacotes APT</li>
                <li>Modo escuro com design responsivo</li>
            </ul>
            <p><i>Desenvolvido para FydelisTechOS</i></p>
        """)


# ═══════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════
if __name__ == '__main__':
    # Verifica root (Linux)
    if os.name == 'posix' and os.geteuid() != 0:
        print("❌ Erro: O painel de controle precisa ser executado como ROOT (sudo).")
        print("   sudo python3 FydelisControl.py")
        sys.exit(1)

    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    # Fonte global
    font = QFont("Segoe UI", 9)
    font.setHintingPreference(QFont.PreferFullHinting)
    app.setFont(font)

    window = DebianControlPanel()
    window.show()

    sys.exit(app.exec_())