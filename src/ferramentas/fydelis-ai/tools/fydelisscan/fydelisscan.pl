#!/usr/bin/env perl
#
# fydelisscan.pl - FydelisTechos Service Scanner + Credential Tester
# ==================================================================
# Author:  Adiel Santos Fontes
# License: MIT (Authorized Security Testing Only)
# Version: 2.0.0
# ==================================================================

use v5.20;
use strict;
use warnings;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

use FindBin;
use lib "$FindBin::Bin/lib";

use FydelisScan        ();
use FydelisScan::CLI   ();
use FydelisScan::Logger ();

# ── Graceful shutdown ──────────────────────────────────
our $SHUTDOWN = 0;
$SIG{INT}  = sub { $SHUTDOWN = 1; warn "\n⚠️  Recebido SIGINT — encerrando...\n"; };
$SIG{TERM} = sub { $SHUTDOWN = 1; };

sub main {
    my $cli  = FydelisScan::CLI->new();
    my $conf = $cli->parse_args(\@ARGV) or return 1;

    my $logger = FydelisScan::Logger->new(
        level   => $conf->verbose ? 'DEBUG' : 'INFO',
        logfile => $conf->logfile,
    );

    my $engine = FydelisScan->new(
        config   => $conf,
        logger   => $logger,
        shutdown => \$SHUTDOWN,
    );

    $engine->run();
    return 0;
}

exit main();