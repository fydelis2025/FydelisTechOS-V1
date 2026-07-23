#ifndef TOOLS_H
#define TOOLS_H

#include <QString>
#include <QMap>
#include <QList>
#include <QStringList>

struct ToolEntry {
    QString packageName;
    QString displayName;
    QString category;
    QString description;
};

class ToolsDatabase {
public:
    static QMap<QString, QList<ToolEntry>> getAllByCategory() {
        QMap<QString, QList<ToolEntry>> cats;

        // ─── Informação / OSINT ─────────────────────────────────
        cats["Coleta de Informações (OSINT)"] = {
            {"nmap",           "Nmap",           "info", "Scanner de portas e descoberta de rede"},
            {"whois",          "Whois",          "info", "Consulta de registros de domínio"},
            {"dnsutils",       "DNS Utils",      "info", "Ferramentas DNS (dig, nslookup, host)"},
            {"recon-ng",       "Recon-ng",       "info", "Framework de reconhecimento web"},
            {"theharvester",   "The Harvester",  "info", "Coleta de e-mails, subdomínios e IPs"},
            {"sherlock",       "Sherlock",       "info", "Busca de usuários em redes sociais"},
            {"sublist3r",      "Sublist3r",      "info", "Enumeração rápida de subdomínios"},
            {"amass",          "Amass",          "info", "Mapeamento de superfície de ataque"},
            {"dnsrecon",       "DNSRecon",       "info", "Enumeração avançada de DNS"},
            {"masscan",        "Masscan",        "info", "Scanner de portas em massa"}
        };

        // ─── Varredura / Enumeração ─────────────────────────────
        cats["Varredura e Enumeração"] = {
            {"nikto",          "Nikto",          "scan", "Scanner de vulnerabilidades web"},
            {"gobuster",       "Gobuster",       "scan", "Fuzzing de diretórios e DNS"},
            {"dirb",           "DIRB",           "scan", "Scanner de diretórios web"},
            {"wfuzz",          "Wfuzz",          "scan", "Fuzzer web para parâmetros"},
            {"enum4linux",     "Enum4linux",     "scan", "Enumeração de Samba/Linux"},
            {"smbclient",      "SMB Client",     "scan", "Cliente SMB para enumeração de shares"},
            {"ldapscripts",    "LDAP Scripts",   "scan", "Scripts de enumeração LDAP"},
            {"snmpcheck",      "SNMP Check",     "scan", "Enumeração SNMP"},
            {"nbtscan",        "NBTScan",        "scan", "Scanner NetBIOS"},
            {"onesixtyone",    "OneSixtyOne",    "scan", "Scanner SNMP com comunidade pública"}
        };

        // ─── Exploração ─────────────────────────────────────────
        cats["Exploração"] = {
            {"metasploit-framework", "Metasploit",        "exploit", "Framework completo de exploração"},
            {"sqlmap",               "SQLMap",            "exploit", "Detecção e exploração de SQL Injection"},
            {"hydra",                "Hydra",             "exploit", "Brute-force de autenticação"},
            {"searchsploit",         "Searchsploit",      "exploit", "Pesquisa local no Exploit-DB"},
            {"exploitdb",            "Exploit-DB",        "exploit", "Banco de exploits local"},
            {"beef-xss",             "BeEF",              "exploit", "Framework de exploração XSS"},
            {"commix",               "Commix",            "exploit", "Teste de injeção de comandos"},
            {"crackmapexec",         "CrackMapExec",      "exploit", "Pós-exploração de redes Windows"},
            {"impacket-scripts",     "Impacket Scripts",  "exploit", "Coleção de scripts para protocolos Windows"},
            {"responder",            "Responder",         "exploit", "Envenenamento LLMNR/NBT-NS/MDNS"}
        };

        // ─── Senhas / Cracking ──────────────────────────────────
        cats["Cracking e Senhas"] = {
            {"john",             "John the Ripper",   "crack", "Quebrador de hashes offline"},
            {"hashcat",          "Hashcat",           "crack", "Quebrador de hashes via GPU"},
            {"hash-identifier",  "Hash Identifier",   "crack", "Identificação de tipos de hash"},
            {"hydra",            "Hydra (senhas)",    "crack", "Ataque de força bruta online"},
            {"medusa",           "Medusa",            "crack", "Brute-force paralelo massivo"},
            {"cewl",             "CeWL",              "crack", "Gerador de wordlists personalizadas"},
            {"crunch",           "Crunch",            "crack", "Gerador de wordlists"},
            {"seclists",         "SecLists",          "crack", "Coleção massiva de wordlists"},
            {"rsmangler",        "RSMangler",         "crack", "Mangling de wordlists"},
            {"pdfcrack",         "PDF Crack",         "crack", "Recuperação de senhas PDF"}
        };

        // ─── Wireless ───────────────────────────────────────────
        cats["Wireless e RF"] = {
            {"aircrack-ng",      "Aircrack-ng",       "wireless", "Suite de auditoria WiFi"},
            {"wifite",           "Wifite",            "wireless", "Script automatizado de cracking WiFi"},
            {"kismet",           "Kismet",            "wireless", "Detector de redes wireless"},
            {"reaver",           "Reaver",            "wireless", "Ataque WPS PIN"},
            {"bully",            "Bully",             "wireless", "Implementação WPS bruteforce"},
            {"mdk4",             "MDK4",              "wireless", "Teste de stress WiFi"},
            {"bettercap",        "Bettercap",         "wireless", "Framework MITM e monitoramento"},
            {"hcxdumptool",      "Hcxdumptool",       "wireless", "Captura de hashes PMKID/WPA"},
            {"hackrf",           "HackRF Tools",      "wireless", "Ferramentas SDR para HackRF"},
            {"gnuradio",         "GNU Radio",         "wireless", "Plataforma de processamento SDR"}
        };

        // ─── Web ────────────────────────────────────────────────
        cats["Segurança Web"] = {
            {"burpsuite",        "Burp Suite",        "web", "Proxy de interceptação web"},
            {"zaproxy",          "ZAP Proxy",         "web", "Scanner de segurança web OWASP"},
            {"ffuf",             "FFUF",              "web", "Fuzzer rápido de diretórios web"},
            {"dirsearch",        "Dirsearch",         "web", "Scanner de diretórios web"},
            {"wpscan",           "WPScan",            "web", "Scanner de vulnerabilidades WordPress"},
            {"whatweb",          "WhatWeb",           "web", "Identificação de tecnologias web"},
            {"wapiti",           "Wapiti",            "web", "Scanner de vulnerabilidades web"},
            {"xsstrike",         "XSS Strike",        "web", "Detector e exploração XSS"},
            {"jwt_tool",         "JWT Tool",          "web", "Teste de tokens JWT"},
            {"gospider",         "GoSpider",          "web", "Spidering rápido em Go"}
        };

        // ─── Engenharia Social ──────────────────────────────────
        cats["Engenharia Social"] = {
            {"setoolkit",        "SET",               "social", "Social Engineering Toolkit"},
            {"king-phisher",     "King Phisher",      "social", "Simulação de phishing"},
            {"gophish",          "GoPhish",           "social", "Framework de phishing open source"},
            {"evilginx2",        "Evilginx2",         "social", "Framework de phishing com proxy reverso"},
            {"socialfish",       "SocialFish",        "social", "Ferramenta educacional de phishing"},
            {"hiddeneye",        "HiddenEye",         "social", "Phishing com páginas clonadas"}
        };

        // ─── Pós-Exploração ─────────────────────────────────────
        cats["Pós-Exploração e Persistência"] = {
            {"powershell-empire", "Empire",           "post", "Framework pós-exploração PowerShell"},
            {"bloodhound",       "BloodHound",        "post", "Mapeamento de relações AD"},
            {"chisel",           "Chisel",            "post", "Túnel TCP/UDP rápido"},
            {"ligolo-ng",        "Ligolo-ng",         "post", "Túnel de rede reverso"},
            {"mimikatz",         "Mimikatz",          "post", "Extração de credenciais do LSASS"},
            {"mimikatz",         "Mimikatz",          "post", "Extração de credenciais do LSASS (já incluso)"},
            {"p0f",              "p0f",               "post", "Impressão digital passiva de SO"},
            {"netcat-traditional", "Netcat",          "post", "Swiss army knife de redes"}
        };

        // ─── Relatórios ─────────────────────────────────────────
        cats["Relatórios e Documentação"] = {
            {"exiftool",         "ExifTool",          "report", "Leitura de metadados de arquivos"},
            {"dradis",           "Dradis",            "report", "Framework de colaboração para relatórios"},
            {"cherrytree",       "CherryTree",        "report", "Editor de notas hierárquico"},
            {"pandoc",           "Pandoc",            "report", "Conversor universal de documentos"},
            {"texlive-latex-base", "LaTeX Base",      "report", "Sistema de preparação de documentos"}
        };

        return cats;
    }

    // Total de ferramentas
    static int totalTools() {
        auto cats = getAllByCategory();
        int total = 0;
        for (auto it = cats.begin(); it != cats.end(); ++it)
            total += it.value().size();
        return total;
    }

    // Lista plana com todos os nomes de pacotes
    static QStringList allPackageNames() {
        QStringList pkgs;
        auto cats = getAllByCategory();
        for (auto it = cats.begin(); it != cats.end(); ++it)
            for (const auto &t : it.value())
                pkgs << t.packageName;
        return pkgs;
    }

    // Categorias disponíveis
    static QStringList categories() {
        QStringList cats;
        auto all = getAllByCategory();
        for (auto it = all.begin(); it != all.end(); ++it)
            cats << it.key();
        return cats;
    }
};

#endif // TOOLS_H