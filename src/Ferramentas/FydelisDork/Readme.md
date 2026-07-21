# ======================================================================
#            F Y D E L I S D O R K   v 3 . 0   P R O
#                    FydelisTechos © 2026
#   Ferramenta Profissional de Google Dorks & OSINT
#   USO EXCLUSIVO PARA ESTUDO E PESQUISA DE DADOS PÚBLICOS
# ======================================================================

📌 O que é?
Monta buscas avançadas (Google Dorks) para encontrar dados que já estão
públicos na internet — sem acessar nada bloqueado ou privado.

📌 USO: fydelisdork -t "TERMO" [OPÇÕES]
       fydelisdork -c CATEGORIA [OPÇÕES]
       fydelisdork -i

⚙️ OPÇÕES BÁSICAS:
  -t, --termo TEXTO         🔍 Palavra ou frase principal (OBRIGATÓRIO se não usar -c)
  -c, --categoria NOME      📂 Categoria pronta (admin | painel | sql | xss | info | docs | camera)
  -s, --site DOMINIO        🌐 Apenas em um site (ex: gov.br, com.br)
  -a, --arquivo TIPO        📄 Tipo de arquivo (pdf, doc, xls, sql, txt, php, zip, csv, json)
  -T, --titulo TEXTO        📝 Palavra no título da página
  -u, --url TEXTO           🔗 Palavra no endereço da página

⚙️ OPÇÕES AVANÇADAS:
  -m, --motor MOTOR         🌍 Motor de busca (google | bing | duckduckgo | yandex | startpage | all)
  -e, --excluir TEXTO       ❌ Palavra a EXCLUIR da busca
  -E, --exato               💬 Busca exata (aspas duplas)
  -o, --operador TIPO       🔗 Operador: AND | OR | - (exclusão)
  -d, --data "INI..FIM"     📅 Filtrar intervalo de datas
  -n, --intensidade N       ⚡ 1=mínima | 2=média | 3=agressiva
  -l, --limite N            🔢 Limitar número de dorks gerados

💾 SAÍDA E EXPORTAÇÃO:
  -O, --salvar ARQUIVO      💾 Salvar as buscas geradas em arquivo
  -f, --formato FORMATO     📄 Formato: txt | html | json | csv | md (padrão: txt)
  -A, --abrir               🌐 Abrir links direto no navegador
  -v, --verbose             📣 Modo detalhado
  -i, --interativo          🎮 Modo interativo (menu guiado passo a passo)

📖 OUTROS:
  -H, --ajuda               📖 Esta tela de ajuda
  -V, --versao              ℹ️ Mostrar versão

📝 EXEMPLOS PRÁTICOS:

  1) Encontrar PDF sobre segurança em um site:
     fydelisdork -t "segurança" -s exemplo.com -a pdf -O resultado.txt

  2) Categoria admin em sites .com.br exportando HTML:
     fydelisdork -c admin -s com.br -f html -O relatorio.html

  3) SQL injection com intensidade máxima + abrir navegador:
     fydelisdork -c sql -n 3 -A -O sqli.txt

  4) Todos os motores de busca para câmeras IP:
     fydelisdork -c camera -m all -f json -O cameras.json

  5) Modo interativo (mais fácil):
     fydelisdork -i

📂 CATEGORIAS DISPONÍVEIS:
  admin     - Painéis administrativos, logins, áreas restritas
  painel    - Dashboards, controles, monitoramento
  sql       - Potenciais SQL injection (parâmetros em URL)
  xss       - Potenciais Cross-Site Scripting
  info      - Vazamento de informações (dir listing, backups)
  docs      - Documentos públicos sensíveis (PDF, DOC, XLS)
  camera    - Câmeras IP e webcams públicas

⚠️  AVISO: USO EXCLUSIVO PARA ESTUDO E PESQUISA DE DADOS PÚBLICOS
