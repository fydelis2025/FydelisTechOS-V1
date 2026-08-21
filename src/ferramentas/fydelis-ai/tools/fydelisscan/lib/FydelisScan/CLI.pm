package FydelisScan::CLI;
use v5.20;
use strict;
use warnings;
use Moo;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Pod::Usage;

use FydelisScan::Config;

sub parse_args {
    my ($self, $argv) = @_;

    my %opts;
    GetOptionsFromArray($$argv, \%opts,
        'h|host=s'            => \$opts{host},
        'p|port=i'            => \$opts{port},
        'P|portlist=s'        => \$opts{portlist},
        'u|user|username=s'   => \$opts{username},
        'U|userlist=s'        => \$opts{userlist},
        's|pass|password=s'   => \$opts{password},
        'S|passlist=s'        => \$opts{passlist},
        'T|threads=i'         => \$opts{threads},
        'scan-timeout=i'      => \$opts{scan_timeout},
        'brute-timeout=i'     => \$opts{brute_timeout},
        'o|output=s'          => \$opts{output},
        'l|log=s'             => \$opts{log},
        'v|verbose'           => \$opts{verbose},
        'retry|max-retry=i'   => \$opts{retry},
        'no-identify'         => \$opts{no_identify},
        'help|?'              => \$opts{help},
        'version'             => \$opts{version},
    ) or pod2usage(2);

    # ── Help / Version ─────────────────────────────────
    if ($opts{help}) {
        $self->_banner();
        pod2usage(-verbose => 2, -exitval => 0);
    }

    if ($opts{version}) {
        $self->_banner();
        print "Versão: 2.0.0\n";
        exit 0;
    }

    # ── Validação ──────────────────────────────────────
    my @errors;
    push @errors, "Host (-h) é obrigatório" unless $opts{host};

    # Carregar portas
    my @ports;
    if ($opts{port}) {
        @ports = ($opts{port});
    } elsif ($opts{portlist}) {
        @ports = $self->_load_int_list($opts{portlist});
        push @errors, "Lista de portas vazia ou inválida: $opts{portlist}" unless @ports;
    } else {
        # Portas padrão de serviços comuns
        @ports = qw/21 22 23 25 80 110 143 443 990 1433 3306 5432 8080 8443/;
    }

    # Carregar credenciais
    my @usernames;
    my @passwords;

    if ($opts{username}) {
        @usernames = ($opts{username});
    } elsif ($opts{userlist}) {
        @usernames = $self->_load_list($opts{userlist});
        push @errors, "Lista de usuários vazia: $opts{userlist}" unless @usernames;
    }

    if ($opts{password}) {
        @passwords = ($opts{password});
    } elsif ($opts{passlist}) {
        @passwords = $self->_load_list($opts{passlist});
        push @errors, "Lista de senhas vazia: $opts{passlist}" unless @passwords;
    }

    # Se tem senha, precisa ter usuário (e vice-versa)
    if (@passwords && !@usernames) {
        push @errors, "Forneça usuários (-u ou -U) junto com as senhas";
    }
    if (@usernames && !@passwords) {
        push @errors, "Forneça senhas (-s ou -S) junto com os usuários";
    }

    if (@errors) {
        $self->_banner();
        print "\n❌ ERROS DE VALIDAÇÃO:\n";
        print "   $_\n" for @errors;
        print "\nUse --help para ver as opções.\n\n";
        return undef;
    }

    my $config = FydelisScan::Config->new(
        host            => $opts{host},
        ports           => \@ports,
        usernames       => \@usernames,
        passwords       => \@passwords,
        threads         => $opts{threads}        // 10,
        scan_timeout    => $opts{scan_timeout}   // 3,
        brute_timeout   => $opts{brute_timeout}  // 8,
        verbose         => $opts{verbose}        // 0,
        (defined $opts{output}      ? (output_file  => $opts{output})      : ()),
        (defined $opts{log}         ? (logfile      => $opts{log})          : ()),
        max_retries     => $opts{retry}          // 1,
        identify_service => !$opts{no_identify},
    );

    return $config;
}

sub _banner {
    print <<'BANNER';
╔══════════════════════════════════════════════════════════╗
║              FydelisScan  v2.0                           ║
║      Service Scanner + Credential Testing Framework      ║
║              FydelisTechos © 2026                        ║
║    Authorized Security Assessment Use Only               ║
╚══════════════════════════════════════════════════════════╝
BANNER
}

sub _load_list {
    my ($self, $file) = @_;
    return () unless defined $file && -f $file && -r $file;
    open my $fh, '<', $file or return ();
    chomp(my @lines = <$fh>);
    close $fh;
    return grep { /\S/ } @lines;
}

sub _load_int_list {
    my ($self, $file) = @_;
    my @lines = $self->_load_list($file);
    my @ints;
    for my $line (@lines) {
        # Suporta ranges: 20-25,80,443
        if ($line =~ /^(\d+)\s*-\s*(\d+)$/) {
            push @ints, ($1..$2);
        } elsif ($line =~ /^\d+$/) {
            push @ints, $line;
        }
    }
    return @ints;
}

1;

__END__

=head1 NAME

fydelisscan.pl - Service Scanner + Credential Testing Framework

=head1 SYNOPSIS

  fydelisscan.pl -h HOST [options]

  Required:
    -h, --host HOST       Target IP or hostname

  Ports:
    -p, --port PORT       Single port to scan
    -P, --portlist FILE   File with port list (one per line, supports ranges)

  Credentials (optional - if omitted, only port scan is performed):
    -u, --user USER       Single username
    -U, --userlist FILE   File with usernames
    -s, --pass PASSWORD   Single password
    -S, --passlist FILE   File with passwords

  Performance:
    -T, --threads N         Concurrent threads (default: 10, max: 50)
    --scan-timeout SEC      Port scan timeout (default: 3)
    --brute-timeout SEC     Credential test timeout (default: 8)
    --retry N               Max retries on failed connection (default: 1)

  Output:
    -o, --output FILE     Save found credentials to file
    -l, --log FILE        Log file
    -v, --verbose         Verbose output

  Other:
    --no-identify         Skip service identification via banner
    --help                This help
    --version             Version

=head1 DESCRIPTION

FydelisScan performs multi-port service scanning followed by
credential testing on open ports. It supports service identification
via banner grabbing and automatic protocol matching.

=head1 EXAMPLES

  # Port scan only
  fydelisscan.pl -h 192.168.1.100 -p 22,80,443

  # Scan + brute force on found services
  fydelisscan.pl -h 10.0.0.50 -U users.txt -S pass.txt -T 20

  # Custom ports + save results
  fydelisscan.pl -h target.com -P myports.txt -U users.txt -S pass.txt -o found.txt -v

=cut