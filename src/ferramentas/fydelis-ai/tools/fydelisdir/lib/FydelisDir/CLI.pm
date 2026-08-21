package FydelisDir::CLI;
use v5.20;
use strict;
use warnings;
use Moo;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Pod::Usage;

use FydelisDir::Config;

sub parse_args {
    my ($self, $argv) = @_;

    my %opts;
    GetOptionsFromArray($$argv, \%opts,
        'h|host|url=s'            => \$opts{host},
        'p|port=i'                => \$opts{port},
        's|ssl|https'             => \$opts{ssl},
        'b|base-path=s'           => \$opts{base_path},

        'w|wordlist=s'            => \$opts{wordlist},
        'e|extensions=s'          => \$opts{extensions},
        'x|exclude-ext'           => \$opts{exclude_ext},

        'T|threads=i'             => \$opts{threads},
        'd|delay=i'               => \$opts{delay_ms},
        't|timeout=i'             => \$opts{timeout},

        'sc|status-codes=s'       => \$opts{status_codes},
        'min-size=i'              => \$opts{min_size},
        'exclude-text=s'          => \$opts{exclude_text},

        'u|username=s'            => \$opts{username},
        'P|password=s'            => \$opts{password},

        'r|recursion=i'           => \$opts{recursion},
        'no-redirect'             => \$opts{no_redirect},
        'rotate-ua'               => \$opts{rotate_ua},

        'o|output=s'              => \$opts{output},
        'l|log=s'                 => \$opts{log},
        'v|verbose'               => \$opts{verbose},
        'q|quiet'                 => \$opts{quiet},
        'help|?'                  => \$opts{help},
        'version'                 => \$opts{version},
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

    # ── Validar host ───────────────────────────────────
    unless ($opts{host}) {
        $self->_banner();
        print "\n❌ Host (-h) é obrigatório.\n";
        print "Use --help para ajuda completa.\n\n";
        return undef;
    }

    # Limpar URL se necessário
    my $host = $opts{host};
    $host =~ s{^https?://}{};
    $host =~ s{/.*$}{};

    # ── Carregar wordlist ─────────────────────────────
    my @wordlist;
    if ($opts{wordlist}) {
        @wordlist = $self->_load_list($opts{wordlist});
        unless (@wordlist) {
            print "\n❌ Wordlist vazia ou não encontrada: $opts{wordlist}\n\n";
            return undef;
        }
    } else {
        # Wordlist padrão embutida (comum)
        @wordlist = $self->_default_wordlist();
    }

    # ── Extensões ──────────────────────────────────────
    my @extensions = ('');
    if ($opts{extensions} && !$opts{exclude_ext}) {
        push @extensions, split(/[,;:\s]+/, $opts{extensions});
    } elsif (!$opts{exclude_ext}) {
        push @extensions, qw(php html htm asp aspx jsp txt bak old inc conf xml json);
    }

    # ── Status codes ───────────────────────────────────
    my @status_codes;
    if ($opts{status_codes}) {
        @status_codes = split(/[,;:\s]+/, $opts{status_codes});
        @status_codes = grep { /^\d+$/ } @status_codes;
    } else {
        @status_codes = qw(200 201 204 301 302 307 401 403 405 500);
    }

    # ── SSL automático por porta ──────────────────────
    if (!defined $opts{ssl} && $opts{port}) {
        $opts{ssl} = 1 if $opts{port} == 443 || $opts{port} == 8443;
    }

    my $config = FydelisDir::Config->new(
        host               => $host,
        port               => $opts{port}        // 80,
        ssl                => $opts{ssl}         // 0,
        base_path          => $opts{base_path}   // '/',
        wordlist           => \@wordlist,
        extensions         => \@extensions,
        threads            => $opts{threads}     // 10,
        delay_ms           => $opts{delay_ms}    // 0,
        request_timeout    => $opts{timeout}     // 10,
        valid_status_codes => \@status_codes,
        min_response_size  => $opts{min_size}    // 0,
        exclude_text       => $opts{exclude_text},
        (defined $opts{username} ? (username => $opts{username}) : ()),
        (defined $opts{password} ? (password => $opts{password}) : ()),
        follow_redirects   => !$opts{no_redirect},
        recursion_depth    => $opts{recursion}   // 0,
        rotate_agents      => $opts{rotate_ua}   // 0,
        (defined $opts{output} ? (output_file => $opts{output}) : ()),
        (defined $opts{log}    ? (logfile     => $opts{log})    : ()),
        verbose            => $opts{verbose}     // 0,
        quiet              => $opts{quiet}       // 0,
    );

    return $config;
}

sub _banner {
    print <<'BANNER';
╔══════════════════════════════════════════════════════════╗
║             FydelisDir  v2.0                              ║
║        HTTP/HTTPS Path Enumeration Framework              ║
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
    return grep { /\S/ && !/^#/ } @lines;
}

sub _default_wordlist {
    return qw(
        admin backup blog cgi-bin config css data db
        dev downloads error favicon.ico fonts
        includes img images index install js
        login logout media mysql old panel
        phpmyadmin private public restore robots.txt
        sitemap.xml sql src static status test
        tmp uploads vendor webadmin www xml
    );
}

1;

__END__

=head1 NAME

fydelisdir.pl - HTTP/HTTPS Path Enumeration Framework

=head1 SYNOPSIS

  fydelisdir.pl -h TARGET [options]

  Required:
    -h, --host HOST        Target hostname or IP

  Connection:
    -p, --port PORT        Port (default: 80)
    -s, --ssl              Use HTTPS
    -b, --base-path PATH   Base path (default: /)

  Wordlist:
    -w, --wordlist FILE    Path wordlist (one per line)
    -e, --extensions EXT   File extensions (e.g., php,txt,html,bak)
    -x, --exclude-ext      Disable automatic extension appending

  Performance:
    -T, --threads N        Concurrent requests (default: 10, max: 50)
    -d, --delay MS         Delay between requests in ms (default: 0)
    -t, --timeout SEC      Request timeout (default: 10)

  Filtering:
    --sc, --status-codes   Valid status codes (default: 200,301,302,403,401,500)
    --min-size BYTES       Minimum response body size
    --exclude-text TEXT     Text in body that indicates "not found"

  Auth:
    -u, --username USER    HTTP basic auth username
    -P, --password PASS    HTTP basic auth password

  Behavior:
    -r, --recursion N      Directory recursion depth (default: 0)
    --no-redirect          Don't follow redirects
    --rotate-ua            Rotate User-Agent headers

  Output:
    -o, --output FILE      Save findings to file
    -l, --log FILE         Log file
    -v, --verbose          Verbose output (all requests)
    -q, --quiet            Only show found items

  Other:
    --help                 This help
    --version              Version

=head1 DESCRIPTION

FydelisDir performs HTTP/HTTPS path enumeration for authorized
security assessments. It supports multi-threaded scanning with
intelligent filtering to reduce false positives, automatic
extension probing, and directory recursion.

=head1 EXAMPLES

  # Basic scan
  fydelisdir.pl -h example.com

  # HTTPS with custom wordlist and extensions
  fydelisdir.pl -h target.com -s -w mylist.txt -e php,html,bak -T 20

  # Filter by status codes and min size
  fydelisdir.pl -h 10.0.0.1 --sc "200,403" --min-size 100 --exclude-text "not found"

  # Authenticated scan with recursion
  fydelisdir.pl -h admin.example.com -u admin -P s3cr3t -r 2 -o results.txt

=cut