import os
from flask import Flask, render_template, request, jsonify, redirect, url_for, session
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv
import requests
from datetime import datetime

# ---------------------- CONFIGURAÇÕES ----------------------
load_dotenv()
app = Flask(__name__)

# Chave de segurança
app.secret_key = os.getenv("SECRET_KEY", "chave_segura_para_sessao_123456")

# Banco de dados
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///fydelistech.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Configurações de sessão
app.config['SESSION_COOKIE_SECURE'] = False
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['PERMANENT_SESSION_LIFETIME'] = 86400  # 1 dia

db = SQLAlchemy(app)

# ---------------------- CONFIGURAÇÕES OLLAMA ----------------------
OLLAMA_URL = "http://localhost:11434/api/generate"
MODELO_IA = "gemma:2b-instruct-q4_K_M"  # Modelo leve ideal para a ISO/Notebook

def consultar_ollama(mensagem):
    # Unificado com a persona cyberpunk técnica do fydel_ai.py
    instrucao_sistema = """Você é a FydelisTech-AI, a inteligência artificial oficial do FydelisTechOS. 
Responda sempre em português, de forma direta, técnica, cyberpunk e especializada em segurança da informação e pentest.
Mostre comandos práticos sempre que necessário e relembre que o uso das ferramentas deve respeitar permissões legais."""

    dados = {
        "model": MODELO_IA,
        "prompt": f"{instrucao_sistema}\n\nOperador: {mensagem}",
        "stream": False,
        "keep_alive": -1,
        "options": {
            "temperature": 0.3,
            "num_ctx": 2048,      # Espaço para contexto técnico
            "num_predict": 256,    # Respostas curtas e ágeis no terminal web
            "low_vram": True       # Otimizado para hardware antigo/antigo
        }
    }
    try:
        resposta = requests.post(OLLAMA_URL, json=dados, timeout=60)
        resposta.raise_for_status()
        return resposta.json().get("response", "Sem resposta.")
    except requests.exceptions.Timeout:
        return "❌ Erro: O motor FydelisTech-AI demorou muito para responder. Verifique a carga do sistema."
    except Exception as e:
        return f"❌ O motor FydelisTech-AI (Ollama) não está respondendo localmente: {str(e)}"

# ---------------------- BANCO DE DADOS ----------------------
class UsuarioDB(db.Model):
    __tablename__ = 'usuario'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    senha_hash = db.Column(db.String(256), nullable=False)
    is_premium = db.Column(db.Boolean, default=False)
    saldo = db.Column(db.Float, default=0.0)

    def definir_senha(self, senha):
        self.senha_hash = generate_password_hash(senha)

    def verificar_senha(self, senha):
        return check_password_hash(self.senha_hash, senha)

class LogAtividade(db.Model):
    __tablename__ = 'logs'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuario.id'), nullable=False)
    conteudo = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

# ---------------------- ROTAS ----------------------
@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if 'usuario_id' in session:
        return redirect(url_for('ia'))
    erro = None
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        senha = request.form.get('senha', '').strip()
        usuario = UsuarioDB.query.filter_by(email=email).first()
        if usuario and usuario.verificar_senha(senha):
            session['usuario_id'] = usuario.id
            session['email'] = usuario.email
            return redirect(url_for('ia'))
        erro = "E-mail ou senha incorretos"
    return render_template('login.html', erro=erro)

@app.route('/registrar', methods=['GET', 'POST'])
def registrar():
    if 'usuario_id' in session:
        return redirect(url_for('ia'))
    erro = None
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        senha = request.form.get('senha', '').strip()
        if UsuarioDB.query.filter_by(email=email).first():
            erro = "Este e-mail já está cadastrado"
        elif len(senha) < 6:
            erro = "A senha deve ter pelo menos 6 caracteres"
        else:
            novo_usuario = UsuarioDB(email=email)
            novo_usuario.definir_senha(senha)
            db.session.add(novo_usuario)
            db.session.commit()
            return redirect(url_for('login'))
    return render_template('registrar.html', erro=erro)

@app.route('/ia')
def ia():
    if 'usuario_id' not in session:
        return redirect(url_for('login'))
    
    usuario = UsuarioDB.query.get(session['usuario_id'])
    if usuario is None:
        session.clear()
        return redirect(url_for('login'))

    return render_template(
        'index.html',
        saldo=usuario.saldo,
        is_premium=usuario.is_premium,
        email=usuario.email
    )

@app.route('/conversar', methods=['POST'])
def conversar():
    if 'usuario_id' not in session:
        return jsonify({"conteudo": "Acesso não autorizado."}), 403

    dados = request.get_json() or {}
    mensagem = dados.get("mensagem", "").strip()

    if not mensagem:
        return jsonify({"conteudo": "Digite uma mensagem válida."})

    # Consome o Ollama com a nova persona unificada
    resposta = consultar_ollama(mensagem)

    # Registro de auditoria no Painel Admin
    novo_log = LogAtividade(
        usuario_id=session['usuario_id'],
        conteudo=f"Usuário: {mensagem}\nIA: {resposta}"
    )
    db.session.add(novo_log)
    db.session.commit()

    return jsonify({"conteudo": resposta})

@app.route('/trocar_conta')
def trocar_conta():
    return redirect(url_for('logout'))

@app.route('/planos')
def planos():
    return render_template('planos.html')

@app.route('/admin')
def admin():
    if 'usuario_id' not in session:
        return redirect(url_for('login'))
    logs = LogAtividade.query.order_by(LogAtividade.timestamp.desc()).all()
    return render_template('admin.html', logs=logs)

@app.route('/gerar-foto', methods=['POST'])
def gerar_foto():
    return jsonify({"erro": "Módulo de geração de imagem não disponível nesta versão"})

@app.route('/gerar-video', methods=['POST'])
def gerar_video():
    return jsonify({"erro": "Módulo de geração de vídeo não disponível nesta versão"})

@app.route('/confirmar-pagamento', methods=['POST'])
def confirmar_pagamento():
    if 'usuario_id' not in session:
        return jsonify({"status": "erro", "mensagem": "Não autorizado"})
    dados = request.get_json()
    usuario = UsuarioDB.query.get(session['usuario_id'])
    if usuario and dados.get('valor'):
        usuario.saldo += float(dados['valor'])
        usuario.is_premium = True
        db.session.commit()
        return jsonify({"status": "sucesso", "mensagem": "Pagamento confirmado"})
    return jsonify({"status": "erro", "mensagem": "Dados inválidos"})

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# ---------------------- INICIAR SERVIDOR ----------------------
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        print("Banco de dados sincronizado!")
    app.run(host='0.0.0.0', port=5000, debug=True)
