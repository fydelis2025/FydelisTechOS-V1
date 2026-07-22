"""
Gerenciador de Exercícios do FydelisLab
Adicione, edite, liste ou remova exercícios diretamente pelo terminal.
"""
import sqlite3
import os

DB_PATH = "bancos/fydelislab.db"


def conectar():
    os.makedirs("bancos", exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def listar_exercicios():
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT e.*, 
               CASE e.level 
                   WHEN 1 THEN 'Básico' 
                   WHEN 2 THEN 'Intermediário' 
                   WHEN 3 THEN 'Avançado' 
               END AS level_name
        FROM exercises e
        ORDER BY e.level, e.order_num
    """)
    exs = cursor.fetchall()
    conn.close()

    if not exs:
        print("Nenhum exercício cadastrado.")
        return

    print("\n" + "="*100)
    print(f"{'ID':<4} {'Nível':<14} {'Ordem':<6} {'Título':<30} {'Comando':<30}")
    print("="*100)
    for ex in exs:
        print(f"{ex['id']:<4} {ex['level_name']:<14} {ex['order_num']:<6} "
              f"{ex['title'][:28]:<30} {ex['correct_command'][:28]:<30}")
    print("="*100)


def adicionar_exercicio():
    print("\n--- NOVO EXERCÍCIO ---")
    try:
        level = int(input("Nível (1=Básico, 2=Intermediário, 3=Avançado): "))
        order = int(input("Ordem dentro do nível (1, 2, 3...): "))
    except ValueError:
        print("❌ Nível e ordem devem ser números.")
        return
    title = input("Título do exercício: ").strip()
    desc = input("Descrição/enunciado: ").strip()
    cmd = input("Comando correto: ").strip()
    hint = input("Dica (opcional): ").strip()

    if not title or not desc or not cmd:
        print("❌ Título, descrição e comando são obrigatórios.")
        return

    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO exercises (level, order_num, title, description, correct_command, hint)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (level, order, title, desc, cmd, hint))
    conn.commit()
    conn.close()
    print("✅ Exercício adicionado com sucesso!")


def editar_exercicio():
    listar_exercicios()
    try:
        ex_id = int(input("\nID do exercício para editar: "))
    except ValueError:
        print("❌ ID inválido.")
        return

    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM exercises WHERE id = ?", (ex_id,))
    ex = cursor.fetchone()
    if not ex:
        print("❌ ID não encontrado.")
        conn.close()
        return

    print("\nDeixe em branco para manter o valor atual:")
    level = input(f"Nível [{ex['level']}]: ").strip()
    order = input(f"Ordem [{ex['order_num']}]: ").strip()
    title = input(f"Título [{ex['title']}]: ").strip()
    desc = input(f"Descrição [{ex['description']}]: ").strip()
    cmd = input(f"Comando [{ex['correct_command']}]: ").strip()
    hint = input(f"Dica [{ex['hint']}]: ").strip()

    try:
        cursor.execute("""
            UPDATE exercises SET
                level = ?, order_num = ?, title = ?, description = ?,
                correct_command = ?, hint = ?
            WHERE id = ?
        """, (
            int(level) if level else ex['level'],
            int(order) if order else ex['order_num'],
            title if title else ex['title'],
            desc if desc else ex['description'],
            cmd if cmd else ex['correct_command'],
            hint if hint else ex['hint'],
            ex_id
        ))
        conn.commit()
        print("✅ Exercício atualizado!")
    except Exception as e:
        print(f"❌ Erro ao atualizar: {e}")
    finally:
        conn.close()


def remover_exercicio():
    listar_exercicios()
    try:
        ex_id = int(input("\nID do exercício para remover: "))
    except ValueError:
        print("❌ ID inválido.")
        return

    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT title FROM exercises WHERE id = ?", (ex_id,))
    ex = cursor.fetchone()
    if not ex:
        print("❌ ID não encontrado.")
        conn.close()
        return

    conf = input(f"Remover '{ex['title']}'? (s/N): ").strip().lower()
    if conf == 's':
        cursor.execute("DELETE FROM exercises WHERE id = ?", (ex_id,))
        conn.commit()
        print("🗑️ Exercício removido.")
    else:
        print("Operação cancelada.")
    conn.close()


def resetar_exercicios():
    print("\n⚠️  Isso vai APAGAR TODOS os exercícios e recriar os originais.")
    conf = input("Continuar? (s/N): ").strip().lower()
    if conf != 's':
        print("Operação cancelada.")
        return

    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM exercises")

    exercicios = [
        (1, 1, "Permissões de Arquivo",
         "O arquivo secrets.txt está bloqueado. Use o comando para liberar acesso total.",
         "chmod 777 secrets.txt", "Tente: chmod 777 secrets.txt"),
        (1, 2, "Navegação em Diretórios",
         "Você precisa encontrar a pasta oculta. Use o comando para listar diretórios ocultos.",
         "ls -la", "Tente: ls -la para ver arquivos ocultos"),
        (1, 3, "Leitura de Arquivo",
         "Leia o conteúdo do arquivo flag.txt usando o comando correto.",
         "cat flag.txt", "Tente: cat flag.txt"),
        (2, 1, "Varredura de Rede",
         "Identifique hosts ativos na rede. Use o comando de varredura.",
         "nmap -sn 192.168.1.0/24", "Tente: nmap -sn 192.168.1.0/24"),
        (2, 2, "Descobrindo Portas",
         "Descubra quais portas estão abertas no servidor alvo.",
         "nmap -p 1-1000 192.168.1.10", "Tente: nmap -p 1-1000 192.168.1.10"),
        (2, 3, "Força Bruta SSH",
         "Tente acessar o servidor SSH com o usuário admin.",
         "hydra -l admin -P passwords.txt ssh://192.168.1.10",
         "Tente: hydra -l admin -P passwords.txt ssh://192.168.1.10"),
        (3, 1, "Injeção SQL",
         "A página de login é vulnerável. Injete o payload para bypass.",
         "' OR 1=1 --", "Tente: ' OR 1=1 --"),
        (3, 2, "Escalação de Privilégio",
         "Você tem acesso de usuário. Escalone para root.",
         "sudo su", "Tente: sudo su"),
        (3, 3, "Captura da Bandeira Final",
         "Execute o exploit final para capturar a flag do sistema.",
         "exploit --target=auth --flag", "Tente: exploit --target=auth --flag"),
    ]
    cursor.executemany("""
        INSERT INTO exercises (level, order_num, title, description, correct_command, hint)
        VALUES (?, ?, ?, ?, ?, ?)
    """, exercicios)
    conn.commit()
    conn.close()
    print("✅ Exercícios restaurados ao padrão!")


def ver_estatisticas():
    conn = conectar()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM exercises")
    total = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM exercises WHERE level = 1")
    basico = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM exercises WHERE level = 2")
    inter = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM exercises WHERE level = 3")
    avanc = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM player")
    jogadores = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM certificates")
    certificados = cursor.fetchone()[0]

    conn.close()

    print("\n" + "="*40)
    print("  📊 ESTATÍSTICAS DO FydelisLAB")
    print("="*40)
    print(f"  Total de exercícios:  {total}")
    print(f"    Nível Básico:       {basico}")
    print(f"    Nível Intermediário:{inter}")
    print(f"    Nível Avançado:     {avanc}")
    print(f"  Jogadores cadastrados:{jogadores}")
    print(f"  Certificados emitidos:{certificados}")
    print("="*40)


def menu():
    while True:
        print("\n" + "="*40)
        print("  GERENCIADOR DE EXERCÍCIOS - FydelisLAB")
        print("="*40)
        print("1. Listar exercícios")
        print("2. Adicionar exercício")
        print("3. Editar exercício")
        print("4. Remover exercício")
        print("5. Resetar para padrão")
        print("6. Estatísticas")
        print("0. Sair")
        print("="*40)

        op = input("Opção: ").strip()

        if op == "1":
            listar_exercicios()
        elif op == "2":
            adicionar_exercicio()
        elif op == "3":
            editar_exercicio()
        elif op == "4":
            remover_exercicio()
        elif op == "5":
            resetar_exercicios()
        elif op == "6":
            ver_estatisticas()
        elif op == "0":
            print("Saindo...")
            break
        else:
            print("Opção inválida.")

        if op != "0":
            input("\nPressione Enter para continuar...")


if __name__ == "__main__":
    menu()