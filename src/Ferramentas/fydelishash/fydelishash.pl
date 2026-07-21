#!/usr/bin/env perl
#
# fydelishash.pl - FydelisTechos Hash Cracking Framework
# =======================================================
# Author:  Adiel Santos Fontes
# License: MIT (Authorized Security Testing Only)
# Version: 2.0.0
# =======================================================

use v5.20;
use strict;
use warnings;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

use FindBin;
use lib "$FindBin::Bin/lib";

use FydelisHash        ();
use FydelisHash::CLI   ();
use FydelisHash::Logger ();

# ── Graceful shutdown ──────────────────────────────────
our $SHUTDOWN = 0;
$SIG{INT}  = sub { $SHUTDOWN = 1; warn "\n⚠️  Recebido SIGINT — finalizando...\n"; };
$SIG{TERM} = sub { $SHUTDOWN = 1; };

sub main {
    my $cli  = FydelisHash::CLI->new();
    my $conf = $cli->parse_args(\@ARGV) or return 1;

    my $logger = FydelisHash::Logger->new(
        level   => $conf->verbose ? 'DEBUG' : 'INFO',
        logfile => $conf->logfile,
    );

    my $engine = FydelisHash->new(
        config   => $conf,
        logger   => $logger,
        shutdown => \$SHUTDOWN,
    );

    $engine->run();
    return 0;
}

exit main();