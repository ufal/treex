package Treex::Block::SemevalABSA::MarkSentiment;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has lemmas => (
    isa => 'HashRef',
    is  => 'rw',
);

has forms => (
    isa => 'HashRef',
    is  => 'rw',
);

has lexicon_file => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
);

has use_wild => (
    isa =>  'Bool',
    default => 1,
    is => 'rw',
);

sub BUILD {
    my ( $self ) = @_;
    open( my $lexhdl, $self->{lexicon_file} ) or log_fatal "$self->{lexicon_file}: $!";
    while (<$lexhdl>) {
        chomp;
        my ( $form, $lemma, $tag, $polarity ) = split /\|/;
        log_fatal "Bad format of line '$_' in $self->{lexicon_file}" if ! $polarity;
        $self->{forms}->{$form} = $polarity;
        $self->{lemmas}->{$lemma} = $polarity;
    }
    close $lexhdl;
    return 1;
}

sub process_anode {
    my ( $self, $anode ) = @_;   

    if ( $self->{forms}->{$anode->form} ) {
        $self->mark_node( $anode, $self->{forms}->{$anode->form} );
    } elsif ( $self->{lemmas}->{$anode->lemma} ) {
        $self->mark_node( $anode, $self->{lemmas}->{$anode->lemma} );
    }
    return 1;
}

sub mark_node {
    my ( $self, $node, $polarity ) = @_;
    if ( $self->use_wild ) {
        $node->wild->{'absa_is_subjective'} = 1;
        $node->wild->{'absa_polarity'} = $polarity;
    } else {
        $node->set_form( $node->form . '#SUBJ#' . $polarity );
        $node->set_lemma( $node->lemma . '#SUBJ#' . $polarity );
    }
    return 1;
}

1;
