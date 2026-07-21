#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import socket
import sys
import re
import platform
import json
from datetime import datetime

# ---- Tentar importar urllib (stdlib) ----
try:
    from urllib.request import urlopen, Request
    from urllib.error import URLError
    HAS_URLLIB = True
except ImportError:
    HAS_URLLIB = False

# ---- Servidores Whois (porta 43) por TLD ----
TLD_SERVERS = {
    'com': 'whois.verisign-grs.com',
    'net': 'whois.verisign-grs.com',
    'org': 'whois.pir.org',
    'info': 'whois.afilias.net',
    'biz': 'whois.neulevel.biz',
    'mobi': 'whois.afilias.net',
    'name': 'whois.nic.name',
    'pro': 'whois.registrypro.pro',
    'aero': 'whois.information.aero',
    'asia': 'whois.nic.asia',
    'cat': 'whois.nic.cat',
    'coop': 'whois.nic.coop',
    'edu': 'whois.educause.edu',
    'gov': 'whois.dotgov.gov',
    'int': 'whois.iana.org',
    'jobs': 'whois.nic.jobs',
    'mil': 'whois.nic.mil',
    'museum': 'whois.museum',
    'tel': 'whois.nic.tel',
    'travel': 'whois.nic.travel',
    'xxx': 'whois.nic.xxx',
    'br': 'whois.registro.br',
    'uk': 'whois.nic.uk',
    'de': 'whois.denic.de',
    'jp': 'whois.jprs.jp',
    'fr': 'whois.nic.fr',
    'au': 'whois.auda.org.au',
    'ca': 'whois.cira.ca',
    'cn': 'whois.cnnic.cn',
    'ru': 'whois.tcinet.ru',
    'io': 'whois.nic.io',
    'co': 'whois.nic.co',
    'us': 'whois.nic.us',
    'eu': 'whois.eu',
    'it': 'whois.nic.it',
    'es': 'whois.nic.es',
    'nl': 'whois.domain-registry.nl',
    'se': 'whois.iis.se',
    'no': 'whois.norid.no',
    'dk': 'whois.dk-hostmaster.dk',
    'fi': 'whois.fi',
    'pl': 'whois.dns.pl',
    'be': 'whois.dns.be',
    'at': 'whois.nic.at',
    'ch': 'whois.nic.ch',
    'pt': 'whois.dns.pt',
    'mx': 'whois.mx',
    'ar': 'whois.nic.ar',
    'cl': 'whois.nic.cl',
    'in': 'whois.registry.in',
    'me': 'whois.nic.me',
    'tv': 'whois.nic.tv',
    'cc': 'whois.nic.cc',
    'gg': 'whois.nic.gg',
    'ly': 'whois.nic.ly',
    'pe': 'whois.nic.pe',
    'uy': 'whois.nic.uy',
    'dev': 'whois.nic.google',
    'app': 'whois.nic.google',
    'cloud': 'whois.nic.cloud',
    'tech': 'whois.nic.tech',
    'online': 'whois.nic.online',
    'site': 'whois.nic.site',
    'store': 'whois.nic.store',
    'blog': 'whois.nic.blog',
    'design': 'whois.nic.design',
    'social': 'whois.nic.social',
    'xyz': 'whois.nic.xyz',
    'club': 'whois.nic.club',
    'top': 'whois.nic.top',
    'vip': 'whois.nic.vip',
    'work': 'whois.nic.work',
    'live': 'whois.nic.live',
    'today': 'whois.nic.today',
    'world': 'whois.nic.world',
}

# TLDs compostos (duas ou mais partes)
COMPOUND_TLDS = {
    # Brasil
    'com.br': 'whois.registro.br',
    'org.br': 'whois.registro.br',
    'net.br': 'whois.registro.br',
    'gov.br': 'whois.registro.br',
    'mil.br': 'whois.registro.br',
    'edu.br': 'whois.registro.br',
    'art.br': 'whois.registro.br',
    'blog.br': 'whois.registro.br',
    'emp.br': 'whois.registro.br',
    'etc.br': 'whois.registro.br',
    'fm.br': 'whois.registro.br',
    'ind.br': 'whois.registro.br',
    'inf.br': 'whois.registro.br',
    'med.br': 'whois.registro.br',
    'rec.br': 'whois.registro.br',
    'slg.br': 'whois.registro.br',
    'tmp.br': 'whois.registro.br',
    'tur.br': 'whois.registro.br',
    'tv.br': 'whois.registro.br',
    'am.br': 'whois.registro.br',
    'biz.br': 'whois.registro.br',
    'coop.br': 'whois.registro.br',
    'eco.br': 'whois.registro.br',
    'jor.br': 'whois.registro.br',
    'lel.br': 'whois.registro.br',
    'mat.br': 'whois.registro.br',
    'mus.br': 'whois.registro.br',
    'not.br': 'whois.registro.br',
    'ntr.br': 'whois.registro.br',
    'odo.br': 'whois.registro.br',
    'ppg.br': 'whois.registro.br',
    'pro.br': 'whois.registro.br',
    'seg.br': 'whois.registro.br',
    'tec.br': 'whois.registro.br',
    'vet.br': 'whois.registro.br',
    'zlg.br': 'whois.registro.br',
    'adm.br': 'whois.registro.br',
    'adv.br': 'whois.registro.br',
    'agr.br': 'whois.registro.br',
    'arq.br': 'whois.registro.br',
    'ato.br': 'whois.registro.br',
    'eng.br': 'whois.registro.br',
    'esp.br': 'whois.registro.br',
    'far.br': 'whois.registro.br',
    'fis.br': 'whois.registro.br',
    'fot.br': 'whois.registro.br',
    'geo.br': 'whois.registro.br',
    'imb.br': 'whois.registro.br',
    'ong.br': 'whois.registro.br',
    'psi.br': 'whois.registro.br',
    # Reino Unido
    'co.uk': 'whois.nic.uk',
    'org.uk': 'whois.nic.uk',
    'ac.uk': 'whois.nic.uk',
    'gov.uk': 'whois.nic.uk',
    'net.uk': 'whois.nic.uk',
    'me.uk': 'whois.nic.uk',
    'ltd.uk': 'whois.nic.uk',
    'plc.uk': 'whois.nic.uk',
    # Japão
    'co.jp': 'whois.jprs.jp',
    'ne.jp': 'whois.jprs.jp',
    'or.jp': 'whois.jprs.jp',
    'ac.jp': 'whois.jprs.jp',
    'go.jp': 'whois.jprs.jp',
    # Austrália
    'com.au': 'whois.auda.org.au',
    'net.au': 'whois.auda.org.au',
    'org.au': 'whois.auda.org.au',
    'gov.au': 'whois.auda.org.au',
    'edu.au': 'whois.auda.org.au',
    # Nova Zelândia
    'co.nz': 'whois.nsrs.net.nz',
    'net.nz': 'whois.nsrs.net.nz',
    'org.nz': 'whois.nsrs.net.nz',
    'ac.nz': 'whois.nsrs.net.nz',
    # Coreia do Sul
    'co.kr': 'whois.kr',
    'or.kr': 'whois.kr',
    'ne.kr': 'whois.kr',
    'go.kr': 'whois.kr',
    'ac.kr': 'whois.kr',
    # China
    'com.cn': 'whois.cnnic.cn',
    'net.cn': 'whois.cnnic.cn',
    'org.cn': 'whois.cnnic.cn',
    'gov.cn': 'whois.cnnic.cn',
    'edu.cn': 'whois.cnnic.cn',
    # México
    'com.mx': 'whois.mx',
    'org.mx': 'whois.mx',
    'net.mx': 'whois.mx',
    'edu.mx': 'whois.mx',
    'gob.mx': 'whois.mx',
    # Índia
    'co.in': 'whois.registry.in',
    'net.in': 'whois.registry.in',
    'org.in': 'whois.registry.in',
    'gov.in': 'whois.registry.in',
    'ac.in': 'whois.registry.in',
    'gen.in': 'whois.registry.in',
    # Argentina
    'com.ar': 'whois.nic.ar',
    'net.ar': 'whois.nic.ar',
    'org.ar': 'whois.nic.ar',
    'gov.ar': 'whois.nic.ar',
    # Portugal
    'com.pt': 'whois.dns.pt',
    'net.pt': 'whois.dns.pt',
    'org.pt': 'whois.dns.pt',
    'gov.pt': 'whois.dns.pt',
    'edu.pt': 'whois.dns.pt',
    # África do Sul
    'co.za': 'whois.registry.net.za',
    'org.za': 'whois.registry.net.za',
    'net.za': 'whois.registry.net.za',
    'gov.za': 'whois.registry.net.za',
    'ac.za': 'whois.registry.net.za',
    # Venezuela
    'com.ve': 'whois.nic.ve',
    'net.ve': 'whois.nic.ve',
    'org.ve': 'whois.nic.ve',
    'gov.ve': 'whois.nic.ve',
    # Filipinas
    'com.ph': 'whois.ph',
    'net.ph': 'whois.ph',
    'org.ph': 'whois.ph',
    'gov.ph': 'whois.ph',
}

ALL_COMPOUND_TLDS = sorted(COMPOUND_TLDS.keys(), key=len, reverse=True)
DEFAULT_WHOIS_SERVER = 'whois.iana.org'


def detect_os():
    return platform.system().lower()


def get_tld(domain):
    """Extrai o TLD do domínio"""
    domain = domain.strip().lower()
    domain = re.sub(r'^https?://', '', domain)
    domain = re.sub(r'/.*$', '', domain)
    domain = re.sub(r'^www\d*\.', '', domain)
    
    parts = domain.split('.')
    if len(parts) < 2:
        return None, domain
    
    # Tenta TLD composto
    for tld in ALL_COMPOUND_TLDS:
        tld_parts = tld.split('.')
        domain_parts = domain.split('.')
        if len(tld_parts) <= len(domain_parts):
            if domain_parts[-len(tld_parts):] == tld_parts:
                name = '.'.join(domain_parts[:-len(tld_parts)])
                return tld, name
    
    tld = parts[-1]
    name = '.'.join(parts[:-1])
    return tld, name


def get_whois_server(tld):
    if tld in COMPOUND_TLDS:
        return COMPOUND_TLDS[tld]
    return TLD_SERVERS.get(tld, DEFAULT_WHOIS_SERVER)


# ============ MÉTODO 1: Socket TCP (porta 43) ============

def perform_whois_socket(server, query, timeout=15):
    """Consulta Whois via socket TCP na porta 43"""
    try:
        socket.getaddrinfo(server, 43)
    except socket.gaierror:
        return None, f"DNS resolution failed for {server}"
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((server, 43))
        sock.send(f"{query}\r\n".encode('utf-8', errors='ignore'))
        
        response = b''
        while True:
            try:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                response += chunk
                if len(response) > 1024 * 1024:
                    break
            except socket.timeout:
                break
        
        sock.close()
        
        if not response:
            return None, "Empty response"
        
        return response.decode('utf-8', errors='replace'), None
    
    except (socket.timeout, ConnectionRefusedError, OSError) as e:
        return None, str(e)
    except Exception as e:
        return None, str(e)


# ============ MÉTODO 2: RDAP via HTTPS (fallback) ============

def perform_rdap_lookup(domain, timeout=15):
    """
    Consulta RDAP via HTTPS.
    O Registro.br oferece RDAP em: https://rdap.registro.br/domain/<dominio>
    """
    if not HAS_URLLIB:
        return None, "urllib not available"
    
    url = f"https://rdap.registro.br/domain/{domain}"
    
    try:
        req = Request(url, headers={
            'User-Agent': 'HackerAI-Whois/1.1 (Python)',
            'Accept': 'application/json',
        })
        
        with urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        
        # Converte RDAP JSON para texto legível
        text = format_rdap_to_text(data, domain)
        return text, None
    
    except URLError as e:
        return None, f"HTTP error: {e.reason}"
    except json.JSONDecodeError:
        return None, "Invalid JSON response from RDAP server"
    except Exception as e:
        return None, str(e)


def format_rdap_to_text(data, domain):
    """Converte resposta RDAP JSON em formato texto legível"""
    lines = []
    lines.append(f"Domain Name: {data.get('ldhName', domain)}")
    lines.append(f"Handle: {data.get('handle', 'N/A')}")
    
    # Status
    statuses = data.get('status', [])
    if statuses:
        lines.append(f"Status: {', '.join(statuses)}")
    
    # Dates
    for event in data.get('events', []):
        action = event.get('eventAction', '')
        date = event.get('eventDate', '')
        if action and date:
            label = {
                'registration': 'Created',
                'expiration': 'Expires',
                'last changed': 'Changed',
                'last update of RDAP database': 'Last Updated',
            }.get(action, action)
            lines.append(f"{label}: {date}")
    
    # Nameservers
    for ns in data.get('nameservers', []):
        name = ns.get('ldhName', '')
        if name:
            lines.append(f"Nameserver: {name}")
    
    # Entities (contacts)
    for entity in data.get('entities', []):
        roles = entity.get('roles', [])
        role_str = ', '.join(roles).title() if roles else 'Contact'
        name = entity.get('vcardArray', [[], []])[1] if len(entity.get('vcardArray', [[], []])) > 1 else []
        
        # Extrai nome do vcard
        contact_name = 'N/A'
        contact_email = ''
        for item in name:
            if len(item) >= 3 and item[0] == 'fn':
                contact_name = item[3]
            elif len(item) >= 3 and item[0] == 'email':
                contact_email = item[3]
        
        lines.append(f"\n{role_str}:")
        lines.append(f"  Name: {contact_name}")
        if contact_email:
            lines.append(f"  Email: {contact_email}")
        
        # Extrai organizacao
        for item in name:
            if len(item) >= 3 and item[0] == 'org':
                lines.append(f"  Organization: {item[3]}")
    
    # Remarks
    for remark in data.get('remarks', []):
        for line in remark.get('description', []):
            lines.append(f"Note: {line}")
    
    return '\n'.join(lines)


# ============ MÉTODO 3: API HTTP pública (fallback final) ============

def perform_http_whois(domain, timeout=15):
    """
    Consulta Whois via API HTTP pública.
    Usa who-dat.as93.net como fallback gratuito sem autenticação.
    """
    if not HAS_URLLIB:
        return None, "urllib not available"
    
    services = [
        f"https://who-dat.as93.net/{domain}",
    ]
    
    for url in services:
        try:
            req = Request(url, headers={
                'User-Agent': 'FydelisTech-Whois/1.1 (Python)',
                'Accept': 'text/plain, application/json',
            })
            
            with urlopen(req, timeout=timeout) as resp:
                content = resp.read().decode('utf-8', errors='replace')
            
            if content and len(content) > 50:
                # Tenta parsear como JSON se for
                try:
                    data = json.loads(content)
                    if isinstance(data, dict):
                        text = json.dumps(data, indent=2, ensure_ascii=False)
                        return text, None
                except json.JSONDecodeError:
                    pass
                return content, None
        
        except Exception as e:
            continue
    
    return None, "All HTTP services failed"


# ============ FUNÇÃO PRINCIPAL ============

def whois_lookup(domain, timeout=15, verbose=False):
    """
    Função principal com fallback automático:
    1. Tenta socket TCP (porta 43)
    2. Tenta RDAP via HTTPS
    3. Tenta API HTTP pública
    """
    domain = domain.strip()
    
    # Verifica se é IP
    is_ip = re.match(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$', domain)
    
    if is_ip:
        if verbose:
            print("[*] Modo IP detectado")
        return whois_lookup_ip(domain, timeout, verbose)
    
    # Processa domínio
    tld, clean_domain = get_tld(domain)
    if not tld:
        return "[ERRO] Não foi possível identificar o TLD."
    
    # Domínio completo para query
    if '.' in tld:
        full_domain = f"{clean_domain}.{tld}"
    else:
        full_domain = f"{clean_domain}.{tld}" if clean_domain else tld
    
    server = get_whois_server(tld)
    
    if verbose:
        print(f"[*] Domínio: {full_domain}")
        print(f"[*] TLD: {tld}")
        print(f"[*] Servidor Whois: {server}")
    
    # --- TENTATIVA 1: Socket (porta 43) ---
    if verbose:
        print("[*] Tentativa 1: Socket TCP porta 43...")
    
    response, error = perform_whois_socket(server, full_domain, timeout)
    
    if response:
        # Procura servidor de referência
        referral = find_referral_server(response)
        if referral and referral != server:
            if verbose:
                print(f"[*] Servidor de referência: {referral}")
            response2, _ = perform_whois_socket(referral, full_domain, timeout)
            if response2 and len(response2) > 50 and 'NOT FOUND' not in response2.upper()[:200]:
                response = response2
        
        return format_response(response, f"socket:{server}", full_domain)
    
    if verbose:
        print(f"[!] Socket falhou: {error}")
    
    # --- TENTATIVA 2: RDAP (HTTPS) ---
    if verbose:
        print("[*] Tentativa 2: RDAP via HTTPS...")
    
    response, error = perform_rdap_lookup(full_domain, timeout)
    
    if response:
        return format_response(response, f"RDAP:rdap.registro.br", full_domain)
    
    if verbose:
        print(f"[!] RDAP falhou: {error}")
    
    # --- TENTATIVA 3: API HTTP pública ---
    if verbose:
        print("[*] Tentativa 3: API HTTP pública...")
    
    response, error = perform_http_whois(full_domain, timeout)
    
    if response:
        return format_response(response, "HTTP:who-dat.as93.net", full_domain)
    
    if verbose:
        print(f"[!] HTTP falhou: {error}")
    
    return f"[ERRO] Todas as tentativas falharam para {full_domain}\nÚltimo erro: {error}"


def whois_lookup_ip(ip, timeout=15, verbose=False):
    """Consulta Whois para endereço IP"""
    if verbose:
        print("[*] Tentativa 1: Socket ARIN...")
    
    response, _ = perform_whois_socket('whois.arin.net', f'n + {ip}', timeout)
    
    if response and 'No match' not in response and 'NOT FOUND' not in response:
        return format_response(response, 'socket:whois.arin.net', ip)
    
    # Fallback para outros registros
    for registry in ['whois.ripe.net', 'whois.apnic.net', 'whois.lacnic.net', 'whois.afrinic.net']:
        if verbose:
            print(f"[*] Tentando: {registry}...")
        response, _ = perform_whois_socket(registry, f'-r {ip}', timeout)
        if response and 'No match' not in response and 'NOT FOUND' not in response and len(response) > 50:
            return format_response(response, f'socket:{registry}', ip)
    
    return f"[ERRO] IP {ip} não encontrado nos registros Whois"


def find_referral_server(response):
    """Procura servidor de referência na resposta"""
    patterns = [
        r'Whois\s*Server:\s*([^\s]+)',
        r'whois\s*server:\s*([^\s]+)',
        r'WHOIS\s*SERVER:\s*([^\s]+)',
        r'Registrar\s*WHOIS\s*Server:\s*([^\s]+)',
        r'refer:\s*([^\s]+)',
        r'whois:\s*([^\s]+)',
    ]
    for pattern in patterns:
        match = re.search(pattern, response, re.IGNORECASE | re.MULTILINE)
        if match:
            server = match.group(1).strip().lower()
            if server and 'crsnic' not in server:
                return server
    return None


def format_response(raw_response, method, query):
    """Formata a resposta"""
    lines = raw_response.split('\n')
    while lines and lines[0].strip() == '':
        lines.pop(0)
    
    header = f"{'='*60}\n"
    header += f"  Whois Lookup - Resultado\n"
    header += f"  Consulta: {query}\n"
    header += f"  Método: {method}\n"
    header += f"  Data/Hora: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    header += f"  Sistema: {detect_os().upper()} | Python {sys.version.split()[0]}\n"
    header += f"{'='*60}\n"
    
    return header + '\n'.join(lines)


def main():
    print(f"\n{'#'*60}")
    print(f"  Whois Portável v1.2")
    print(f"  Python {sys.version.split()[0]} | {platform.system()} {platform.release()}")
    print(f"{'#'*60}\n")
    
    if len(sys.argv) < 2:
        print("Uso:")
        print(f"  python {sys.argv[0]} <domínio|IP> [opções]")
        print(f"\nExemplos:")
        print(f"  python {sys.argv[0]} mixoliveira.com.br")
        print(f"  python {sys.argv[0]} 8.8.8.8")
        print(f"  python {sys.argv[0]} exemplo.com -v     # Modo verbose")
        print(f"  python {sys.argv[0]} exemplo.com -t 30  # Timeout 30s")
        sys.exit(1)
    
    domain = sys.argv[1]
    timeout = 15
    verbose = False
    
    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg in ('-v', '--verbose'):
            verbose = True
            i += 1
        elif arg in ('-t', '--timeout'):
            if i + 1 < len(sys.argv):
                try:
                    timeout = int(sys.argv[i + 1])
                    i += 2
                except ValueError:
                    print(f"[!] Timeout inválido: {sys.argv[i+1]}")
                    sys.exit(1)
            else:
                print("[!] -t requer um valor numérico (segundos)")
                sys.exit(1)
        else:
            i += 1
    
    try:
        result = whois_lookup(domain, timeout, verbose)
        print(result)
    except KeyboardInterrupt:
        print("\n[!] Operação cancelada.")
        sys.exit(1)
    except Exception as e:
        print(f"[!] Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
