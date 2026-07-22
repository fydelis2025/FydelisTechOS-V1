package FydelisHash::Rules;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use List::Util qw(shuffle);

requires qw(config logger);

# ── Aplicar regras a uma senha ────────────────────────
sub apply_rules {
    my ($self, $password) = @_;

    my @results = ($password);
    my @rules = $self->_load_rules();

    for my $rule (@rules) {
        my @variants = $self->_apply_single_rule($password, $rule);
        push @results, @variants;
    }

    return @results;
}

# ── Carregar regras ───────────────────────────────────
sub _load_rules {
    my $self = shift;

    my @rules;

    # Regras do arquivo
    if ($self->config->has_rules_file) {
        open my $fh, '<', $self->config->rules_file or do {
            $self->logger->warn("Não foi possível abrir regras: %s", $self->config->rules_file);
            return @rules;
        };
        chomp(my @lines = <$fh>);
        close $fh;
        push @rules, grep { /\S/ && !/^#/ } @lines;
    }

    # Regras inline
    push @rules, $self->config->rules->@*;

    return @rules;
}

# ============================================================
# IMPLEMENTAÇÃO DE REGRAS (hashcat-style)
# ============================================================

sub _apply_single_rule {
    my ($self, $word, $rule) = @_;
    return ($word) unless defined $rule && $rule ne '';

    my @results;

    # Regras são aplicadas em pipeline
    my $current = $word;

    # Tokenizar a regra (separada por espaço)
    my @tokens = split(/\s+/, $rule);

    for my $token (@tokens) {
        last unless defined $current && length($current) > 0;

        my $op = substr($token, 0, 1);
        my $arg = substr($token, 1) // '';

        $current = $self->_apply_token($current, $op, $arg);
    }

    push @results, $current if defined $current && length($current) > 0;
    return @results;
}

sub _apply_token {
    my ($self, $word, $op, $arg) = @_;

    return $word unless defined $word;

    given ($op) {
        # ── Lowercase ──────────────────────────────
        when ('l') { return lc($word) }

        # ── Uppercase ──────────────────────────────
        when ('u') { return uc($word) }

        # ── Capitalize (primeira letra maiúscula) ──
        when ('c') { return ucfirst(lc($word)) }

        # ── Toggle case (inverte) ──────────────────
        when ('t') {
            return join('', map { $_ eq uc($_) ? lc($_) : uc($_) } split(//, $word));
        }

        # ── Reverse ────────────────────────────────
        when ('r') { return scalar reverse($word) }

        # ── Duplicate ──────────────────────────────
        when ('d') { return $word x 2 }

        # ── Append character ───────────────────────
        when ('$') {
            return $word . $arg;
        }

        # ── Prepend character ──────────────────────
        when ('^') {
            return $arg . $word;
        }

        # ── Append number ──────────────────────────
        when ('a') {
            return $word . $arg;
        }

        # ── Delete first N chars ───────────────────
        when ('[') {
            my $n = $arg || 1;
            return substr($word, $n);
        }

        # ── Delete last N chars ────────────────────
        when (']') {
            my $n = $arg || 1;
            return substr($word, 0, length($word) - $n);
        }

        # ── Substitute character ───────────────────
        when ('s') {
            my ($old, $new) = split(/\s*,\s*/, $arg, 2);
            return undef unless defined $old && defined $new;
            $word =~ s/\Q$old\E/$new/g;
            return $word;
        }

        # ── @ = Substitute (first occurrence only) ─
        when ('@') {
            my ($old, $new) = split(/\s*,\s*/, $arg, 2);
            return undef unless defined $old && defined $new;
            $word =~ s/\Q$old\E/$new/;
            return $word;
        }

        # ── Insert at position ─────────────────────
        when ('i') {
            my ($pos, $char) = split(/\s*,\s*/, $arg, 2);
            return undef unless defined $pos && defined $char;
            substr($word, $pos, 0, $char);
            return $word;
        }

        # ── Overwrite at position ──────────────────
        when ('o') {
            my ($pos, $char) = split(/\s*,\s*/, $arg, 2);
            return undef unless defined $pos && defined $char;
            substr($word, $pos, 1, $char);
            return $word;
        }

        # ── Truncate to N ──────────────────────────
        when ('tr') {
            my $n = $arg || 8;
            return substr($word, 0, $n);
        }

        # ── Leet speak ─────────────────────────────
        when ('leet') {
            my %leet = (a => '4', e => '3', i => '1', o => '0', s => '5', t => '7');
            $word =~ s/([aeiost])/$leet{lc($1)}/gie;
            return $word;
        }

        # ── Toggle @ N ───────────────────────────
        when ('T') {
            my $n = $arg || 0;
            my @chars = split(//, $word);
            if ($n < @chars) {
                $chars[$n] = $chars[$n] eq uc($chars[$n])
                    ? lc($chars[$n])
                    : uc($chars[$n]);
            }
            return join('', @chars);
        }

        # ── Nothing ───────────────────────────────
        default { return $word }
    }
}

# ── Gerar regras comuns automaticamente ──────────────
sub generate_common_rules {
    my $self = shift;

    my @rules = (
        'l',           # lowercase
        'u',           # uppercase
        'c',           # capitalize
        'r',           # reverse
        'd',           # duplicate
        'l r',         # lowercase + reverse
        'u r',         # uppercase + reverse
        'c r',         # capitalize + reverse
        '$1',          # append 1
        '$2',
        '$3',
        '$!',
        '$@',
        '$#',
        'l $1',        # lowercase + 1
        'l $!',
        'l $123',
        'c $1',
        'c $!',
        'l r $1',
        'c r $!',
        'd $1',
        'd $!',
        'l leet',      # lowercase + leet
        'l leet $1',
        'l leet $!',
        'u leet',
        'c leet',
        'l $2024',
        'l $2025',
        'l $2026',
        '$1 l',
        '$1 u',
        'l tr8',       # lower + truncate 8
        'l tr8 $!',
        's,e,3',       # substitute e -> 3
        's,a,4',
        's,i,1',
        's,o,0',
        's,s,5',
    );

    return @rules;
}

1;