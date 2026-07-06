#!/usr/bin/env python3
import sys
import requests
import json

# Configurações de cores ANSI (Estilo Cyberpunk)
ROXO = "\033[38;2;120;90;255m"
BRANCO = "\033[38;2;245;248;255m"
RESET = "\033[0m"

def detectar_melhor_modelo():
    try:
        # Lê a memória RAM total disponível no sistema em kB
        with open('/proc/meminfo', 'r') as f:
            for linha in f:
                if 'MemTotal' in linha:
                    mem_kb = int(linha.split()[1])
                    mem_gb = mem_kb / (1024 * 1024)
                    
                    # Se for um PC simples (menos de 4GB), vai de Gemma
                    if mem_gb < 4.0:
                        return "gemma:2b-instruct-q4_K_M"
                    else:
                        return "llama3.2:3b"
    except Exception:
        return "gemma:2b-instruct-q4_K_M" # Fallback seguro para PC fraco

def perguntar_ia(prompt, modelo_customizado=None):
    """
    Função principal que conecta ao motor Ollama.
    Seleciona dinamicamente o modelo com base no hardware se nenhum for forçado.
    """
    url = "http://localhost:11434/api/generate"
    
    # Se o Flask ou a CLI não passarem um modelo específico, detecta pela RAM
    modelo = modelo_customizado if modelo_customizado else detectar_melhor_modelo()
    
    payload = {
        "model": modelo, 
        "prompt": f"Você é a FydelisTech-AI, a inteligência artificial oficial do FydelisTechOS. Responda de forma direta, técnica e cyberpunk à seguinte questão: {prompt}",
        "stream": False
    } # Chave corrigida aqui!
    
    try:
        response = requests.post(url, json=payload, timeout=15)
        if response.status_code == 200:
            return response.json().get("response", "Sem resposta.")
        return "❌ Erro na comunicação com o motor de IA."
    except Exception:
        return f"❌ O motor FydelisTech-AI (Ollama) não está respondendo. Certifique-se de que o modelo {modelo} está carregado."

# O bloco abaixo SÓ roda se o arquivo for executado direto (ex: fydel-ai no terminal)
if __name__ == "__main__":
    modelo_ativo = detectar_melhor_modelo()
    print(f"{ROXO}🤖 FydelisTech-AI v1.0 iniciada. Perfil de hardware detectado.")
    print(f"🧠 Matriz de Inteligência Ativa: {BRANCO}{modelo_ativo}{ROXO}")
    print(f"Como posso te ajudar, operador? (Digite 'sair' para retornar){RESET}\n")

    while True:
        try:
            user_input = input(f"{BRANCO}Operador > {RESET}")
            if user_input.lower() in ['sair', 'exit', 'quit']:
                break
            if not user_input.strip():
                continue
                
            print(f"\n{ROXO}🤖 Processando na Matriz...{RESET}")
            resposta = perguntar_ia(user_input, modelo_customizado=modelo_ativo)
            print(f"\n{ROXO}FydelisTech-AI >{BRANCO} {resposta}{RESET}\n")
        except KeyboardInterrupt:
            print(f"\n{ROXO}🤖 Desconectando da Matriz...{RESET}")
            break
