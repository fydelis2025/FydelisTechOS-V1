package FydelisBrute::Protocols;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use IO::Socket::INET;
use IO::Select;
use Try::Tiny;
use Time::HiRes qw(usleep);

requires qw(config logger);

# ── Retry com exponential backoff ───────────────────────
sub _connect_with_retry {
    my ($self, $host, $port, $timeout) = @_;
    $timeout //= $self->config->timeout;

    my $max_retries = $self->config->max_retries;
    my $attempt     = 0;
    my $sleep       = 100_000;  # 100ms inicial

    while ($attempt <= $max_retries) {
        $attempt++;

        my $sock = IO::Socket::INET->new(
            PeerHost  => $host,
            PeerPort  => $port,
            Proto     => 'tcp',
            Timeout   => $timeout,
            Blocking  => 0,
        );

        if ($sock) {
            # Esperar conexão completar (non-blocking)
            my $sel = IO::Select->new($sock);
            if ($sel->can_write($timeout)) {
                $sock->blocking(1);
                return $sock;
            }
            $sock->close();
        }

        if ($attempt <= $max_retries) {
            my $jitter = int(rand($sleep));
            usleep($sleep + $jitter);
            $sleep *= 2;  # exponential backoff
            $sleep = 5_000_000 if $sleep > 5_000_000;  # cap 5s
        }
    }

    return undef;
}

# ── Banner grab ─────────────────────────────────────────
sub _grab_banner {
    my ($self, $sock, $timeout) = @_;
    $timeout //= 3;

    my $sel = IO::Select->new($sock);
    return '' unless $sel->can_read($timeout);

    my $banner = '';
    my $r;
    while (defined($r = $sock->getc()) && $r ne '') {
        $banner .= $r;
        last unless $sel->can_read(0.1);
    }
    return $banner;
}

# ============================================================
# HANDLERS POR PROTOCOLO
# ============================================================

sub _handle_ftp {
    my ($self, $user, $pass) = @_;

    my $sock = $self->_connect_with_retry(
        $self->config->host, $self->config->port
    ) or return 0;

    my $banner = $self->_grab_banner($sock);

    # USER
    $sock->send("USER $user\r\n");
    my $resp = $self->_read_response($sock);
    return 0 unless defined $resp && $resp =~ /^3\d\d/;

    # PASS
    $sock->send("PASS $pass\r\n");
    $resp = $self->_read_response($sock);

    $sock->close();
    return defined $resp && $resp =~ /^2\d\d/;
}

sub _handle_ssh {
    my ($self, $user, $pass) = @_;

    # Alternativa via Net::SSH::Perl
    try {
        require Net::SSH::Perl;
        my $ssh = Net::SSH::Perl->new(
            $self->config->host,
            Port    => $self->config->port,
            Timeout => $self->config->timeout,
        );
        $ssh->login($user, $pass);
        return 1;
    } catch {
        $self->logger->debug("SSH login failed: $_");
        return 0;
    };
}

sub _handle_http {
    my ($self, $user, $pass) = @_;
    return $self->_handle_http_base($user, $pass, 0);
}

sub _handle_https {
    my ($self, $user, $pass) = @_;
    return $self->_handle_http_base($user, $pass, 1);
}

sub _handle_http_base {
    my ($self, $user, $pass, $ssl) = @_;

    my $scheme  = $ssl ? 'https' : 'http';
    my $uri     = "$scheme://$self->{config}{host}:$self->{config}{port}/";
    my $timeout = $self->config->timeout;

    my $output = `curl -s -o /dev/null -w "%{http_code}" \
        --max-time $timeout \
        --connect-timeout $timeout \
        -u "$user:$pass" \
        "$uri" 2>/dev/null`;

    return defined $output && $output ne '' && $output != 401 && $output != 403;
}

sub _handle_mysql {
    my ($self, $user, $pass) = @_;

    try {
        require DBI;
        require DBD::mysql;
        my $dbh = DBI->connect(
            "DBI:mysql:host=$self->{config}{host};port=$self->{config}{port};mysql_connect_timeout=$self->{config}{timeout}",
            $user, $pass,
            { PrintError => 0, RaiseError => 1 },
        );
        $dbh->disconnect() if $dbh;
        return 1;
    } catch {
        $self->logger->debug("MySQL login failed: $_");
        return 0;
    };
}

sub _read_response {
    my ($self, $sock, $timeout) = @_;
    $timeout //= 3;

    my $sel = IO::Select->new($sock);
    my $buf = '';

    while ($sel->can_read($timeout)) {
        my $chunk;
        my $r = $sock->recv($chunk, 4096);
        last unless defined $r && $r > 0;
        $buf .= $chunk;
        last if $buf =~ /\r?\n$/;
    }

    chomp $buf;
    return $buf;
}

1;