package FydelisBrute::CLI;
use v5.20;
use strict;
use warnings;
use Moo;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Pod::Usage;
use File::Spec;

use FydelisBrute::Config;

# Banner ASCII
sub _banner {
    return <<'BANNER';
╔══════════════════════════════════════════════════════════╗
║              FydelisBrute  v2.0                          ║
║         Credential Testing Framework                     ║
║              FydelisTechos © 2026                        ║
║    Authorized Security Assessment Use Only               ║
╚══════════════════════════════════════════════════════════╝
BANNER
}

sub parse_args {
    my ($self, $argv) = @_;

    my %opts;
    GetOptionsFromArray($$argv, \%opts,
        'h|host=s'            => \$opts{host},
        'p|port=i'            => \$opts{port},
        't|type|protocol=s'   => \$opts{protocol},
        'u|user|username=s'   => \$opts{username},
        'U|userlist=s'        => \$opts{userlist},
        's|pass|password=s'   => \$opts{password},
        'S|passlist=s'        => \$opts{passlist},
        'T|threads=i'         => \$opts{threads},
        'timeout=i'           => \$opts{timeout},
        'continue|no-stop'    => \$opts{continue},
        'o|output=s'          => \$opts{output},
        'l|log=s'             => \$opts{log},
        'v|verbose'           => \$opts{verbose},
        'retry|max-retry=i'   => \$opts{retry},
        'delay=i'             => \$opts{delay},
        'help|?'              => \$opts{help},
        'version'             => \$opts{version},
    ) or pod2usage(2);

    # ── Ajuda / Versão ──────────────────────────────────
    if ($opts{help}) {
        print $self->_banner();
        pod2usage( -verbose => 2, -exitval => 0 );
    }

    if ($opts{version}) {
        print $self->_banner();
        print "Versão: 2.0.0\n";
        exit 0;
    }

    # ── Validação de requisitos ─────────────────────────
    my @errors;

    push @errors, "Host (-h) é obrigatório"          unless $opts{host};
    push @errors, "Porta (-p) é obrigatória"          unless $opts{port};
    push @errors, "Protocolo (-t) é obrigatório"       unless $opts{protocol};

    if ($opts{port} && ($opts{port} < 1 || $opts{port} > 65535)) {
        push @errors, "Porta inválida: $opts{port} (1-65535)";
    }

    my @valid_protos = qw/ftp ftps ssh telnet smtp pop3 imap http https mysql mssql postgres/;
    if ($opts{protocol} && !grep { lc($opts{protocol}) eq $_ } @valid_protos) {
        push @errors, "Protocolo inválido: $opts{protocol}. Válidos: @valid_protos";
    }

    # ── Carregar listas ────────────────────────────────
    my @usernames;
    my @passwords;

    if ($opts{username}) {
        @usernames = ($opts{username});
    } elsif ($opts{userlist}) {
        @usernames = $self->_load_list($opts{userlist});
        push @errors, "Lista de usuários vazia ou não encontrada: $opts{userlist}"
            unless @usernames;
    }

    if ($opts{password}) {
        @passwords = ($opts{password});
    } elsif ($opts{passlist}) {
        @passwords = $self->_load_list($opts{passlist});
        push @errors, "Lista de senhas vazia ou não encontrada: $opts{passlist}"
            unless @passwords;
    }

    # ── Reportar erros ─────────────────────────────────
    if (@errors) {
        print $self->_banner();
        print "\n❌ ERROS DE VALIDAÇÃO:\n";
        print "   $_\n" for @errors;
        print "\nUse --help para ver as opções disponíveis.\n\n";
        return undef;
    }

    # ── Construir Config ───────────────────────────────
    my $config = FydelisBrute::Config->new(
        host           => $opts{host},
        port           => $opts{port},
        protocol       => lc($opts{protocol}),
        usernames      => \@usernames,
        passwords      => \@passwords,
        threads        => $opts{threads}         // 5,
        timeout        => $opts{timeout}         // 10,
        stop_on_first  => !$opts{continue},
        verbose        => $opts{verbose}         // 0,
        (defined $opts{output} ? (output_file => $opts{output}) : ()),
        (defined $opts{log}    ? (logfile      => $opts{log})    : ()),
        max_retries    => $opts{retry}           // 2,
        delay_between  => $opts{delay}           // 0,
    );

    return $config;
}

sub _load_list {
    my ($self, $filepath) = @_;

    return () unless defined $filepath && -f $filepath && -r $filepath;

    open my $fh, '<', $filepath or return ();
    my @lines = <$fh>;
    close $fh;

    chomp @lines;
    @lines = grep { /\S/ } @lines;

    return @lines;
}

1;

__END__

=head1 NAME

fydelisbrute.pl - Credential Testing Framework

=head1 SYNOPSIS

  fydelisbrute.pl [options]

  Required:
    -h, --host HOST          Target IP or hostname
    -p, --port PORT          Target port
    -t, --type PROTOCOL      Protocol: ftp, ssh, telnet, smtp, pop3,
                             imap, http, https, ftps, mysql, mssql, postgres

  Credentials:
    -u, --user USERNAME      Single username
    -U, --userlist FILE      File with usernames (one per line)
    -s, --pass PASSWORD      Single password
    -S, --passlist FILE      File with passwords (one per line)

  Performance:
    -T, --threads N          Concurrent threads (default: 5, max: 50)
    --timeout SEC            Connection timeout per attempt (default: 10)
    --retry N                Max retries per attempt (default: 2)
    --delay MS               Delay between attempts in ms (default: 0)

  Behavior:
    --continue               Don't stop on first valid credential
    -v, --verbose            Verbose output (show all attempts)

  Output:
    -o, --output FILE        Save found credentials to file
    -l, --log FILE           Log file for full session log

  Other:
    --help                   Show this help
    --version                Show version

=head1 DESCRIPTION

FydelisBrute is a professional credential testing framework for
authorized security assessments. It supports multiple protocols
and provides threaded concurrent testing with configurable
timeouts and retry logic.

=head1 EXAMPLES

  # Basic SSH test
  fydelisbrute.pl -h 192.168.1.100 -p 22 -t ssh -u admin -S passwords.txt

  # Full dictionary attack on FTP with 10 threads
  fydelisbrute.pl -h 10.0.0.50 -p 21 -t ftp -U users.txt -S pass.txt -T 10

  # HTTP basic auth, save results
  fydelisbrute.pl -h example.com -p 443 -t https -U users.txt -S pass.txt -o found.txt

=head1 AUTHOR

Adiel Santos Fontes / FydelisTechos

=head1 LICENSE

MIT - For authorized security testing only.

=cut