"""
Faz backup do banco de dados com timestamp.
"""
import shutil
import os
from datetime import datetime

DB_PATH = "bancos/fydelislab.db"


def backup():
    if not os.path.exists(DB_PATH):
        print("❌ Banco de dados não encontrado. Execute o FydelisLab.py primeiro.")
        return

    os.makedirs("backups", exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"backups/FydelisLab_backup_{timestamp}.db"

    try:
        shutil.copy2(DB_PATH, backup_name)
        print(f"✅ Backup salvo em: {backup_name}")
        print(f"   Tamanho: {os.path.getsize(backup_name) / 1024:.1f} KB")
    except Exception as e:
        print(f"❌ Erro ao fazer backup: {e}")


if __name__ == "__main__":
    backup()