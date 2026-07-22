package FydelisAI::Session;
use v5.20;
use strict;
use warnings;
use Moo;
use JSON;
use File::Path qw(make_path);
use File::Spec;
use POSIX qw(strftime);

has config => ( is => 'ro', required => 1 );
has logger => ( is => 'ro', required => 1 );

has target => (
    is      => 'ro',
    default => 'default',
);

has _messages => (
    is      => 'rw',
    default => sub { [] },
);

has _session_file => (
    is      => 'lazy',
);

sub _build__session_file {
    my $self = shift;

    my $dir = $self->config->session_dir;
    make_path($dir) unless -d $dir;

    my $safe_target = $self->target;
    $safe_target =~ s/[^a-zA-Z0-9._-]/_/g;

    return File::Spec->catfile($dir, "$safe_target.json");
}

sub add_message {
    my ($self, $role, $content) = @_;

    push $self->_messages->@*, {
        role      => $role,
        content   => $content,
        timestamp => strftime('%Y-%m-%dT%H:%M:%S', gmtime),
    };

    $self->_save() if $self->config->save_sessions;
}

sub get_context {
    my ($self, $max_messages) = @_;
    $max_messages //= 20;

    my @recent = $self->_messages->@*;
    if (@recent > $max_messages) {
        @recent = @recent[-$max_messages .. -1];
    }

    my $context = '';
    for my $msg (@recent) {
        my $prefix = $msg->{role} eq 'user' ? 'Você' : 'Assistente';
        $context .= "$prefix: $msg->{content}\n\n";
    }

    return $context;
}

sub clear {
    my $self = shift;
    $self->_messages([]);
    $self->_save();
}

sub _save {
    my $self = shift;
    return unless $self->config->save_sessions;

    eval {
        open my $fh, '>', $self->_session_file or die $!;
        print $fh encode_json($self->_messages);
        close $fh;
    };
    if ($@) {
        $self->logger->warn("Falha ao salvar sessão: %s", $@);
    }
}

sub _load {
    my $self = shift;

    my $file = $self->_session_file;
    return unless -f $file;

    eval {
        open my $fh, '<', $file or return;
        local $/;
        my $json = <$fh>;
        close $fh;

        my $data = decode_json($json);
        $self->_messages($data) if ref $data eq 'ARRAY';
    };
    if ($@) {
        $self->logger->warn("Falha ao carregar sessão: %s", $@);
    }
}

sub BUILD {
    my $self = shift;
    $self->_load();
}

sub DESTROY {
    my $self = shift;
    $self->_save();
}

1;