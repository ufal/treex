package Treex::Tool::Tagger::LXTagger;
use Moose;
use File::Basename;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::ProcessUtils;
use Treex::Core::Resource;
use Data::Dumper;
with 'Treex::Tool::Tagger::Role';

has debug => ( isa => 'Bool', is => 'ro', required => 0, default => 1 );
has lxsuite_key => ( isa => 'Str', is => 'ro', required => 1 );
has num_tagged_sents => ( isa => 'Int', is => 'rw', required => 0, default => 0 );
has [qw( _reader _writer _pid )] => ( is => 'rw' );

sub tag_sentence {
    my $self = shift;
    my $toks = shift;
    my $ntoks = @$toks;
    my $to_tag = join(" ", @$toks);
    my $sentence_num = $self->num_tagged_sents + 1;
    $self->set_num_tagged_sents($sentence_num);
    print STDERR "LXTagger in     [$sentence_num]: $to_tag\n" if $self->debug;

    return [], [] if $ntoks == 0;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

    print $writer "$to_tag\n\n";
    my $tagged = <$reader>;
    while (!$tagged) { # discard empty lines
        $tagged = <$reader>;
    }

    die "Failed to read from LX-Suite tokenizer, better to kill oneself."
        if !defined $tagged;
    $tagged =~ s/\s+$//;
    print STDERR "LXTagger out    [$sentence_num]: $tagged\n" if $self->debug;
    my @tagged_toks = split(/[ ]+/, $tagged);
    my $ntags = @tagged_toks;

    die "Expecting $ntoks tagged toks, got: $ntags" if $ntags != $ntoks;

    my $tags = [];
    my $lemmas = [];
    foreach my $tagged_tok ( @tagged_toks ) {
        my @parts = split('/', $tagged_tok);
        my $tok = "";
        my $lemma = "_";
        my $tag = "_";
        if (@parts == 3) {
            ($tok, $lemma, $tag) = @parts;
        } elsif (@parts == 2) {
            ($tok, $tag) = @parts;
        } elsif (@parts == 1) {
            ($tok) = @parts;
        } else {
            die "Got invalid TOKEN/LEMMA/TAG triple: $tagged_tok";
        }
        #print STDERR "$tagged_tok => $tok, $lemma, $tag\n" if $self->debug;
        $tok = ".*/" if $tok eq ".*";
        push @$tags, $tag;
        push @$lemmas, $lemma;
    }

    print STDERR "LXTagger tags   [$sentence_num]: ".join(" ", @$tags)."\n" if $self->debug;
    print STDERR "LXTagger lemmas [$sentence_num]: ".join(" ", @$lemmas)."\n" if $self->debug;
    return ($tags, $lemmas);
}

sub BUILD {
    my $self = shift;
    my $client = require_file_from_share(
        "installed_tools/lxsuite_client.sh",
        ref( $self ),
    );
    my $key = $self->lxsuite_key;
    my $cmd = "$client $key plain:tagger:plain";
    my ( $reader, $writer, $pid ) =
        Treex::Tool::ProcessUtils::bipipe($cmd, ':encoding(utf-8)');
    $self->_set_reader( $reader );
    $self->_set_writer( $writer );
    $self->_set_pid( $pid );
}

sub DEMOLISH {
    my $self = shift;
    close( $self->_writer );
    close( $self->_reader );
    Treex::Tool::ProcessUtils::safewaitpid( $self->_pid );
    return;
}

1;

__END__

=head1 NAME

Tagger::LX_Suite

Wrapper around LX-Suite

Copyright 2014 Luís Gomes (NLX group @ FCUL)
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
