#!/usr/bin/env python3
import sys
import requests
import json

# Configurações de cores ANSI
ROXO = "\033[38;2;120;90;255m"
BRANCO = "\033[38;2;245;248;255m"
RESET = "\033[0m"

def perguntar_ia(prompt):
    """
    Função principal que conecta ao motor Ollama.
    Pode ser chamada via CLI ou importada pelo Flask (app.py).
    """
    url = "http://localhost:11434/api/generate"
    payload = {
        "model": "llama3", 
        "prompt": f"Você é a FydelisTech-AI, a inteligência artificial oficial do FydelisTechOS. Responda de forma direta, técnica e cyberpunk à seguinte questão: {prompt}",
        "stream": False
    )
    
    try:
        response = requests.post(url, json=payload, timeout=10)
        if response.status_code == 200:
            return response.json().get("response", "Sem resposta.")
        return "❌ Erro na comunicação com o motor de IA."
    except Exception:
        return "❌ O motor FydelisTech-AI (Ollama) não está respondendo ou não está rodando."

# O bloco abaixo SÓ roda se o arquivo for executado direto (ex: fydel-ai no terminal)
# Se o app.py importar este arquivo, o bloco abaixo é ignorado.
if __name__ == "__main__":
    print(f"{ROXO}🤖 FydelisTech-AI v1.0 iniciada. Como posso te ajudar, operador? (Digite 'sair' para retornar){RESET}\n")

    while True:
        try:
            user_input = input(f"{BRANCO}Operador > {RESET}")
            if user_input.lower() in ['sair', 'exit', 'quit']:
                break
            if not user_input.strip():
                continue
                
            print(f"\n{ROXO}🤖 Pensando...{RESET}")
            resposta = perguntar_ia(user_input)
            print(f"\n{ROXO}FydelisTech-AI >{BRANCO} {resposta}{RESET}\n")
        except KeyboardInterrupt:
            break
