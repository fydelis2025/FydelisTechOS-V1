"""
Exporta todos os exercícios do banco para CSV.
Útil para editar em massa no Excel/LibreOffice.
"""
import sqlite3
import csv
import os

DB_PATH = "bancos/fydelislab.db"


def exportar():
    if not os.path.exists(DB_PATH):
        print("❌ Banco de dados não encontrado. Execute o FydelisLab.py primeiro.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM exercises ORDER BY level, order_num")
    exercicios = cursor.fetchall()
    conn.close()

    if not exercicios:
        print("Nenhum exercício encontrado.")
        return

    filename = "exercicios_exportados.csv"
    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["ID", "Nível", "Ordem", "Título", "Descrição", "Comando Correto", "Dica"])
        for ex in exercicios:
            writer.writerow(ex)

    print(f"✅ Exportados {len(exercicios)} exercícios para '{filename}'")
    print(f"   Abra no Excel/LibreOffice, edite e use o importador.")


if __name__ == "__main__":
    exportar()