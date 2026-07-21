package FydelisScan::Scanner;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use IO::Socket::INET;
use IO::Select;
use Try::Tiny;
use Time::HiRes qw(time);

requires qw(config logger shutdown);

# ── Scanner de porta individual ────────────────────────
sub scan_port {
    my ($self, $port) = @_;

    return 0 if ${$self->shutdown};

    my $timeout = $self->config->scan_timeout;

    my $sock = IO::Socket::INET->new(
        PeerHost  => $self->config->host,
        PeerPort  => $port,
        Proto     => 'tcp',
        Timeout   => $timeout,
        Blocking  => 0,
    );

    return 0 unless $sock;

    # Non-blocking connect check
    my $sel = IO::Select->new($sock);
    my $result = $sel->can_write($timeout);

    $sock->close();

    return $result ? 1 : 0;
}

# ── Banner grabbing ────────────────────────────────────
sub grab_banner {
    my ($self, $port, $timeout) = @_;
    $timeout //= $self->config->scan_timeout;

    return undef unless $self->config->identify_service;

    my $sock = IO::Socket::INET->new(
        PeerHost  => $self->config->host,
        PeerPort  => $port,
        Proto     => 'tcp',
        Timeout   => $timeout,
    );

    return undef unless $sock;

    $sock->autoflush(1);
    my $sel = IO::Select->new($sock);
    my $banner = '';
    my $max_read = 1024;

    if ($sel->can_read($timeout)) {
        my $chunk;
        my $r = $sock->recv($chunk, $max_read);
        $banner = $chunk if defined $r && $r > 0;
    }

    $sock->close();
    return $banner;
}

# ── Identificar serviço por porta + banner ─────────────
sub identify_service {
    my ($self, $port, $banner) = @_;

    # Primeiro, mapa de portas conhecidas
    my %port_map = (
        21    => 'ftp',
        22    => 'ssh',
        23    => 'telnet',
        25    => 'smtp',
        53    => 'dns',
        80    => 'http',
        110   => 'pop3',
        135   => 'rpc',
        139   => 'netbios',
        143   => 'imap',
        389   => 'ldap',
        443   => 'https',
        445   => 'smb',
        465   => 'smtps',
        512   => 'rexec',
        513   => 'rlogin',
        514   => 'rsh',
        587   => 'submission',
        636   => 'ldaps',
        990   => 'ftps',
        993   => 'imaps',
        995   => 'pop3s',
        1433  => 'mssql',
        1521  => 'oracle',
        2049  => 'nfs',
        3306  => 'mysql',
        3389  => 'rdp',
        5432  => 'postgres',
        5900  => 'vnc',
        5985  => 'winrm-http',
        5986  => 'winrm-https',
        6379  => 'redis',
        8080  => 'http-proxy',
        8443  => 'https-alt',
        11211 => 'memcached',
        27017 => 'mongodb',
    );

    my $service = $port_map{$port} // 'unknown';

    # Se temos banner, tentar identificar melhor
    if (defined $banner && length $banner > 0) {
        my $banner_lc = lc($banner);

        if ($banner_lc =~ /ssh/) {
            $service = 'ssh';
        } elsif ($banner_lc =~ /ftp/) {
            $service = 'ftp';
        } elsif ($banner_lc =~ /smtp|esmtp/) {
            $service = 'smtp';
        } elsif ($banner_lc =~ /pop3/) {
            $service = 'pop3';
        } elsif ($banner_lc =~ /imap/) {
            $service = 'imap';
        } elsif ($banner_lc =~ /mysql/) {
            $service = 'mysql';
        } elsif ($banner_lc =~ /postgresql/) {
            $service = 'postgres';
        } elsif ($banner_lc =~ /http/) {
            $service = (($port == 443 || $port == 8443) ? 'https' : 'http');
        } elsif ($banner_lc =~ /telnet/) {
            $service = 'telnet';
        }
    }

    return $service;
}

# ── Scan de múltiplas portas com pool ──────────────────
sub scan_ports {
    my ($self, $ports_ref) = @_;
    my @ports = $ports_ref->@*;
    my @open_ports;

    $self->logger->info("Iniciando scan de %d porta(s)...", scalar @ports);

    my $count = 0;
    my $total = scalar @ports;
    my $open  = 0;

    for my $port (@ports) {
        last if ${$self->shutdown};
        $count++;

        $self->logger->progress(
            sprintf("  Scan: [%d/%d] %d abertas | verificando porta %d...",
                $count, $total, $open, $port)
        );

        if ($self->scan_port($port)) {
            $open++;

            my $banner  = $self->grab_banner($port);
            my $service = $self->identify_service($port, $banner);

            $self->logger->progress("");  # limpa linha
            $self->logger->info("  ✅ PORTA %-5d ABERTA | %-10s | %s",
                $port, $service,
                defined $banner ? "banner: " . substr($banner, 0, 80) : "(sem banner)"
            );

            push @open_ports, {
                port    => $port,
                service => $service,
                banner  => $banner // '',
            };
        }

        # Pequeno delay para não floodar
        Time::HiRes::usleep(10_000);  # 10ms
    }

    $self->logger->done_progress();

    $self->logger->info("");
    $self->logger->info("Scan concluído: %d/%d portas abertas", $open, $total);

    return \@open_ports;
}

1;