"""
FydelisLab - Progressive Security Training v2.1
GUI Python + SQLite + Certificates as Images
CORRIGIDO: Salva progresso ao fechar o aplicativo
"""

import tkinter as tk
from tkinter import ttk, font as tkfont, messagebox
import sqlite3
import webbrowser
import urllib.parse
import os
import json
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageTk
    PILLOW_AVAILABLE = True
except ImportError:
    PILLOW_AVAILABLE = False

# ============================================================
# CONFIGURAÇÕES
# ============================================================

# Usa caminho ABSOLUTO para evitar problemas de diretório
BASE_DIR = Path(__file__).parent.resolve()
DB_PATH = str(BASE_DIR / "bancos" / "fydelislab.db")
CERT_DIR = BASE_DIR / "certificados"


def ensure_dirs():
    """Cria as pastas necessárias se não existirem."""
    (BASE_DIR / "bancos").mkdir(parents=True, exist_ok=True)
    (BASE_DIR / "certificados").mkdir(parents=True, exist_ok=True)
    (BASE_DIR / "backgrounds").mkdir(parents=True, exist_ok=True)
    (BASE_DIR / "scripts").mkdir(parents=True, exist_ok=True)
    (BASE_DIR / "docs").mkdir(parents=True, exist_ok=True)


# ============================================================
# DATABASE SETUP
# ============================================================

def init_database():
    """Cria as tabelas no banco SQLite com seed inicial."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS player (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            xp INTEGER DEFAULT 0,
            current_level INTEGER DEFAULT 1,
            current_exercise_index INTEGER DEFAULT 0,
            exercises_done_in_level INTEGER DEFAULT 0,
            basic_completed INTEGER DEFAULT 0,
            intermediate_completed INTEGER DEFAULT 0,
            advanced_completed INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level INTEGER NOT NULL,
            order_num INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            correct_command TEXT NOT NULL,
            hint TEXT DEFAULT ''
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS certificates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id INTEGER NOT NULL,
            level TEXT NOT NULL,
            image_path TEXT DEFAULT '',
            issued_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (player_id) REFERENCES player(id)
        )
    """)

    cursor.execute("SELECT COUNT(*) FROM exercises")
    if cursor.fetchone()[0] == 0:
        exercises = [
            (1, 1, "Permissões de Arquivo",
             "O arquivo secrets.txt está bloqueado. Use o comando para liberar acesso total.",
             "chmod 777 secrets.txt",
             "Tente: chmod 777 secrets.txt"),
            (1, 2, "Navegação em Diretórios",
             "Você precisa encontrar a pasta oculta. Use o comando para listar diretórios ocultos.",
             "ls -la",
             "Tente: ls -la para ver arquivos ocultos"),
            (1, 3, "Leitura de Arquivo",
             "Leia o conteúdo do arquivo flag.txt usando o comando correto.",
             "cat flag.txt",
             "Tente: cat flag.txt"),
            (2, 1, "Varredura de Rede",
             "Identifique hosts ativos na rede. Use o comando de varredura.",
             "nmap -sn 192.168.1.0/24",
             "Tente: nmap -sn 192.168.1.0/24"),
            (2, 2, "Descobrindo Portas",
             "Descubra quais portas estão abertas no servidor alvo.",
             "nmap -p 1-1000 192.168.1.10",
             "Tente: nmap -p 1-1000 192.168.1.10"),
            (2, 3, "Força Bruta SSH",
             "Tente acessar o servidor SSH com o usuário admin.",
             "hydra -l admin -P passwords.txt ssh://192.168.1.10",
             "Tente: hydra -l admin -P passwords.txt ssh://192.168.1.10"),
            (3, 1, "Injeção SQL",
             "A página de login é vulnerável. Injete o payload para bypass.",
             "' OR 1=1 --",
             "Tente: ' OR 1=1 --"),
            (3, 2, "Escalação de Privilégio",
             "Você tem acesso de usuário. Escalone para root.",
             "sudo su",
             "Tente: sudo su"),
            (3, 3, "Captura da Bandeira Final",
             "Execute o exploit final para capturar a flag do sistema.",
             "exploit --target=auth --flag",
             "Tente: exploit --target=auth --flag"),
        ]
        cursor.executemany("""
            INSERT INTO exercises (level, order_num, title, description, correct_command, hint)
            VALUES (?, ?, ?, ?, ?, ?)
        """, exercises)

    conn.commit()
    conn.close()


def get_db():
    """Retorna uma conexão com o banco."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# ============================================================
# CERTIFICATE IMAGE GENERATOR
# ============================================================

def generate_certificate_image(player_name, level, use_custom_bg=None):
    if not PILLOW_AVAILABLE:
        messagebox.showwarning(
            "Pillow não instalado",
            "Instale Pillow para gerar imagens dos certificados:\n"
            "pip install Pillow\n\n"
            "Por enquanto, o certificado será exibido apenas em texto."
        )
        return None

    CERT_DIR.mkdir(exist_ok=True)

    level_colors = {
        "básico": "#3fb950",
        "intermediário": "#58a6ff",
        "avançado": "#f0883e",
    }
    level_display = {
        "básico": "BÁSICO",
        "intermediário": "INTERMEDIÁRIO",
        "avançado": "AVANÇADO",
    }

    lcolor = level_colors.get(level.lower(), "#58a6ff")
    ldisplay = level_display.get(level.lower(), level.upper())

    W, H = 800, 560

    if use_custom_bg and os.path.exists(use_custom_bg):
        bg_img = Image.open(use_custom_bg).convert("RGB")
        bg_img = bg_img.resize((W, H), Image.LANCZOS)
        img = bg_img
        draw = ImageDraw.Draw(img)
    else:
        img = Image.new("RGB", (W, H), "#0d1117")
        draw = ImageDraw.Draw(img)
        for i in range(6):
            draw.rectangle(
                [i, i, W - 1 - i, H - 1 - i],
                outline=lcolor if i < 3 else "#30363d",
                width=1
            )
        draw.rectangle([20, 20, W - 21, H - 21], fill="#161b22", outline="#30363d", width=1)
        draw.rectangle([40, 50, W - 40, 56], fill=lcolor)

    try:
        font_paths = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "C:\\Windows\\Fonts\\arialbd.ttf",
            "C:\\Windows\\Fonts\\arial.ttf",
        ]
        font_title = None
        font_name = None
        font_text = None
        font_small = None

        for fp in font_paths:
            if os.path.exists(fp):
                if "Bold" in fp or "bd" in fp:
                    if font_title is None:
                        font_title = ImageFont.truetype(fp, 32)
                    if font_name is None:
                        font_name = ImageFont.truetype(fp, 24)
                else:
                    if font_text is None:
                        font_text = ImageFont.truetype(fp, 16)
                    if font_small is None:
                        font_small = ImageFont.truetype(fp, 12)
                if all([font_title, font_name, font_text, font_small]):
                    break

        if font_title is None:
            font_title = ImageFont.load_default()
        if font_name is None:
            font_name = ImageFont.load_default()
        if font_text is None:
            font_text = ImageFont.load_default()
        if font_small is None:
            font_small = ImageFont.load_default()
    except Exception:
        font_title = ImageFont.load_default()
        font_name = ImageFont.load_default()
        font_text = ImageFont.load_default()
        font_small = ImageFont.load_default()

    y = 70

    shield_text = "🛡️"
    try:
        bbox = draw.textbbox((0, 0), shield_text, font=font_title)
        sw = bbox[2] - bbox[0]
        draw.text(((W - sw) / 2, y), shield_text, fill=lcolor, font=font_title)
    except:
        pass
    y += 50

    title = "CERTIFICADO DE CONCLUSÃO"
    try:
        bbox = draw.textbbox((0, 0), title, font=font_title)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2, y), title, fill=lcolor, font=font_title)
    except:
        draw.text((W//2 - 100, y), title, fill=lcolor, font=font_title)
    y += 45

    draw.rectangle([200, y, W - 200, y + 2], fill="#30363d")
    y += 20

    text1 = "Este certificado é concedido a"
    try:
        bbox = draw.textbbox((0, 0), text1, font=font_text)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2, y), text1, fill="#c9d1d9", font=font_text)
    except:
        draw.text((W//2 - 80, y), text1, fill="#c9d1d9", font=font_text)
    y += 28

    try:
        bbox = draw.textbbox((0, 0), player_name, font=font_name)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2, y), player_name, fill="#58a6ff", font=font_name)
    except:
        draw.text((W//2 - 60, y), player_name, fill="#58a6ff", font=font_name)
    y += 38

    draw.rectangle([200, y, W - 200, y + 2], fill="#30363d")
    y += 18

    text2 = f"Por completar com êxito o treinamento do nível {ldisplay} no FydelisLab"
    try:
        bbox = draw.textbbox((0, 0), text2, font=font_text)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2, y), text2, fill="#c9d1d9", font=font_text)
    except:
        draw.text((W//2 - 140, y), text2, fill="#c9d1d9", font=font_text)
    y += 28

    text3 = "Reconhecimento por habilidades em Ethical Hacking e Cybersecurity Defense."
    try:
        bbox = draw.textbbox((0, 0), text3, font=font_text)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2, y), text3, fill="#f0883e", font=font_text)
    except:
        draw.text((W//2 - 150, y), text3, fill="#f0883e", font=font_text)
    y += 40

    badge_text = f"★ NÍVEL {ldisplay} ★"
    try:
        bbox = draw.textbbox((0, 0), badge_text, font=font_title)
        tw = bbox[2] - bbox[0]
        badge_pad = 20
        draw.rectangle(
            [(W - tw) / 2 - badge_pad, y - 5,
             (W + tw) / 2 + badge_pad, y + 35],
            fill=lcolor, outline=lcolor, width=1
        )
        draw.text(((W - tw) / 2, y), badge_text, fill="#0d1117", font=font_title)
    except:
        draw.text((W//2 - 60, y), badge_text, fill=lcolor, font=font_title)
    y += 55

    date_str = f"Emitido em: {datetime.now().strftime('%d/%m/%Y %H:%M')}"
    try:
        bbox = draw.textbbox((0, 0), date_str, font=font_small)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2, y), date_str, fill="#8b949e", font=font_small)
    except:
        draw.text((W//2 - 80, y), date_str, fill="#8b949e", font=font_small)
    y += 30

    draw.rectangle([40, y, W - 40, y + 6], fill=lcolor)

    filename = f"certificado_{player_name}_{level}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
    filename = "".join(c if c.isalnum() or c in "._- " else "_" for c in filename)
    filepath = CERT_DIR / filename
    img.save(filepath, "PNG")

    return str(filepath)


# ============================================================
# COLOR THEME
# ============================================================

COLORS = {
    "bg": "#0d1117",
    "bg2": "#161b22",
    "bg3": "#21262d",
    "border": "#30363d",
    "text": "#c9d1d9",
    "accent": "#58a6ff",
    "success": "#3fb950",
    "warning": "#f0883e",
    "error": "#f85149",
    "prompt": "#3fb950",
    "title": "#58a6ff",
    "card_bg": "#010409",
}

FONTS = {}


def setup_fonts():
    FONTS["mono"] = tkfont.Font(family="Courier New", size=11)
    FONTS["mono_small"] = tkfont.Font(family="Courier New", size=9)
    FONTS["mono_big"] = tkfont.Font(family="Courier New", size=14, weight="bold")
    FONTS["title"] = tkfont.Font(family="Courier New", size=16, weight="bold")
    FONTS["cert_title"] = tkfont.Font(family="Courier New", size=22, weight="bold")
    FONTS["cert_name"] = tkfont.Font(family="Courier New", size=16)
    FONTS["cert_text"] = tkfont.Font(family="Courier New", size=12)
    FONTS["heading"] = tkfont.Font(family="Courier New", size=13, weight="bold")


# ============================================================
# SHARE UTILITIES
# ============================================================

def share_linkedin_text(player_name, level):
    text = (
        f"🛡️ Acabei de concluir o nível {level.upper()} "
        f"no FydelisLab - FydelisTech OS!\n"
        f"Treinamento prático de cibersegurança com desafios reais. "
        f"Evoluindo para me tornar um expert em Ethical Hacking!\n\n"
        f"#CyberSecurity #EthicalHacking #FydelisTech #Pentest #FydelisLab"
    )
    share_url = f"https://www.linkedin.com/feed/?shareActive=true&text={urllib.parse.quote(text)}"
    webbrowser.open(share_url)


def share_twitter_text(player_name, level):
    text = (
        f"🛡️ Acabei de concluir o nível {level.upper()} no FydelisLab! "
        f"Treinamento prático de cibersegurança. "
        f"#CyberSecurity #EthicalHacking #Pentest #FydelisLab"
    )
    share_url = f"https://twitter.com/intent/tweet?text={urllib.parse.quote(text)}"
    webbrowser.open(share_url)


def share_whatsapp_text(player_name, level):
    text = (
        f"🛡️ Acabei de concluir o nível {level.upper()} no FydelisLab - "
        f"treinamento prático de cibersegurança! 🚀"
    )
    share_url = f"https://wa.me/?text={urllib.parse.quote(text)}"
    webbrowser.open(share_url)


# ============================================================
# CERTIFICATE DISPLAY WINDOW
# ============================================================

def show_certificate(parent, player_name, level, custom_bg_path=None,
                     on_close_callback=None):
    """Display certificate with generated image and share with image attachment."""
    img_path = generate_certificate_image(player_name, level, custom_bg_path)

    win = tk.Toplevel(parent)
    win.title(f"Certificado - Nível {level.capitalize()}")
    win.configure(bg=COLORS["bg"])
    win.resizable(False, False)
    win.transient(parent)
    win.grab_set()

    level_colors = {
        "básico": "#3fb950",
        "intermediário": "#58a6ff",
        "avançado": "#f0883e",
    }
    lcolor = level_colors.get(level.lower(), "#58a6ff")

    main = tk.Frame(win, bg=COLORS["bg"], padx=20, pady=20)
    main.pack()

    # Preview da imagem
    if img_path and PILLOW_AVAILABLE:
        try:
            pil_img = Image.open(img_path)
            pw, ph = pil_img.size
            max_w, max_h = 600, 420
            scale = min(max_w / pw, max_h / ph, 1.0)
            new_w, new_h = int(pw * scale), int(ph * scale)
            pil_img = pil_img.resize((new_w, new_h), Image.LANCZOS)
            tk_img = ImageTk.PhotoImage(pil_img)

            img_label = tk.Label(main, image=tk_img, bg=COLORS["bg"])
            img_label.image = tk_img
            img_label.pack(pady=(0, 10))
        except Exception:
            _show_text_certificate(main, player_name, level, lcolor)
    else:
        _show_text_certificate(main, player_name, level, lcolor)

    # Funções auxiliares dos botões
    def _save_certificate(path):
        messagebox.showinfo(
            "Certificado Salvo",
            f"✅ Imagem salva em:\n{path}\n\n"
            f"Você pode anexá-la manualmente ao post."
        )

    def _open_folder():
        folder = str(CERT_DIR.resolve())
        if os.name == 'nt':
            os.startfile(folder)
        elif os.name == 'posix':
            webbrowser.open(f"file://{folder}")
            
    def _copy_image_to_clipboard(path):
        try:
            import subprocess
            import platform
            system = platform.system()
            abs_path = str(Path(path).resolve())

            if system == "Windows":
                ps_cmd = (
                    f'Add-Type -AssemblyName System.Windows.Forms; '
                    f'$img = [System.Drawing.Image]::FromFile("{abs_path}"); '
                    f'[System.Windows.Forms.Clipboard]::SetImage($img); '
                    f'$img.Dispose()'
                )
                subprocess.run(["powershell", "-Command", ps_cmd], capture_output=True)
                return True
            elif system == "Linux":
                try:
                    subprocess.run(["xclip", "-selection", "clipboard", "-t", "image/png", "-i", abs_path], check=True)
                    return True
                except (subprocess.CalledProcessError, FileNotFoundError):
                    return False
            elif system == "Darwin":
                script = f'set theImage to (readPOSIX file "{abs_path}" as JPEG picture)\nset the clipboard to theImage'
                subprocess.run(["osascript", "-e", script], capture_output=True)
                return True
        except Exception:
            return False
        return False

    def _share_and_attach(platform_name, share_func):
        share_func()
        if img_path:
            copiado = _copy_image_to_clipboard(img_path)
            _open_folder()
            if copiado:
                msg = f"✅ Link do {platform_name} aberto!\n\n📋 A imagem do certificado foi COPIADA para a área de transferência (Ctrl+V)."
            else:
                msg = f"✅ Link do {platform_name} aberto!\n\n📁 A pasta de certificados foi aberta para você arrastar a imagem."
            messagebox.showinfo(f"Compartilhar no {platform_name}", msg)

    # Botões (renderizados apenas uma vez)
    btn_frame = tk.Frame(main, bg=COLORS["bg"])
    btn_frame.pack(fill="x", pady=(5, 0))

    if img_path:
        btn_save = tk.Button(btn_frame, text="💾 Salvar Imagem", font=FONTS["mono_small"],
                             bg=COLORS["success"], fg=COLORS["bg"], bd=0, padx=12, pady=5, cursor="hand2",
                             command=lambda: _save_certificate(img_path))
        btn_save.pack(side="left", padx=3)

        btn_open = tk.Button(btn_frame, text="📂 Abrir Pasta", font=FONTS["mono_small"],
                             bg=COLORS["accent"], fg=COLORS["bg"], bd=0, padx=12, pady=5, cursor="hand2",
                             command=_open_folder)
        btn_open.pack(side="left", padx=3)

    tk.Label(btn_frame, text="Compartilhar:", font=FONTS["mono_small"], bg=COLORS["bg"],
             fg=COLORS["text"]).pack(side="left", padx=(10, 5))

    btn_linkedin = tk.Button(btn_frame, text="LinkedIn", bg="#0a66c2", fg="white", font=FONTS["mono_small"],
                             cursor="hand2", bd=0, padx=12, pady=5,
                             command=lambda: _share_and_attach("LinkedIn", lambda: share_linkedin_text(player_name, level)))
    btn_linkedin.pack(side="left", padx=3)

    btn_twitter = tk.Button(btn_frame, text="Twitter", bg="#1da1f2", fg="white", font=FONTS["mono_small"],
                            cursor="hand2", bd=0, padx=12, pady=5,
                            command=lambda: _share_and_attach("Twitter", lambda: share_twitter_text(player_name, level)))
    btn_twitter.pack(side="left", padx=3)

    btn_whatsapp = tk.Button(btn_frame, text="WhatsApp", bg="#25d366", fg="white", font=FONTS["mono_small"],
                             cursor="hand2", bd=0, padx=12, pady=5,
                             command=lambda: _share_and_attach("WhatsApp", lambda: share_whatsapp_text(player_name, level)))
    btn_whatsapp.pack(side="left", padx=3)

    def on_closing():
        win.grab_release()
        win.destroy()
        if on_close_callback:
            on_close_callback()

    win.protocol("WM_DELETE_WINDOW", on_closing)
    win.geometry(f"+{parent.winfo_rootx() + 60}+{parent.winfo_rooty() + 40}")

    def _notify_share(img_path):
        if img_path:
            messagebox.showinfo(
                "Compartilhar Certificado",
                f"📸 A imagem do certificado foi salva em:\n{img_path}\n\n"
                f"📌 Para compartilhar com a imagem:\n"
                f"1. Publique o texto no LinkedIn/Twitter\n"
                f"2. Anexe a imagem manualmente ao post\n\n"
                f"A imagem está na pasta 'certificados/'"
            )
    # ========================================================

    # Botões
    btn_frame = tk.Frame(main, bg=COLORS["bg"])
    btn_frame.pack(fill="x", pady=(5, 0))

    if img_path:
        btn_save = tk.Button(btn_frame,
                             text="💾 Salvar Imagem",
                             font=FONTS["mono_small"],
                             bg=COLORS["success"], fg=COLORS["bg"],
                             bd=0, padx=12, pady=5, cursor="hand2",
                             command=lambda: _save_certificate(img_path))
        btn_save.pack(side="left", padx=3)

        btn_open = tk.Button(btn_frame,
                             text="📂 Abrir Pasta",
                             font=FONTS["mono_small"],
                             bg=COLORS["accent"], fg=COLORS["bg"],
                             bd=0, padx=12, pady=5, cursor="hand2",
                             command=_open_folder)
        btn_open.pack(side="left", padx=3)

    tk.Label(btn_frame, text="Compartilhar:",
             font=FONTS["mono_small"], bg=COLORS["bg"],
             fg=COLORS["text"]).pack(side="left", padx=(10, 5))

    for name, color, callback in [
        ("LinkedIn", "#0a66c2",
         lambda: [share_linkedin_text(player_name, level),
                  _notify_share(img_path)]),
        ("Twitter", "#1da1f2",
         lambda: [share_twitter_text(player_name, level),
                  _notify_share(img_path)]),
        ("WhatsApp", "#25d366",
         lambda: [share_whatsapp_text(player_name, level),
                  _notify_share(img_path)]),
    ]:
        btn = tk.Button(btn_frame, text=name,
                        bg=color, fg="white",
                        font=FONTS["mono_small"],
                        cursor="hand2", bd=0, padx=12, pady=5,
                        command=callback)
        btn.pack(side="left", padx=3)

    def on_closing():
        win.grab_release()
        win.destroy()
        if on_close_callback:
            on_close_callback()

    win.protocol("WM_DELETE_WINDOW", on_closing)
    win.geometry(f"+{parent.winfo_rootx() + 60}+{parent.winfo_rooty() + 40}")

    def _save_certificate(path):
        messagebox.showinfo(
            "Certificado Salvo",
            f"✅ Imagem salva em:\n{path}\n\n"
            f"Você pode anexá-la manualmente ao post no LinkedIn/Twitter."
        )

    def _open_folder():
        folder = str(CERT_DIR.resolve())
        if os.name == 'nt':
            os.startfile(folder)
        elif os.name == 'posix':
            webbrowser.open(f"file://{folder}")

    def _notify_share(img_path):
        if img_path:
            messagebox.showinfo(
                "Compartilhar Certificado",
                f"📸 A imagem do certificado foi salva em:\n{img_path}\n\n"
                f"📌 Para compartilhar com a imagem:\n"
                f"1. Publique o texto no LinkedIn/Twitter\n"
                f"2. Anexe a imagem manualmente ao post\n\n"
                f"A imagem está na pasta 'certificados/'"
            )

    def on_closing():
        win.grab_release()
        win.destroy()
        if on_close_callback:
            on_close_callback()

    win.protocol("WM_DELETE_WINDOW", on_closing)
    win.geometry(f"+{parent.winfo_rootx() + 60}+{parent.winfo_rooty() + 40}")


def _show_text_certificate(parent, player_name, level, lcolor):
    level_colors = {
        "básico": "#3fb950",
        "intermediário": "#58a6ff",
        "avançado": "#f0883e",
    }
    lc = level_colors.get(level.lower(), "#58a6ff")

    outer = tk.Frame(parent, bg=COLORS["border"], padx=2, pady=2)
    outer.pack(pady=(0, 10))

    inner = tk.Frame(outer, bg=COLORS["bg2"], padx=30, pady=25)
    inner.pack()

    tk.Frame(inner, bg=lc, height=3).pack(fill="x", pady=(0, 15))
    tk.Label(inner, text="🛡️", font=("Courier New", 36),
             bg=COLORS["bg2"], fg=lc).pack()
    tk.Label(inner, text="CERTIFICADO DE CONCLUSÃO",
             font=FONTS["cert_title"], bg=COLORS["bg2"],
             fg=lc).pack(pady=(5, 5))
    tk.Frame(inner, bg=COLORS["border"], height=1).pack(fill="x", pady=5)
    tk.Label(inner, text="Este certificado é concedido a",
             font=FONTS["cert_text"], bg=COLORS["bg2"],
             fg=COLORS["text"]).pack(pady=(5, 2))
    tk.Label(inner, text=player_name,
             font=FONTS["cert_name"], bg=COLORS["bg2"],
             fg=COLORS["accent"]).pack(pady=(2, 5))
    tk.Frame(inner, bg=COLORS["border"], height=1).pack(fill="x", pady=5)
    tk.Label(inner,
             text=f"Por completar com êxito o treinamento\ndo nível {level.upper()} no FydelisLab",
             font=FONTS["cert_text"], bg=COLORS["bg2"],
             fg=COLORS["text"], justify="center").pack(pady=5)
    tk.Label(inner,
             text="Reconhecimento por habilidades em Ethical Hacking\ne Cybersecurity Defense.",
             font=FONTS["mono_small"], bg=COLORS["bg2"],
             fg=COLORS["warning"], justify="center").pack(pady=(0, 10))
    tk.Label(inner,
             text=f"Emitido em: {datetime.now().strftime('%d/%m/%Y %H:%M')}",
             font=FONTS["mono_small"], bg=COLORS["bg2"],
             fg=COLORS["text"]).pack(pady=(0, 10))
    tk.Frame(inner, bg=lc, height=3).pack(fill="x", pady=(5, 0))


# ============================================================
# MAIN APPLICATION
# ============================================================

class FydelisLabApp:
    def __init__(self, root, custom_cert_bg=None):
        self.root = root
        self.root.title("FydelisTechOS - FydelisTechOS")
        self.root.configure(bg=COLORS["bg"])
        self.root.minsize(720, 580)

        self.custom_cert_bg = custom_cert_bg

        ensure_dirs()
        setup_fonts()

        # Player state
        self.player_id = None
        self.player_name = ""
        self.player_xp = 0
        self.current_level = 1
        self.current_ex_index = 0
        self.exercises_done_in_level = 0
        self.total_exercises_in_level = 0
        self.level_exercises = []

        # Database
        init_database()

        # FIX: Salva progresso quando o usuário fecha a janela
        self.root.protocol("WM_DELETE_WINDOW", self.on_app_closing)

        # Show login
        self.show_login()

    # ========== NOVO: Salvar ao fechar ==========
    def on_app_closing(self):
        """Salva o progresso e fecha o aplicativo."""
        if hasattr(self, 'player_id') and self.player_id is not None:
            self.save_full_progress()
            print(f"[✓] Progresso salvo: {self.player_name} | "
                  f"Nível {self.current_level} | "
                  f"Exercício {self.current_ex_index}/{self.total_exercises_in_level} | "
                  f"XP: {self.player_xp}")
        self.root.destroy()
    # ============================================

    def clear_screen(self):
        for widget in self.root.winfo_children():
            widget.destroy()

    # ---------- LOGIN ----------

    def show_login(self):
        self.clear_screen()

        main = tk.Frame(self.root, bg=COLORS["bg"])
        main.place(relx=0.5, rely=0.5, anchor="center")

        tk.Label(main, text="🛡️ FydelisLab",
                 font=tkfont.Font(family="Courier New", size=28, weight="bold"),
                 bg=COLORS["bg"], fg=COLORS["accent"]).pack(pady=(0, 5))

        tk.Label(main, text="FydelisTech OS - Interface de Treinamento",
                 font=FONTS["mono"], bg=COLORS["bg"],
                 fg=COLORS["success"]).pack(pady=(0, 25))

        card = tk.Frame(main, bg=COLORS["bg2"],
                        bd=1, relief="solid",
                        highlightbackground=COLORS["border"],
                        highlightcolor=COLORS["border"],
                        highlightthickness=1, padx=30, pady=25)
        card.pack()

        tk.Label(card, text="Identificação do Operador",
                 font=FONTS["heading"], bg=COLORS["bg2"],
                 fg=COLORS["title"]).pack(pady=(0, 15))

        tk.Label(card, text="Nome do usuário:",
                 font=FONTS["mono"], bg=COLORS["bg2"],
                 fg=COLORS["text"]).pack(anchor="w")

        entry_name = tk.Entry(card, font=FONTS["mono"],
                              bg=COLORS["card_bg"], fg=COLORS["text"],
                              bd=1, relief="solid",
                              highlightbackground=COLORS["border"],
                              highlightthickness=1,
                              insertbackground=COLORS["accent"])
        entry_name.pack(fill="x", pady=(5, 15), ipady=4)
        entry_name.focus_set()

        if self.custom_cert_bg:
            tk.Label(card,
                     text=f"✓ Imagem de fundo personalizada carregada",
                     font=FONTS["mono_small"], bg=COLORS["bg2"],
                     fg=COLORS["success"]).pack(pady=(0, 5))

        def do_login(event=None):
            name = entry_name.get().strip()
            if not name:
                messagebox.showwarning("Atenção", "Informe seu nome para continuar.")
                return
            self.player_name = name
            self.find_or_create_player()
            self.show_lab()

        btn = tk.Button(card, text="🔓 INICIAR LABORATÓRIO",
                        font=FONTS["mono"], bg=COLORS["success"],
                        fg=COLORS["bg"], bd=0, padx=20, pady=8,
                        cursor="hand2", command=do_login)
        btn.pack(pady=5)

        entry_name.bind("<Return>", do_login)

    def find_or_create_player(self):
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM player WHERE name = ?", (self.player_name,))
        player = cursor.fetchone()
        if player:
            self.player_id = player["id"]
            self.player_xp = player["xp"]
            self.current_level = player["current_level"]
            self.current_ex_index = player["current_exercise_index"]
            self.exercises_done_in_level = player["exercises_done_in_level"]
            # DEBUG: mostra o que foi carregado
            print(f"[✓] Jogador '{self.player_name}' carregado do banco:")
            print(f"    Nível: {self.current_level}, "
                  f"Exercício: {self.current_ex_index}, "
                  f"XP: {self.player_xp}")
        else:
            cursor.execute("""
                INSERT INTO player (name, xp, current_level, current_exercise_index,
                                    exercises_done_in_level)
                VALUES (?, 0, 1, 0, 0)
            """, (self.player_name,))
            conn.commit()
            self.player_id = cursor.lastrowid
            self.player_xp = 0
            self.current_level = 1
            self.current_ex_index = 0
            self.exercises_done_in_level = 0
            print(f"[✓] Novo jogador '{self.player_name}' criado no banco.")
        conn.close()

    def save_full_progress(self):
        """Salva TODAS as variáveis de progresso no banco SQLite."""
        try:
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE player SET
                    xp = ?,
                    current_level = ?,
                    current_exercise_index = ?,
                    exercises_done_in_level = ?
                WHERE id = ?
            """, (self.player_xp, self.current_level, self.current_ex_index,
                  self.exercises_done_in_level, self.player_id))
            conn.commit()
            conn.close()
            # DEBUG
            print(f"[💾] Salvo: Lv={self.current_level}, "
                  f"Ex={self.current_ex_index}, "
                  f"Done={self.exercises_done_in_level}, "
                  f"XP={self.player_xp}")
        except Exception as e:
            print(f"[❌] Erro ao salvar progresso: {e}")

    # ---------- MAIN LAB ----------

    def show_lab(self):
        self.clear_screen()

        # Top bar
        top = tk.Frame(self.root, bg=COLORS["bg2"],
                       bd=1, relief="solid",
                       highlightbackground=COLORS["border"],
                       highlightthickness=1)
        top.pack(fill="x", padx=10, pady=(10, 5))

        lbl_mod = tk.Label(top,
                           text=f"🛡️ Módulo: {self.current_level}/3 "
                                f"({self.level_name(self.current_level)})",
                           font=FONTS["mono"], bg=COLORS["bg2"],
                           fg=COLORS["accent"])
        lbl_mod.pack(side="left", padx=12, pady=8)

        self.lbl_xp = tk.Label(top,
                               text=f"XP: {self.player_xp}",
                               font=FONTS["mono"], bg=COLORS["bg2"],
                               fg=COLORS["success"])
        self.lbl_xp.pack(side="right", padx=12, pady=8)

        self.lbl_player = tk.Label(top,
                                   text=f"Operador: {self.player_name}",
                                   font=FONTS["mono_small"], bg=COLORS["bg2"],
                                   fg=COLORS["text"])
        self.lbl_player.pack(side="right", padx=12, pady=8)

        # Body
        body = tk.Frame(self.root, bg=COLORS["bg"])
        body.pack(fill="both", expand=True, padx=10, pady=5)

        # Left panel
        left = tk.Frame(body, bg=COLORS["bg"])
        left.pack(side="left", fill="both", expand=True, padx=(0, 5))

        card = tk.Frame(left, bg=COLORS["bg2"],
                        bd=1, relief="solid",
                        highlightbackground=COLORS["border"],
                        highlightthickness=1, padx=15, pady=12)
        card.pack(fill="x")

        self.lbl_progress = tk.Label(card, text="Progresso do Nível",
                                     font=FONTS["mono_small"],
                                     bg=COLORS["bg2"], fg=COLORS["text"])
        self.lbl_progress.pack(anchor="w")

        self.progress_bar = ttk.Progressbar(card,
                                            length=400,
                                            mode="determinate",
                                            style="Cyber.Horizontal.TProgressbar")
        self.progress_bar.pack(fill="x", pady=5)

        style = ttk.Style()
        style.theme_use("clam")
        style.configure("Cyber.Horizontal.TProgressbar",
                        troughcolor=COLORS["bg3"],
                        background=COLORS["accent"],
                        bordercolor=COLORS["border"],
                        lightcolor=COLORS["accent"],
                        darkcolor=COLORS["accent"])

        self.lbl_ex_title = tk.Label(card,
                                     text="",
                                     font=FONTS["heading"],
                                     bg=COLORS["bg2"], fg=COLORS["warning"])
        self.lbl_ex_title.pack(anchor="w", pady=(10, 5))

        self.lbl_ex_desc = tk.Label(card,
                                    text="",
                                    font=FONTS["mono"],
                                    bg=COLORS["bg2"], fg=COLORS["text"],
                                    justify="left", wraplength=380)
        self.lbl_ex_desc.pack(anchor="w", pady=(0, 8))

        status_frame = tk.Frame(card, bg=COLORS["bg2"])
        status_frame.pack(fill="x")
        tk.Label(status_frame, text="Status: ",
                 font=FONTS["mono"], bg=COLORS["bg2"],
                 fg=COLORS["text"]).pack(side="left")
        self.lbl_status = tk.Label(status_frame, text="PENDENTE",
                                   font=FONTS["mono"],
                                   bg=COLORS["bg2"], fg=COLORS["warning"])
        self.lbl_status.pack(side="left")

        self.btn_hint = tk.Button(card, text="💡 Dica",
                                  font=FONTS["mono_small"],
                                  bg=COLORS["bg3"], fg=COLORS["text"],
                                  bd=1, relief="solid", cursor="hand2",
                                  command=self.show_hint)
        self.btn_hint.pack(anchor="e", pady=(8, 0))

        # Cert buttons
        self.cert_frame = tk.Frame(card, bg=COLORS["bg2"])
        self.cert_frame.pack(fill="x", pady=(8, 0))

        self.btn_show_cert_basic = tk.Button(
            self.cert_frame,
            text="📜 Certificado Básico",
            font=FONTS["mono_small"],
            bg=COLORS["success"], fg=COLORS["bg"],
            bd=0, padx=8, pady=4, cursor="hand2",
            command=lambda: self.view_certificate("básico"))
        self.btn_show_cert_inter = tk.Button(
            self.cert_frame,
            text="📜 Certificado Intermediário",
            font=FONTS["mono_small"],
            bg=COLORS["accent"], fg=COLORS["bg"],
            bd=0, padx=8, pady=4, cursor="hand2",
            command=lambda: self.view_certificate("intermediário"))
        self.btn_show_cert_adv = tk.Button(
            self.cert_frame,
            text="📜 Certificado Avançado",
            font=FONTS["mono_small"],
            bg=COLORS["warning"], fg=COLORS["bg"],
            bd=0, padx=8, pady=4, cursor="hand2",
            command=lambda: self.view_certificate("avançado"))

        # Right panel - Terminal
        right = tk.Frame(body, bg=COLORS["bg"])
        right.pack(side="right", fill="both", expand=True, padx=(5, 0))

        term_frame = tk.Frame(right, bg=COLORS["card_bg"],
                              bd=1, relief="solid",
                              highlightbackground=COLORS["border"],
                              highlightthickness=1)
        term_frame.pack(fill="both", expand=True)

        self.terminal_text = tk.Text(term_frame,
                                     font=FONTS["mono"],
                                     bg=COLORS["card_bg"],
                                     fg=COLORS["text"],
                                     bd=0,
                                     wrap="word",
                                     state="disabled",
                                     cursor="arrow",
                                     insertbackground=COLORS["accent"],
                                     height=12)
        self.terminal_text.pack(fill="both", expand=True, padx=5, pady=5)

        self.terminal_text.tag_config("prompt", foreground=COLORS["prompt"])
        self.terminal_text.tag_config("success", foreground=COLORS["success"])
        self.terminal_text.tag_config("error", foreground=COLORS["error"])
        self.terminal_text.tag_config("info", foreground=COLORS["accent"])
        self.terminal_text.tag_config("warning", foreground=COLORS["warning"])

        input_frame = tk.Frame(right, bg=COLORS["bg"])
        input_frame.pack(fill="x", pady=(5, 0))

        lbl_prompt = tk.Label(input_frame, text="root@fydelis:~# ",
                              font=FONTS["mono"], bg=COLORS["bg"],
                              fg=COLORS["prompt"])
        lbl_prompt.pack(side="left")

        self.entry_cmd = tk.Entry(input_frame,
                                  font=FONTS["mono"],
                                  bg=COLORS["bg"],
                                  fg=COLORS["text"],
                                  bd=0,
                                  insertbackground=COLORS["accent"])
        self.entry_cmd.pack(side="left", fill="x", expand=True, ipady=3)
        self.entry_cmd.focus_set()
        self.entry_cmd.bind("<Return>", self.on_command)

        # Load and show
        self.load_exercises_for_level()
        self.show_current_exercise()
        self.update_cert_buttons()

        # FIX: Mensagem de retomada mais clara
        if self.current_ex_index > 0:
            self.write_terminal(
                f"[+] 🔁 RETOMANDO PROGRESSO SALVO\n"
                f"    Operador: {self.player_name}\n"
                f"    Nível: {self.level_name(self.current_level)} ({self.current_level}/3)\n"
                f"    Exercício atual: {self.current_ex_index + 1} de {self.total_exercises_in_level}\n"
                f"    XP acumulado: {self.player_xp}\n"
                f"[+] Digite 'help' para ver os comandos.\n",
                "success")
        else:
            self.write_terminal(
                "Bem-vindo ao FydelisLab Interface.\n"
                "Digite 'help' para ver os comandos disponíveis.\n",
                "info")

    def level_name(self, level):
        names = {1: "Iniciante", 2: "Intermediário", 3: "Avançado"}
        return names.get(level, "Desconhecido")

    def load_exercises_for_level(self):
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM exercises
            WHERE level = ?
            ORDER BY order_num
        """, (self.current_level,))
        self.level_exercises = cursor.fetchall()
        self.total_exercises_in_level = len(self.level_exercises)
        conn.close()

        # Se o índice salvo for maior que o número de exercícios, trata como nível completo
        if self.current_ex_index >= len(self.level_exercises):
            self.current_ex_index = 0
            self.exercises_done_in_level = len(self.level_exercises)

    def show_current_exercise(self):
        if self.current_ex_index >= len(self.level_exercises):
            if self.current_level < 3:
                self.on_level_complete()
            else:
                self.show_final_completion()
            return

        ex = self.level_exercises[self.current_ex_index]
        self.lbl_ex_title.config(
            text=f"Exercício {ex['order_num']}: {ex['title']}")
        self.lbl_ex_desc.config(text=ex['description'])

        if self.exercises_done_in_level < self.current_ex_index + 1:
            self.lbl_status.config(text="PENDENTE", fg=COLORS["warning"])
        else:
            self.lbl_status.config(text="CONCLUÍDO ✓", fg=COLORS["success"])

        progress_val = (self.current_ex_index / max(self.total_exercises_in_level, 1)) * 100
        self.progress_bar["value"] = progress_val
        self.lbl_progress.config(
            text=f"Progresso: {self.current_ex_index}/{self.total_exercises_in_level} exercícios"
        )

        self.current_hint = ex["hint"] if ex["hint"] else "Tente ler o enunciado com atenção."

    def show_hint(self):
        self.write_terminal(f"\n💡 Dica: {self.current_hint}\n", "warning")

    def on_command(self, event=None):
        cmd = self.entry_cmd.get().strip()
        self.entry_cmd.delete(0, "end")

        self.write_terminal(f"root@fydelis:~# {cmd}\n", "prompt")

        if not cmd:
            return

        cmd_lower = cmd.lower()

        if cmd_lower == "help":
            if self.current_ex_index < len(self.level_exercises):
                ex = self.level_exercises[self.current_ex_index]
                self.write_terminal(
                    f"  Comandos globais: help, clear, ls\n"
                    f"  Comando esperado neste exercício:\n"
                    f"    {ex['correct_command']}\n"
                    f"  💡 Dica: clique no botão 'Dica'\n",
                    "info")
            else:
                self.write_terminal("  Comandos globais: help, clear, ls\n", "info")

        elif cmd_lower == "clear":
            self.terminal_text.config(state="normal")
            self.terminal_text.delete("1.0", "end")
            self.terminal_text.config(state="disabled")

        elif cmd_lower == "ls":
            if self.current_level == 1:
                self.write_terminal("  secrets.txt  flag.txt  .hidden_dir\n", "info")
            elif self.current_level == 2:
                self.write_terminal("  network_map.log  targets.txt  passwords.txt  ssh_config\n", "info")
            else:
                self.write_terminal("  auth_system.bin  database.db  exploit.sh  flag.txt\n", "info")

        elif self.current_ex_index < len(self.level_exercises):
            ex = self.level_exercises[self.current_ex_index]
            expected = ex["correct_command"].strip().lower()

            if cmd_lower == expected:
                xp_gain = 150
                self.player_xp += xp_gain
                self.lbl_xp.config(text=f"XP: {self.player_xp}")

                msg = f"[+] (+{xp_gain} XP) Exercício concluído! {ex['title']} - OK!\n"
                self.write_terminal(msg, "success")
                self.lbl_status.config(text="CONCLUÍDO ✓", fg=COLORS["success"])

                self.current_ex_index += 1
                self.exercises_done_in_level = self.current_ex_index

                # SALVA IMEDIATAMENTE após cada exercício
                self.save_full_progress()

                progress_val = (self.current_ex_index / max(self.total_exercises_in_level, 1)) * 100
                self.progress_bar["value"] = progress_val
                self.lbl_progress.config(
                    text=f"Progresso: {self.current_ex_index}/{self.total_exercises_in_level} exercícios"
                )

                if self.current_ex_index >= len(self.level_exercises):
                    self.root.after(500, self.on_level_complete)
                else:
                    self.root.after(500, self.show_current_exercise)
                    self.root.after(500, self.update_cert_buttons)
            else:
                self.write_terminal(
                    f"[-] Comando incorreto para este exercício.\n"
                    f"    Digite 'help' ou clique em 'Dica'.\n", "error")
        else:
            self.write_terminal("[-] Todos os exercícios deste nível foram concluídos!\n", "success")

    def on_level_complete(self):
        level_names = {1: "básico", 2: "intermediário", 3: "avançado"}
        level_col = {
            1: "basic_completed",
            2: "intermediate_completed",
            3: "advanced_completed"
        }
        level_name = level_names[self.current_level]
        col_name = level_col[self.current_level]

        conn = get_db()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT id FROM certificates
            WHERE player_id = ? AND level = ?
        """, (self.player_id, level_name))
        if not cursor.fetchone():
            cursor.execute("""
                INSERT INTO certificates (player_id, level)
                VALUES (?, ?)
            """, (self.player_id, level_name))
            cursor.execute(f"""
                UPDATE player SET {col_name} = 1 WHERE id = ?
            """, (self.player_id,))
            conn.commit()

            self.save_full_progress()
            self.root.after(200, lambda: show_certificate(
                self.root, self.player_name, level_name,
                custom_bg_path=self.custom_cert_bg,
                on_close_callback=self.advance_level
            ))
        else:
            self.root.after(200, self.advance_level)

        conn.close()

    def advance_level(self):
        if self.current_level < 3:
            self.current_level += 1
            self.current_ex_index = 0
            self.exercises_done_in_level = 0
            self.save_full_progress()
            self.load_exercises_for_level()
            self.show_current_exercise()
            self.update_cert_buttons()

            for widget in self.root.winfo_children():
                if isinstance(widget, tk.Frame):
                    for child in widget.winfo_children():
                        if isinstance(child, tk.Label) and "Módulo:" in child.cget("text"):
                            child.config(
                                text=f"🛡️ Módulo: {self.current_level}/3 "
                                     f"({self.level_name(self.current_level)})"
                            )
                            break

            self.write_terminal(
                f"\n{'='*50}\n"
                f"  🚀 AVANÇANDO PARA NÍVEL "
                f"{self.level_name(self.current_level).upper()}!\n"
                f"{'='*50}\n\n",
                "success"
            )
        else:
            self.show_final_completion()

    def show_final_completion(self):
        self.lbl_ex_title.config(text="🎉 LABORATÓRIO COMPLETO!")
        self.lbl_ex_desc.config(text="")
        self.lbl_status.config(
            text="VOCÊ CONCLUIU TODOS OS NÍVEIS! PARABÉNS! 🏆",
            fg=COLORS["success"])
        self.progress_bar["value"] = 100
        self.lbl_progress.config(text="100% - Todos os exercícios concluídos!")

        self.write_terminal(
            f"\n{'='*50}\n"
            f"  🏆 PARABÉNS, {self.player_name.upper()}!\n"
            f"  VOCÊ COMPLETOU O FydelisLab COMPLETO!\n"
            f"  NÍVEL MÁXIMO ALCANÇADO: AVANÇADO\n"
            f"  XP TOTAL: {self.player_xp}\n"
            f"{'='*50}\n\n"
            f"  Compartilhe sua conquista! 🚀\n\n"
            f"  📸 Os certificados foram salvos na pasta 'certificados/'\n",
            "success"
        )

        self.update_cert_buttons()
        self.entry_cmd.config(state="disabled")

    def update_cert_buttons(self):
        conn = get_db()
        cursor = conn.cursor()

        for btn in [self.btn_show_cert_basic, self.btn_show_cert_inter,
                    self.btn_show_cert_adv]:
            btn.pack_forget()

        cursor.execute("""
            SELECT level FROM certificates
            WHERE player_id = ?
        """, (self.player_id,))
        certs = [row["level"] for row in cursor.fetchall()]

        if "básico" in certs:
            self.btn_show_cert_basic.pack(side="left", padx=2, pady=2)
        if "intermediário" in certs:
            self.btn_show_cert_inter.pack(side="left", padx=2, pady=2)
        if "avançado" in certs:
            self.btn_show_cert_adv.pack(side="left", padx=2, pady=2)

        conn.close()

    def view_certificate(self, level):
        show_certificate(self.root, self.player_name, level,
                         custom_bg_path=self.custom_cert_bg)

    def write_terminal(self, text, tag=None):
        self.terminal_text.config(state="normal")
        if tag:
            self.terminal_text.insert("end", text, tag)
        else:
            self.terminal_text.insert("end", text)
        self.terminal_text.see("end")
        self.terminal_text.config(state="disabled")


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    import sys

    custom_bg = None
    if len(sys.argv) > 1:
        bg_path = sys.argv[1]
        if os.path.exists(bg_path):
            custom_bg = bg_path
            print(f"[+] Usando imagem de fundo personalizada: {custom_bg}")
        else:
            print(f"[-] Arquivo não encontrado: {bg_path}")

    if not PILLOW_AVAILABLE:
        print("[!] Pillow não instalado. Execute: pip install Pillow")
        print("[!] Os certificados serão exibidos em modo texto.\n")

    print(f"[+] Banco de dados em: {DB_PATH}")
    ensure_dirs()
    root = tk.Tk()
    app = FydelisLabApp(root, custom_cert_bg=custom_bg)
    root.mainloop()