package FydelisWordlist::CLI;
use v5.20;
use strict;
use warnings;
use Moo;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Pod::Usage;
use POSIX qw(strftime);

use FydelisWordlist::Config;

sub parse_args {
    my ($self, $argv) = @_;

    my %opts;
    GetOptionsFromArray($$argv, \%opts,
        'n|name|first-name=s'       => \$opts{first_name},
        's|surname|last-name=s'     => \$opts{last_name},
        'a|year=s'                  => \$opts{year},
        'l|location=s'              => \$opts{location},
        'k|keyword|sigla=s'         => \$opts{keyword},
        'w|word|extra-words=s'      => \$opts{extra_words},
        'min-length=i'              => \$opts{min_length},
        'max-length=i'              => \$opts{max_length},
        'no-numbers'                => \$opts{no_numbers},
        'with-symbols'              => \$opts{with_symbols},
        'with-leet'                 => \$opts{with_leet},
        'no-caps'                   => \$opts{no_caps},
        'no-patterns'               => \$opts{no_patterns},
        'with-reversed'             => \$opts{with_reversed},
        'with-doubled'              => \$opts{with_doubled},
        'with-truncated'            => \$opts{with_truncated},
        'append-year'               => \$opts{append_year},
        'max-words=i'               => \$opts{max_words},
        'o|output=s'                => \$opts{output},
        'l|log=s'                   => \$opts{log},
        'v|verbose'                 => \$opts{verbose},
        'estimate'                  => \$opts{estimate},  # só estimar, não gerar
        'help|?'                    => \$opts{help},
        'version'                   => \$opts{version},
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

    # ── Extra words ───────────────────────────────────
    my @extra = ();
    if ($opts{extra_words}) {
        @extra = split(/[,;:|\s]+/, $opts{extra_words});
        @extra = grep { /\S/ } @extra;
    }

    # ── Validar dados mínimos ─────────────────────────
    my $has_data = $opts{first_name} || $opts{last_name} || $opts{year}
                || $opts{location}   || $opts{keyword}   || @extra;

    unless ($has_data) {
        $self->_banner();
        print "\n❌ Nenhum dado informado! Forneça ao menos um dos:\n";
        print "   -n, --name       Nome\n";
        print "   -s, --surname    Sobrenome\n";
        print "   -a, --year       Ano\n";
        print "   -l, --location   Local\n";
        print "   -k, --keyword    Palavra-chave\n";
        print "   -w, --word       Palavras extras\n\n";
        print "Use --help para ajuda completa.\n\n";
        return undef;
    }

    my $config = FydelisWordlist::Config->new(
        first_name           => $opts{first_name}   // '',
        last_name            => $opts{last_name}    // '',
        year                 => $opts{year}         // '',
        location             => $opts{location}     // '',
        keyword              => $opts{keyword}      // '',
        extra_words          => \@extra,
        min_length           => $opts{min_length}   // 4,
        max_length           => $opts{max_length}   // 32,
        include_numbers      => !$opts{no_numbers},
        include_symbols      => $opts{with_symbols} // 0,
        include_leet         => $opts{with_leet}    // 0,
        include_caps         => !$opts{no_caps},
        include_common_patterns => !$opts{no_patterns},
        include_reversed     => $opts{with_reversed} // 0,
        include_doubled      => $opts{with_doubled}  // 0,
        include_truncated    => $opts{with_truncated} // 0,
        append_current_year  => $opts{append_year}   // 0,
        max_combinations     => $opts{max_words}     // 10_000_000,
        output_file          => $opts{output}        // 'wordlist.txt',
        (defined $opts{log}  ? (logfile => $opts{log}) : ()),
        verbose              => $opts{verbose}       // 0,
    );

    # Se só estimativa, print e exit
    if ($opts{estimate}) {
        $self->_print_estimate($config);
        exit 0;
    }

    return $config;
}

sub _banner {
    print <<'BANNER';
╔══════════════════════════════════════════════════════════╗
║           FydelisWordlist  v2.0                          ║
║           Custom Wordlist Generator                      ║
║              FydelisTechos © 2026                        ║
║    Authorized Security Assessment Use Only               ║
╚══════════════════════════════════════════════════════════╝
BANNER
}

sub _print_estimate {
    my ($self, $config) = @_;

    # Estimativa aproximada baseada nas opções
    my $base_words = 0;
    $base_words++ if $config->first_name;
    $base_words++ if $config->last_name;
    $base_words++ if $config->year;
    $base_words++ if $config->location;
    $base_words++ if $config->keyword;
    $base_words += scalar $config->extra_words->@*;

    # Fatores multiplicadores
    my $factor = 1;
    $factor *= 2 if $config->include_numbers;      # com/sem números
    $factor *= 5 if $config->include_symbols;       # vários símbolos
    $factor *= 4 if $config->include_leet;          # substituições leet
    $factor *= 4 if $config->include_caps;          # case variations
    $factor *= 10 if $config->include_common_patterns;
    $factor *= 2 if $config->include_reversed;
    $factor *= 2 if $config->include_doubled;
    $factor *= 3 if $config->include_truncated;

    # Números (0-9999)
    my $num_count = $config->include_numbers ? 10000 : 1;

    # Símbolos
    my $sym_count = $config->include_symbols ? 10 : 1;

    my $estimated = ($base_words ** 2) * $factor * $num_count * $sym_count;
    $estimated = 5_000_000 if $estimated > 5_000_000;

    print "\n📊 ESTIMATIVA DE GERAÇÃO:\n";
    print "  Palavras base:     $base_words\n";
    print "  Fator de mutação:  ${factor}x\n";
    print "  Números:           " . ($config->include_numbers ? "0-9999 + ano" : "nenhum") . "\n";
    print "  Símbolos:          " . ($config->include_symbols ? "10 caracteres" : "nenhum") . "\n";
    print "  Aproximadamente:   $estimated combinações\n";
    print "  Máximo configurado: " . ($config->max_combinations || "ilimitado") . "\n";
    print "\n";
}

1;

__END__

=head1 NAME

fydeliswordlist.pl - Custom Wordlist Generator

=head1 SYNOPSIS

  fydeliswordlist.pl [options]

  Data Input (at least one required):
    -n, --name TEXT           First name
    -s, --surname TEXT        Last name / surname
    -a, --year TEXT           Year (e.g. 1990, 2024)
    -l, --location TEXT       City, state, or location
    -k, --keyword TEXT        Keyword, acronym, or nickname
    -w, --word WORDS          Extra words (comma separated)

  Mutation Rules:
    --min-length N            Minimum password length (default: 4)
    --max-length N            Maximum password length (default: 32)
    --no-numbers              Disable number appending
    --with-symbols            Enable symbol appending (!@#$ etc.)
    --with-leet               Enable leet speak substitutions
    --no-caps                 Disable case variations
    --no-patterns             Disable common patterns (123, 2024!)
    --with-reversed           Include reversed versions
    --with-doubled            Include doubled words (wordword)
    --with-truncated          Include truncated versions (first 3 chars)
    --append-year             Always append current year

  Output:
    --max-words N             Max combinations (default: 10M, 0=unlimited)
    -o, --output FILE         Output file (default: wordlist.txt)
    -l, --log FILE            Log file
    -v, --verbose             Verbose output

  Other:
    --estimate                Only estimate size, don't generate
    --help                    This help
    --version                 Version

=head1 DESCRIPTION

FydelisWordlist generates customized wordlists for authorized
penetration testing. It applies multiple mutation rules including
leet speak, case variations, number/symbol appending, and common
password patterns.

=head1 EXAMPLES

  # Basic: name + surname + year
  fydeliswordlist.pl -n Maria -s Silva -a 1990 -o maria.txt

  # With leet and symbols
  fydeliswordlist.pl -n Admin -s Server -k corp --with-leet --with-symbols -o admin.txt

  # Company target with extra words and estimate
  fydeliswordlist.pl -k empresa -w "2024,portal,vpn,backup" --with-leet --estimate

  # Full mutation
  fydeliswordlist.pl -n Joao -s Santos -a 1985 -l "Rio de Janeiro" \
      -w "admin,teste,dev" --with-leet --with-symbols --with-reversed \
      --max-words 500000 -o joao.txt -v

=cut