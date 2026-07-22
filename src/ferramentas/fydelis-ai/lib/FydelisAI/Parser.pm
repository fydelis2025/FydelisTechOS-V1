package FydelisAI::Parser;
use v5.20;
use strict;
use warnings;
use Moo;
use Try::Tiny;

has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );

# ============================================================
# NMAP
# ============================================================
sub parse_nmap {
    my ($self, $input) = @_;

    my $data = {
        host      => '',
        status    => '',
        ports     => [],
        os        => '',
        uptime    => '',
    };

    my $content = $self->_get_content($input);
    return $data unless defined $content;

    if ($content =~ /Nmap scan report for\s+(\S+)\s+\(?(\S+)?/) {
        $data->{host} = $1;
    }

    if ($content =~ /Host is up.*?\((\d+\.\d+s)\)/) {
        $data->{uptime} = $1;
    }

    while ($content =~ m#^(\d+)/(tcp|udp)\s+(open|filtered|closed)\s+(\S+)\s*(.*)$#gm) {
        push @{$data->{ports}}, {
            port     => $1,
            protocol => $2,
            state    => $3,
            service  => $4,
            version  => $5 || '',
        };
    }

    if ($content =~ /OS details:\s*(.+)/) {
        $data->{os} = $1;
    } elsif ($content =~ /Aggressive OS guesses:\s*(.+)/) {
        $data->{os} = $1;
    }

    return $data;
}

# ============================================================
# GOBUSTER / DIRB / DIRSEARCH
# ============================================================
sub parse_web_dirs {
    my ($self, $input) = @_;

    my @results;
    my $content = $self->_get_content($input);
    return \@results unless defined $content;

    while ($content =~ m#^/(\S+)\s+\(Status:\s*(\d+)\)\s+\[Size:\s*(\d+)\]$#gm) {
        push @results, { path => "/$1", status => $2, size => $3 };
    }

    while ($content =~ m#==>\s+(?:DIRECTORY|FILE):\s+(\S+)$#gm) {
        push @results, { path => $1, status => 200, size => 0 };
    }

    while ($content =~ m#^(\d{3})\s+.*?http.*?(\/.*)$#gm) {
        push @results, { path => $2, status => $1, size => 0 };
    }

    return \@results;
}

# ============================================================
# HYDRA / MEDUSA
# ============================================================
sub parse_hydra {
    my ($self, $input) = @_;

    my @credentials;
    my $content = $self->_get_content($input);
    return \@credentials unless defined $content;

    while ($content =~ m#\[(\d+)\]\[(\w+)\]\s+\S+:\s+(\S+)\s+login:\s+(\S+)\s+password:\s+(\S+)#gm) {
        push @credentials, {
            port     => $1,
            service  => $2,
            host     => $3,
            username => $4,
            password => $5,
        };
    }

    while ($content =~ m#\[(\w+)\]\s+host:(\S+)\s+user:(\S+)\s+pass:(\S+)#gm) {
        push @credentials, {
            port     => 0,
            service  => $1,
            host     => $2,
            username => $3,
            password => $4,
        };
    }

    return \@credentials;
}

# ============================================================
# SQLMAP
# ============================================================
sub parse_sqlmap {
    my ($self, $input) = @_;

    my $data = {
        vulnerable_params => [],
        technique         => '',
        dbms              => '',
        payloads          => [],
    };

    my $content = $self->_get_content($input);
    return $data unless defined $content;

    while ($content =~ m#(GET|POST)\s+parameter\s+'(\w+)'\s+is\s+vulnerable#gm) {
        push @{$data->{vulnerable_params}}, { method => $1, param => $2 };
    }

    if ($content =~ /Technique:\s*(\S+)/) { $data->{technique} = $1 }
    if ($content =~ /DBMS:\s*(.+)/)       { $data->{dbms} = $1 }

    while ($content =~ m#Payload:\s*(.+)$#gm) {
        push @{$data->{payloads}}, $1;
    }

    return $data;
}

# ============================================================
# NIKTO
# ============================================================
sub parse_nikto {
    my ($self, $input) = @_;

    my @vulnerabilities;
    my $content = $self->_get_content($input);
    return \@vulnerabilities unless defined $content;

    while ($content =~ m#^\+\s+(/\S+):\s*(.*)$#gm) {
        push @vulnerabilities, { path => $1, description => $2, severity => 'info' };
    }

    while ($content =~ m#^\+\s+(OSVDB-\d+):\s+(/\S+):\s*(.*)$#gm) {
        push @vulnerabilities, { id => $1, path => $2, description => $3, severity => 'medium' };
    }

    while ($content =~ m#^\+\s+(/\S+):\s*(.*?)\s*\(?(CVE-\d+-\d+)?\)?$#gm) {
        push @vulnerabilities, {
            path => $1, description => $2, cve => $3 || '', severity => 'high'
        };
    }

    return \@vulnerabilities;
}

# ============================================================
# CURL (HTTP response)
# ============================================================
sub parse_curl_response {
    my ($self, $input) = @_;

    my $data = {
        status    => 0,
        headers   => {},
        body      => '',
        body_size => 0,
        cookies   => {},
        redirect  => '',
    };

    my $content = $self->_get_content($input);
    return $data unless defined $content;

    if ($content =~ m#^HTTP/\d\.\d\s+(\d+)#m) { $data->{status} = $1 }

    while ($content =~ m#^([\w-]+):\s*(.*)$#gm) {
        $data->{headers}->{lc($1)} = $2;
    }

    while ($content =~ m#^Set-Cookie:\s*(\w+)=([^;]+)#gm) {
        $data->{cookies}->{$1} = $2;
    }

    if ($content =~ m#^Location:\s*(.*)$#m) { $data->{redirect} = $1 }

    if ($content =~ m#\r?\n\r?\n(.*)$#s) {
        $data->{body}      = $1;
        $data->{body_size} = length($1);
    }

    return $data;
}

# ============================================================
# WPSCAN
# ============================================================
sub parse_wpscan {
    my ($self, $input) = @_;

    my $data = {
        url                => '',
        wordpress_version  => '',
        wordpress_theme    => '',
        plugins            => [],
        themes             => [],
        users              => [],
        vulnerabilities    => [],
        timthumbs          => [],
        interesting_files  => [],
    };

    my $content = $self->_get_content($input);
    return $data unless defined $content;

    # URL
    if ($content =~ m#^\[?\]?\s*Site URL:\s*(\S+)#m) {
        $data->{url} = $1;
    }

    # Versão
    if ($content =~ m#WordPress\s+(?:Core|version)\s+(\d+\.\d+(?:\.\d+)?)#im) {
        $data->{wordpress_version} = $1;
    } elsif ($content =~ m#WordPress\s+(?:version\s+)?(\d+\.\d+(?:\.\d+)?)#im) {
        $data->{wordpress_version} = $1;
    }

    # Tema
    if ($content =~ m#Theme:\s*(.+)#im) {
        $data->{wordpress_theme} = $1;
    }

    # Plugins (vários formatos)
    while ($content =~ m#\[\+\]\s*Plugin:\s*(\S+)\s*\[(.*?)\]#gm) {
        push @{$data->{plugins}}, { name => $1, status => $2 };
    }
    while ($content =~ m#\[\+\]\s*Plugin\(s\):\s*(.+)$#im) {
        my @plugs = split(/,\s*/, $1);
        for my $p (@plugs) {
            $p =~ s/^\s+|\s+$//g;
            push @{$data->{plugins}}, { name => $p } if $p;
        }
    }

    # Temas
    while ($content =~ m#\[\+\]\s*Theme:\s*(\S+)\s*\[(.*?)\]#gm) {
        push @{$data->{themes}}, { name => $1, status => $2 };
    }

    # Usuários
    while ($content =~ m#^\|\s*(\S+)\s*\|.*user#gim) {
        push @{$data->{users}}, { username => $1 };
    }
    while ($content =~ m#\[\+\]\s*User\(s\):\s*(.+)$#im) {
        my @usrs = split(/,\s*/, $1);
        for my $u (@usrs) {
            $u =~ s/^\s+|\s+$//g;
            push @{$data->{users}}, { username => $u } if $u;
        }
    }
    while ($content =~ m#\[\+\]\s*User:\s*(\S+)#gm) {
        push @{$data->{users}}, { username => $1 };
    }

    # Vulnerabilidades
    while ($content =~ m#\[\+\]\s*(.*?)\s*(?:CVE-(\d+-\d+)|$)#gm) {
        my $desc = $1;
        my $cve  = $2 ? "CVE-$2" : '';
        next if $desc =~ /^(Plugin|Theme|User|WordPress)/i;
        push @{$data->{vulnerabilities}}, {
            description => $desc,
            cve         => $cve,
            severity    => 'high',
        };
    }

    return $data;
}

# ============================================================
# OPENVAS
# ============================================================
sub parse_openvas {
    my ($self, $input) = @_;

    my $data = {
        scan_start    => '',
        scan_end      => '',
        target        => '',
        total_results => 0,
        results       => [],
        summary       => {},
    };

    my $content = $self->_get_content($input);
    return $data unless defined $content;

    # Formato XML
    if ($content =~ /<report_id>/ || $content =~ /<report\s+id=/) {
        return $self->_parse_openvas_xml($content);
    }

    # Formato texto
    my @results;
    while ($content =~ m#^\[?(HIGH|MEDIUM|LOW|CRITICAL|INFO)\]\s*(?:\[(\d+/\w+)\])?\s*(.*)$#gm) {
        push @results, {
            severity    => $1,
            port        => $2 || '',
            description => $3,
        };
    }

    $data->{results} = \@results;
    $data->{total_results} = scalar @results;

    # Sumário
    if ($content =~ /High:\s*(\d+)/i)   { $data->{summary}->{high}     = $1 }
    if ($content =~ /Medium:\s*(\d+)/i) { $data->{summary}->{medium}   = $1 }
    if ($content =~ /Low:\s*(\d+)/i)    { $data->{summary}->{low}      = $1 }
    if ($content =~ /Critical:\s*(\d+)/i) { $data->{summary}->{critical} = $1 }

    return $data;
}

sub _parse_openvas_xml {
    my ($self, $content) = @_;

    my $data = { format => 'xml', results => [], summary => {} };

    while ($content =~ m#<result>(.*?)</result>#gs) {
        my $r = $1;
        my $result = {};

        if ($r =~ m#<name>(.*?)</name>#s)        { $result->{name} = $1 }
        if ($r =~ m#<description>(.*?)</description>#s) { $result->{description} = $1 }
        if ($r =~ m#<threat>(.*?)</threat>#s)     { $result->{severity} = uc($1) }
        if ($r =~ m#<port>(.*?)</port>#s)         { $result->{port} = $1 }
        if ($r =~ m#<cvss_base>(.*?)</cvss_base>#s) { $result->{cvss} = $1 }
        if ($r =~ m#<solution>(.*?)</solution>#s) { $result->{solution} = $1 }

        push @{$data->{results}}, $result;
    }

    $data->{total_results} = scalar @{$data->{results}};

    my %severity_count;
    for my $r (@{$data->{results}}) {
        my $sev = lc($r->{severity} // 'info');
        $severity_count{$sev}++;
    }
    $data->{summary} = \%severity_count;

    return $data;
}

# ============================================================
# METASPLOIT
# ============================================================
sub parse_metasploit {
    my ($self, $input) = @_;

    my $data = {
        sessions       => [],
        jobs           => [],
        modules_loaded => 0,
        exploits_run   => [],
        loot           => [],
        credentials    => [],
        targets        => [],
        services       => [],
        vulns          => [],
    };

    my $content = $self->_get_content($input);
    return $data unless defined $content;

    # Sessions
    while ($content =~ m#Session\s+(\d+)\s+opened\s+\((\S+)\s+->\s+(\S+)\)#gm) {
        push @{$data->{sessions}}, {
            id      => $1,
            type    => 'meterpreter',
            lhost   => (split(/:/, $2))[0],
            lport   => (split(/:/, $2))[1],
            rhost   => (split(/:/, $3))[0],
            rport   => (split(/:/, $3))[1],
            state   => 'opened',
        };
    }

    # Sessions table format
    while ($content =~ m#^(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+?)\s+(\S+://\S+)\s*$#gm) {
        push @{$data->{sessions}}, {
            id        => $1,
            type      => $2,
            transport => $3,
            state     => $4,
            info      => $5,
            uri       => $6,
        };
    }

    # Módulos carregados
    while ($content =~ m#msf\s*\d*\s*(exploit|auxiliary|post|payload)\((\S+)\)\s*>#gm) {
        $data->{modules_loaded}++;
    }

    # Credenciais (hashdump format)
    while ($content =~ m#^(\S+):(\S+:\S+:\S+:\S+:\S+:\S+)#gm) {
        push @{$data->{credentials}}, {
            username => $1,
            hash     => $2,
            type     => 'ntlm',
        };
    }

    # Credenciais (found format)
    while ($content =~ m#Found credential:\s*(\S+):(\S+)#gim) {
        push @{$data->{credentials}}, {
            username => $1,
            password => $2,
            type     => 'plaintext',
        };
    }

    # Loot
    while ($content =~ m#Loot:\s*(.*)$#gm) {
        my $loot_line = $1;
        if ($loot_line =~ /(\S+)\s*$/) {
            push @{$data->{loot}}, { path => $1 };
        }
    }

    # Targets (RHOSTS)
    while ($content =~ m#RHOSTS?\s*=>?\s*(\S+)#gm) {
        push @{$data->{targets}}, { rhost => $1 };
    }

    # CVEs mentioned
    while ($content =~ m#(CVE-\d+-\d+)#g) {
        push @{$data->{vulns}}, { cve => $1 };
    }

    # Exploits
    while ($content =~ m#\[\*\].*?exploit.*?(\S+)#gim) {
        push @{$data->{exploits_run}}, { module => $1, status => 'started' };
    }

    return $data;
}

# ============================================================
# AUTO-DETECT
# ============================================================
sub parse_auto {
    my ($self, $input) = @_;

    my $content = $self->_get_content($input);
    return { type => 'unknown', data => $content } unless defined $content;

    return { type => 'nmap',       data => $self->parse_nmap($content) }
        if $content =~ /Nmap\s+\d+\.\d+/;

    return { type => 'wpscan',     data => $self->parse_wpscan($content) }
        if $content =~ /WordPress|WPScan/i && $content =~ /Site URL|plugins|themes/i;

    return { type => 'openvas',    data => $self->parse_openvas($content) }
        if $content =~ /OpenVAS|GVM|Greenbone|NVT Name|report_id=/i;

    return { type => 'metasploit', data => $self->parse_metasploit($content) }
        if $content =~ /msf\s*\d*\s*(exploit|auxiliary|post)\s*\(/ || $content =~ /Session\s+\d+\s+opened/;

    return { type => 'web_dirs',   data => $self->parse_web_dirs($content) }
        if $content =~ /\(Status:\s*\d+\)/;

    return { type => 'hydra',      data => $self->parse_hydra($content) }
        if $content =~ /login:\s+\S+\s+password:\s+\S+/;

    return { type => 'nikto',      data => $self->parse_nikto($content) }
        if $content =~ /^\+.*OSVDB-/m || $content =~ /^\+ \//m;

    return { type => 'sqlmap',     data => $self->parse_sqlmap($content) }
        if $content =~ /parameter.*is vulnerable/i;

    return { type => 'http',       data => $self->parse_curl_response($content) }
        if $content =~ /^HTTP\/\d\.\d\s+\d+/m;

    return { type => 'unknown', data => $content };
}

# ============================================================
# HELPERS
# ============================================================

sub _get_content {
    my ($self, $input) = @_;

    return undef unless defined $input;

    if (-f $input) {
        eval {
            open my $fh, '<', $input or die;
            local $/;
            my $content = <$fh>;
            close $fh;
            return $content;
        };
        if ($@) {
            $self->logger->warn("Erro ao ler arquivo %s: %s", $input, $@);
            return undef;
        }
    }

    return $input;
}

sub sanitize_command {
    my ($self, $cmd) = @_;

    return undef unless defined $cmd;

    $cmd =~ s/^\s+|\s+$//g;
    $cmd =~ s/[\r\n]+/ /g;
    $cmd =~ s/\s+/ /g;

    return $cmd;
}

1;