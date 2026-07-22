package FydelisWordlist::Rules;
use v5.20;
use strict;
use warnings;
use Moo::Role;

requires qw(config logger shutdown);

# ── Leet speak map ────────────────────────────────────
my %LEET_MAP = (
    'a' => ['4', '@'],
    'b' => ['8'],
    'e' => ['3'],
    'g' => ['9', '6'],
    'i' => ['1', '!'],
    'l' => ['1', '7'],
    'o' => ['0'],
    's' => ['5', '$', 'z'],
    't' => ['7', '+'],
    'z' => ['2'],
);

# ── Prefixos e sufixos comuns ─────────────────────────
my @COMMON_PREFIXES = qw(admin root master super power ultra mega hyper);
my @COMMON_SUFFIXES = qw(admin root admin123 123 admin! 123!);

# ── Símbolos comuns ───────────────────────────────────
my @SYMBOLS = qw(! @ # $ % & * _ - + = ? .);

# ── Números comuns ────────────────────────────────────
my @COMMON_NUMBERS = (
    qw(0 1 12 123 1234 12345 123456 7 777 888 999 1000 2000),
    qw(2020 2021 2022 2023 2024 2025 2026),
);

# ============================================================
# MÉTODOS DE MUTAÇÃO
# ============================================================

# ── Lowercase / Uppercase / Capitalize / Toggle ───────
sub apply_case_variations {
    my ($self, $word) = @_;
    return () unless $self->config->include_caps;

    my @variants;
    push @variants, lc($word);
    push @variants, uc($word);
    push @variants, ucfirst(lc($word));
    push @variants, join('', map { $_ eq uc($_) ? lc($_) : uc($_) } split(//, $word));

    return @variants;
}

# ── Leet speak ─────────────────────────────────────────
sub apply_leet {
    my ($self, $word) = @_;
    return $word unless $self->config->include_leet;

    my $leet = lc($word);
    for my $char (keys %LEET_MAP) {
        my @subs = $LEET_MAP{$char}->@*;
        for my $sub (@subs) {
            $leet =~ s/$char/$sub/g;
        }
    }
    return $leet;
}

# ── Leet variations (múltiplas combinações parciais) ──
sub apply_leet_variations {
    my ($self, $word) = @_;
    return ($word) unless $self->config->include_leet;

    my $lc = lc($word);
    my @variants = ($lc);

    # Aplicar substituições uma por uma para gerar variantes
    for my $char (keys %LEET_MAP) {
        my @subs = $LEET_MAP{$char}->@*;
        for my $sub (@subs) {
            my $new = $lc;
            $new =~ s/$char/$sub/;
            push @variants, $new if $new ne $lc;
        }
    }

    return @variants;
}

# ── Reverso ────────────────────────────────────────────
sub apply_reverse {
    my ($self, $word) = @_;
    return () unless $self->config->include_reversed;
    return scalar reverse($word);
}

# ── Duplicado ──────────────────────────────────────────
sub apply_double {
    my ($self, $word) = @_;
    return () unless $self->config->include_doubled;
    return $word x 2;
}

# ── Truncado (primeiros 3, 4, 5 caracteres) ──────────
sub apply_truncated {
    my ($self, $word) = @_;
    return () unless $self->config->include_truncated;

    my @variants;
    my $len = length($word);
    for my $n (3, 4, 5) {
        last if $n >= $len;
        push @variants, substr($word, 0, $n);
    }
    return @variants;
}

# ── Apenas números do ano ──────────────────────────────
sub year_numbers {
    my ($self) = @_;
    my @nums;

    if ($self->config->year) {
        push @nums, $self->config->year;
        # Últimos 2 dígitos
        push @nums, substr($self->config->year, -2) if length($self->config->year) >= 2;
    }

    if ($self->config->append_current_year) {
        my $cy = (localtime)[5] + 1900;
        push @nums, $cy;
        push @nums, substr($cy, -2);
    }

    return @nums;
}

# ── Números comuns para append ─────────────────────────
sub common_numbers {
    my ($self) = @_;
    return @COMMON_NUMBERS;
}

# ── Símbolos para append ──────────────────────────────
sub common_symbols {
    my ($self) = @_;
    return @SYMBOLS;
}

# ── Sanitize: aplicar min/max length ──────────────────
sub sanitize_length {
    my ($self, $word) = @_;

    my $len = length($word);
    return 0 if $len < $self->config->min_length;
    return 0 if $len > $self->config->max_length;
    return 1;
}

1;