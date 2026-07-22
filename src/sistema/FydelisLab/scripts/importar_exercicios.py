"""
Importa exercícios de um arquivo CSV.
O CSV deve ter as colunas: Nível, Ordem, Título, Descrição, Comando Correto, Dica
"""
import sqlite3
import csv
import os

DB_PATH = "bancos/fydelislab.db"


def importar():
    if not os.path.exists(DB_PATH):
        print("❌ Banco de dados não encontrado. Execute o FydelisLab.py primeiro.")
        return

    csv_path = input("Caminho do arquivo CSV para importar: ").strip()
    if not os.path.exists(csv_path):
        print("❌ Arquivo não encontrado.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    count = 0
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                cursor.execute("""
                    INSERT INTO exercises (level, order_num, title, description, correct_command, hint)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    int(row.get("Nível", row.get("level", 0))),
                    int(row.get("Ordem", row.get("order_num", 0))),
                    row.get("Título", row.get("title", "")),
                    row.get("Descrição", row.get("description", "")),
                    row.get("Comando Correto", row.get("correct_command", "")),
                    row.get("Dica", row.get("hint", "")),
                ))
                count += 1
            except Exception as e:
                print(f"  ⚠️ Erro na linha {count + 2}: {e}")

    conn.commit()
    conn.close()
    print(f"✅ Importados {count} exercícios com sucesso!")


if __name__ == "__main__":
    importar()