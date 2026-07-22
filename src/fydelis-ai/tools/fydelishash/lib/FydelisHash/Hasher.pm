package FydelisHash::Hasher;
use v5.20;
use strict;
use warnings;
use Moo::Role;
use Try::Tiny;
use Encode qw(encode);
use MIME::Base64 qw(encode_base64 decode_base64);

use Digest::MD5    qw(md5 md5_hex);
use Digest::SHA    qw(sha1 sha1_hex sha224 sha224_hex sha256 sha256_hex
                      sha384 sha384_hex sha512 sha512_hex
                      sha512_256 sha512_256_hex);

# Carregar módulos opcionais com fallback silencioso
my $HAVE_MD4       = eval { require Digest::MD4; 1 };
my $HAVE_WHIRLPOOL = eval { require Digest::Whirlpool; 1 };
my $HAVE_BLAKE2    = eval { require Digest::BLAKE2; 1 };
my $HAVE_BCRYPT    = eval { require Crypt::Eksblowfish::Bcrypt; 1 };
my $HAVE_DES       = eval { require Crypt::DES; 1 };

requires qw(config logger);

# ============================================================
# HASH PRINCIPAL
# ============================================================
sub compute_hash {
    my ($self, $password, $type) = @_;

    my $method = "_hash_$type";
    if (!$self->can($method)) {
        $self->logger->error("Tipo de hash não suportado: %s", $type);
        return undef;
    }

    return $self->$method($password);
}

# ============================================================
# ALGORITMOS INDIVIDUAIS
# ============================================================

sub _hash_md5 {
    my ($self, $pass) = @_;
    return md5_hex($pass);
}

sub _hash_sha1 {
    my ($self, $pass) = @_;
    return sha1_hex($pass);
}

sub _hash_sha224 {
    my ($self, $pass) = @_;
    return sha224_hex($pass);
}

sub _hash_sha256 {
    my ($self, $pass) = @_;
    return sha256_hex($pass);
}

sub _hash_sha384 {
    my ($self, $pass) = @_;
    return sha384_hex($pass);
}

sub _hash_sha512 {
    my ($self, $pass) = @_;
    return sha512_hex($pass);
}

sub _hash_sha512_256 {
    my ($self, $pass) = @_;
    return sha512_256_hex($pass);
}

sub _hash_ntlm {
    my ($self, $pass) = @_;
    if (!$HAVE_MD4) {
        $self->logger->error("Digest::MD4 não instalado. Instale com: cpanm Digest::MD4");
        return undef;
    }
    my $md4 = Digest::MD4->new();
    $md4->add(encode("UTF-16LE", $pass));
    return lc($md4->hexdigest());
}

sub _hash_md4 {
    my ($self, $pass) = @_;
    if (!$HAVE_MD4) {
        $self->logger->error("Digest::MD4 não instalado. Instale com: cpanm Digest::MD4");
        return undef;
    }
    my $md4 = Digest::MD4->new();
    $md4->add($pass);
    return lc($md4->hexdigest());
}

sub _hash_lm {
    my ($self, $pass) = @_;
    if (!$HAVE_DES) {
        $self->logger->error("Crypt::DES não instalado. Instale com: cpanm Crypt::DES");
        return undef;
    }

    my $pw = uc($pass);
    $pw = substr($pw . ("\x00" x 14), 0, 14);

    my $part1 = substr($pw, 0, 7);
    my $part2 = substr($pw, 7, 7);

    my $magic = "KGS!@\#$%";

    my $c1 = Crypt::DES->new($self->_des_key($part1));
    my $c2 = Crypt::DES->new($self->_des_key($part2));

    return '' unless $c1 && $c2;

    my $hash = $c1->encrypt($magic) . $c2->encrypt($magic);
    return unpack('H*', $hash);
}

sub _des_key {
    my ($self, $key7) = @_;
    my $key8 = '';
    for my $i (0..6) {
        my $byte = ord(substr($key7, $i, 1));
        # DES key schedule with odd parity
        my $parity_byte = 0;
        for my $b (0..6) {
            $parity_byte |= (($byte >> $b) & 1) << ($b + 1);
        }
        # Calculate odd parity bit
        my $bits = 0;
        for my $b (0..6) {
            $bits += (($parity_byte >> ($b + 1)) & 1);
        }
        $parity_byte |= (($bits % 2 == 0) ? 1 : 0);
        $key8 .= chr($parity_byte);
    }
    return $key8;
}

sub _hash_bcrypt {
    my ($self, $pass) = @_;
    if (!$HAVE_BCRYPT) {
        $self->logger->error("Crypt::Eksblowfish::Bcrypt não instalado. Instale com: cpanm Crypt::Eksblowfish::Bcrypt");
        return undef;
    }

    # Se temos salt configurado, usar. Senão, gerar hash de exemplo para comparação
    if ($self->config->has_salt) {
        my $salt = $self->config->salt;
        # salt já deve ser o settings string do bcrypt: $2a$08$...
        if ($salt =~ /^\$\d[ayb]\$\d{2}\$/) {
            return Crypt::Eksblowfish::Bcrypt::Hash->new(
                cost => 8,
                salt => $salt,
            )->bcrypt_hash($pass);
        }
    }

    # Comparação: o hash alvo já contém o salt (formato $2y$10$...)
    # Para verificação, usamos o hash completo como "settings"
    return undef;  # bcrypt precisa do hash alvo para extrair settings
}

sub _hash_sha512_crypt {
    my ($self, $pass) = @_;
    return $self->_unix_crypt($pass, 'sha512', '$6$');
}

sub _hash_sha256_crypt {
    my ($self, $pass) = @_;
    return $self->_unix_crypt($pass, 'sha256', '$5$');
}

sub _hash_md5_crypt {
    my ($self, $pass) = @_;
    return $self->_unix_crypt($pass, 'md5', '$1$');
}

sub _unix_crypt {
    my ($self, $pass, $type, $prefix) = @_;

    try {
        require Crypt::Passwd::XS;
        my $salt = $self->config->salt;
        if ($salt && $salt =~ /^\Q$prefix\E/) {
            $salt =~ s/^\Q$prefix\E//;
            $salt =~ s/\$.*$//;  # remove trailing hash part
        }
        $salt ||= 'salt';

        if ($type eq 'sha512') {
            return Crypt::Passwd::XS::crypt($pass, $prefix . $salt . '$');
        } elsif ($type eq 'sha256') {
            return Crypt::Passwd::XS::crypt($pass, $prefix . $salt . '$');
        } elsif ($type eq 'md5') {
            return Crypt::Passwd::XS::crypt($pass, $prefix . $salt . '$');
        }
    } catch {
        $self->logger->error("Crypt::Passwd::XS não instalado: %s", $_);
        return undef;
    };
}

sub _hash_whirlpool {
    my ($self, $pass) = @_;
    if (!$HAVE_WHIRLPOOL) {
        $self->logger->error("Digest::Whirlpool não instalado. Instale com: cpanm Digest::Whirlpool");
        return undef;
    }
    return Digest::Whirlpool::whirlpool_hex($pass);
}

sub _hash_blake2b {
    my ($self, $pass) = @_;
    if (!$HAVE_BLAKE2) {
        $self->logger->error("Digest::BLAKE2 não instalado. Instale com: cpanm Digest::BLAKE2");
        return undef;
    }
    return Digest::BLAKE2::blake2b_hex($pass);
}

sub _hash_gost {
    my ($self, $pass) = @_;
    try {
        require Digest::GOST;
        return Digest::GOST::gost_hex($pass);
    } catch {
        $self->logger->error("Digest::GOST não instalado");
        return undef;
    };
}

sub _hash_sha3_256 {
    my ($self, $pass) = @_;
    try {
        require Digest::SHA3;
        return Digest::SHA3::sha3_256_hex($pass);
    } catch {
        $self->logger->error("Digest::SHA3 não instalado");
        return undef;
    };
}

sub _hash_sha3_512 {
    my ($self, $pass) = @_;
    try {
        require Digest::SHA3;
        return Digest::SHA3::sha3_512_hex($pass);
    } catch {
        $self->logger->error("Digest::SHA3 não instalado");
        return undef;
    };
}

1;