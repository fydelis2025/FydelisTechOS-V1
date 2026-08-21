#!/usr/bin/env perl
#
# fydelisbrute.pl - FydelisTechos Credential Testing Framework
# ============================================================
# Author:  Adiel Santos Fontes
# License: MIT (Authorized Security Testing Only)
# Version: 2.0.0
# ============================================================

use v5.20;
use strict;
use warnings;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

use FindBin;
use lib "$FindBin::Bin/lib";

use FydelisBrute       ();
use FydelisBrute::CLI  ();
use FydelisBrute::Logger ();

# ─────────────────────────────────────────────────────────────
# Graceful shutdown handler
# ─────────────────────────────────────────────────────────────
our $SHUTDOWN = 0;
$SIG{INT}  = sub { $SHUTDOWN = 1; warn "\n⚠️  Recebido SIGINT — encerrando graciosamente...\n"; };
$SIG{TERM} = sub { $SHUTDOWN = 1; };

sub main {
    my $cli   = FydelisBrute::CLI->new();
    my $conf  = $cli->parse_args(\@ARGV) or return 1;

    my $logger = FydelisBrute::Logger->new(
        level     => $conf->verbose ? 'DEBUG' : 'INFO',
        logfile   => $conf->logfile,
    );

    my $engine = FydelisBrute->new(
        config   => $conf,
        logger   => $logger,
        shutdown => \$SHUTDOWN,
    );

    $engine->run();
    return 0;
}

exit main();