package Treex::Block::W2A::EN::TagMorce;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has _tagger => ( is => 'rw' );
has _n_tagged => ( is => 'rw' );

use Morce::English;
use Treex::Tool::Transliteration::DowngradeUTF8forISO2;

sub BUILD {
    my ($self) = @_;

    return;
}

sub construct_tagger {
    my ($self) = @_;
    my $tagger = Morce::English->new();
    log_fatal("Cannot initialize Morče") if(!defined($tagger));
    $self->_set_tagger($tagger);
    $self->_set_n_tagged(0);
    return $tagger;
}

sub process_start {
    my ($self) = @_;
    $self->construct_tagger();
    $self->SUPER::process_start();
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    # The more sentences tagged, the more memory Morče consumes (a memory leak in Morče?)
    # Kill the tagger process every N sentences to prevent us from dying on memory shortage.
    if ( $self->{_n_tagged} > 10000 ) {
        ###!!! BEWARE: This does not work! After loading the new Morče, Treex throws "Segmentation fault".
        ###!!! Currently the only workaround is not to ask Treex to tag too many documents at once
        ###!!! (i.e., call Treex repeatedly).
        ###!!! Also consider using Featurama instead. It ought to be a cleaner reimplementation of Morče.
        #log_info("Reached 10000 tagged sentences, restarting Morče to save memory.");
        #delete($self->{_tagger});
        #$self->construct_tagger();
    }

    my @a_nodes = $atree->get_descendants( { ordered => 1 } );
    my @forms =
        map { substr( $_, -45, 45 ) }                                       # avoid words > 45 chars; Morce segfaults
        map { Treex::Tool::Transliteration::DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) }
        @a_nodes;

    # get tags
    # Morče still fails occasionally. Output all sentences in order to identify the one that causes the failure.
    # (But the process could also die because of lack of memory. Be default, treex -p asks for 2G, which may not be enough.)
#    log_info('Tagging sentence: '.join(' ', @forms).' ('.scalar(@forms).' tokens)');
    # Morče works with sentences of limited size. Avoid submitting long sentences.
    my $max_sentence_size = 500;
    my ($tags_rf, $lemmas_rf);
    my @tags;
    if ( scalar(@forms) > $max_sentence_size ) {
        my $n_parts = scalar(@forms) / $max_sentence_size + 1;
        for ( my $i = 0; $i < $n_parts; $i++ ) {
            my $j0 = $i * $max_sentence_size;
            my $j1 = ($i + 1) * $max_sentence_size - 1;
            $j1 = $#forms if($j1>$#forms);
            my @forms_part = @forms[$j0..$j1];
            my ($tags_rf_part, $lemmas_rf_part) = $self->_tagger->tag_sentence( \@forms_part );
            my $nf = scalar(@forms_part);
            my $nt = scalar(@{$tags_rf_part});
            if($nt != $nf) {
                log_fatal("Number of tags in tagged part differs from number of tokens. TOKENS: $nf; TAGS: $nt.");
            }
            push( @tags, @{$tags_rf_part} );
        }
        $tags_rf = \@tags;
    }
    else {
        ($tags_rf, $lemmas_rf) = $self->_tagger->tag_sentence( \@forms );
    }
    if ( @$tags_rf != scalar(@forms) ) {
        my $nf = scalar(@forms);
        my $nt = scalar(@{$tags_rf});
        log_fatal "Different number of tokens and tags. TOKENS: $nf, TAGS: $nt";
    }

    # fill tags
    foreach my $a_node (@a_nodes) {
        $a_node->set_tag( shift @$tags_rf );
    }

    # Update number of sentences tagged with the current instance of the tagger.
    $self->{_n_tagged}++;
    return 1;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::EN::TagMorce

Each node in analytical tree is tagged using C<Morce::English> (Penn Treebank POS tags).
This block does NOT do lemmatization.

=back

=cut

# Copyright 2011, 2012 David Mareček, Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
