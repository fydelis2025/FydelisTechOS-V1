package FydelisHash::CLI;
use v5.20;
use strict;
use warnings;
use Moo;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Pod::Usage;

use FydelisHash::Config;

sub parse_args {
    my ($self, $argv) = @_;

    my %opts;
    GetOptionsFromArray($$argv, \%opts,
        'h|hash=s'              => \$opts{hash},
        'H|hashlist=s'          => \$opts{hashlist},

        'w|wordlist=s'          => \$opts{wordlist},
        'W|word=s'              => \$opts{word},  # single word to test

        't|type=s'              => \$opts{type},

        'r|rules=s'             => \$opts{rules},  # rule file
        'R|rule=s'              => \$opts{rule},   # single rule (can repeat)

        'T|threads=i'           => \$opts{threads},
        'no-stop'               => \$opts{no_stop},
        'case-perm'             => \$opts{case_perm},
        'append-num'            => \$opts{append_num},
        'num-range=s'           => \$opts{num_range},
        'min-len=i'             => \$opts{min_len},
        'max-len=i'             => \$opts{max_len},

        'salt=s'                => \$opts{salt},

        'o|output=s'            => \$opts{output},
        'l|log=s'               => \$opts{log},
        'v|verbose'             => \$opts{verbose},
        'q|quiet'               => \$opts{quiet},
        'list-hash-types'       => \$opts{list_types},
        'help|?'                => \$opts{help},
        'version'               => \$opts{version},
    ) or pod2usage(2);

    # ── Help / Version / List Types ───────────────────
    if ($opts{help}) {
        $self->_banner();
        pod2usage(-verbose => 2, -exitval => 0);
    }

    if ($opts{version}) {
        $self->_banner();
        print "Versão: 2.0.0\n";
        exit 0;
    }

    if ($opts{list_types}) {
        $self->_banner();
        print "\nTipos de hash suportados:\n\n";
        my $config = FydelisHash::Config->new();
        for my $t (sort $config->available_hash_types->@*) {
            printf "  %-15s\n", $t;
        }
        print "\n";
        exit 0;
    }

    # ── Carregar hashes ──────────────────────────────
    my @hashes;
    if ($opts{hashlist}) {
        @hashes = $self->_load_list($opts{hashlist});
        unless (@hashes) {
            print "\n❌ Lista de hashes vazia ou não encontrada: $opts{hashlist}\n\n";
            return undef;
        }
    } elsif ($opts{hash}) {
        @hashes = ($opts{hash});
    } else {
        print "\n❌ Hash (-h) ou lista de hashes (-H) é obrigatório.\n\n";
        return undef;
    }

    # ── Carregar wordlist ────────────────────────────
    my @wordlist;
    if ($opts{wordlist}) {
        @wordlist = $self->_load_list($opts{wordlist});
        unless (@wordlist) {
            print "\n❌ Wordlist vazia ou não encontrada: $opts{wordlist}\n\n";
            return undef;
        }
    } elsif ($opts{word}) {
        @wordlist = ($opts{word});
    } else {
        # Wordlist padrão interna (senhas comuns)
        @wordlist = $self->_default_wordlist();
    }

    # ── Carregar regras ──────────────────────────────
    my @rules;
    if ($opts{rules}) {
        my @file_rules = $self->_load_list($opts{rules});
        push @rules, @file_rules;
    }
    if ($opts{rule}) {
        push @rules, $opts{rule};
    }

    # ── Validar tipo ──────────────────────────────────
    my $conf_check = FydelisHash::Config->new();
    if ($opts{type} && !$conf_check->is_valid_hash_type($opts{type})) {
        print "\n❌ Tipo de hash inválido: $opts{type}\n";
        print "   Use --list-hash-types para ver os suportados.\n\n";
        return undef;
    }

    my $config = FydelisHash::Config->new(
        target_hashes    => \@hashes,
        (defined $opts{type} ? (hash_type => lc($opts{type})) : ()),
        wordlist         => \@wordlist,
        rules            => \@rules,
        (defined $opts{rules}  ? (rules_file => $opts{rules}) : ()),
        threads          => $opts{threads}       // 4,
        stop_on_first    => !$opts{no_stop},
        case_permutations => $opts{case_perm}    // 0,
        append_numbers   => $opts{append_num}    // 0,
        number_range     => $opts{num_range}     // '0-9999',
        min_length       => $opts{min_len}       // 1,
        max_length       => $opts{max_len}       // 128,
        (defined $opts{salt} ? (salt => $opts{salt}) : ()),
        (defined $opts{output} ? (output_file => $opts{output}) : ()),
        (defined $opts{log}    ? (logfile     => $opts{log})    : ()),
        verbose          => $opts{verbose}        // 0,
        quiet            => $opts{quiet}          // 0,
    );

    return $config;
}

sub _banner {
    print <<'BANNER';
╔══════════════════════════════════════════════════════════╗
║             FydelisHash  v2.0                             ║
║           Hash Cracking Framework                         ║
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
        admin 123456 password 12345678 qwerty 12345 1234 123456789
        football 1234567 baseball welcome 1234567890 abc123 111111
        1qaz2wsx dragon master monkey letmein login passw0rd
        starwars 654321 superman qazwsx hello 121212
    );
}

1;

__END__

=head1 NAME

fydelishash.pl - Hash Cracking Framework

=head1 SYNOPSIS

  fydelishash.pl -h HASH -w WORDLIST [options]

  Target:
    -h, --hash HASH           Target hash (single)
    -H, --hashlist FILE       File with hashes (one per line)
    -t, --type TYPE           Hash type (md5, sha1, sha256, ntlm, auto)

  Dictionary:
    -w, --wordlist FILE       Password dictionary
    -W, --word TEXT           Single password to test

  Rules (hashcat-style):
    -r, --rules FILE          Rule file (one rule per line)
    -R, --rule RULE           Single rule (can be repeated)

  Performance:
    -T, --threads N           Threads (default: 4, max: 64)
    --no-stop                 Continue after finding a match
    --case-perm               Try case permutations
    --append-num              Append numbers to each word
    --num-range RANGE         Number range (default: 0-9999)
    --min-len N               Min password length (default: 1)
    --max-len N               Max password length (default: 128)

  Salt:
    --salt TEXT               Salt for salted hashes

  Output:
    -o, --output FILE         Save found passwords
    -l, --log FILE            Log file
    -v, --verbose             Verbose
    -q, --quiet               Only show results

  Other:
    --list-hash-types         List supported hash types
    --help                    This help
    --version                 Version

=head1 DESCRIPTION

FydelisHash is a multi-threaded hash cracking framework supporting
multiple hash algorithms with hashcat-compatible rules.

=head1 EXAMPLES

  # Basic MD5
  fydelishash.pl -h 5f4dcc3b5aa765d61d8327deb882cf99 -w rockyou.txt

  # Auto-detect + SHA256
  fydelishash.pl -h 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08 -w passwords.txt

  # NTLM with rules
  fydelishash.pl -h 209c6174da490caeb422f3fa5a7ae634 -w wordlist.txt -r rules/best64.rule -T 8

  # Multiple hashes from file
  fydelishash.pl -H hashes.txt -w dict.txt -t sha1 -o found.txt

  # Salted hash with append numbers
  fydelishash.pl -h hash.txt -w dict.txt --salt "mysalt" --append-num --num-range 0-999

=cut