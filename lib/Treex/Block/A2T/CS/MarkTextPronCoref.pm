package Treex::Block::A2T::CS::MarkTextPronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::PerceptronRanker;
use Treex::Tool::Coreference::PronCorefFeatures;
use Treex::Tool::Coreference::TextPronAnteCandsGetter;

has 'model_path' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',

    default => 'data/models/coreference/CS/perceptron/text.perspron.gold',
    documentation => 'path to a trained model',
);

# TODO  the best would be to pick among several rankers and corresponding models
has '_ranker' => (
    is          => 'ro',
    required    => 1,

    isa         => 'Treex::Tool::Coreference::Ranker',
    lazy        => 1,
    builder     => '_build_ranker'
);

has '_feature_extractor' => (
    is          => 'ro',
    required    => 1,
# TODO this should be a role, not a concrete class
    isa         => 'Treex::Tool::Coreference::PronCorefFeatures',
    builder     => '_build_feature_extractor',
);

has '_ante_cands_selector' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::AnteCandsGetter',
    builder     => '_build_ante_cands_selector',
);

# Attribute _ranker depends on the attribute model_path, whose value do not
# have to be accessible when building other attributes. Thus, _ranker is
# defined as lazy, i.e. it is built during its first access. However, we wish all
# models to be loaded while initializing a block. Following hack ensures it.
sub BUILD {
    my ($self) = @_;

    $self->_ranker;
}

sub _build_ranker {
    my ($self) = @_;
    my $ranker = Treex::Tool::Coreference::PerceptronRanker->new( 
        { model_path => $self->model_path } 
    );
    return $ranker;
}

sub _build_feature_extractor {
    my ($self) = @_;
    my $fe = Treex::Tool::Coreference::PronCorefFeatures->new();
    return $fe;
}

sub _build_ante_cands_selector {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::TextPronAnteCandsGetter->new();
    return $acs;
}

# according to rule presented in Nguy et al. (2009)
# nodes with the t_lemma #PersPron and third person in gram/person
sub _is_anaphoric {
    my ($t_node) = @_;

    return ( $t_node->t_lemma eq '#PersPron' && $t_node->gram_person eq '3' );
}

# according to rule presented in Nguy et al. (2009)
# semantic nouns from previous context of the current sentence and from
# the previous sentence
# TODO think about preparing of all candidates in advance
sub _get_ante_cands {
    my ($self, $t_node) = @_;

    my $acs = $self->_ante_cands_selector;
    return $acs->get_candidates( $t_node );
}

sub _create_instances {
    my ( $self, $anaphor, $ante_cands, $ords ) = @_;

    if (!defined $ords) {
        $ords = [ 1 .. scalar @$ante_cands ];
    }

    my $instances;
    for (my $i; $i < @$ante_cand; $i++) {
        my $cand = $ante_cands->[$i];
        my $fe = $self->_feature_extractor;
        my $features = $fe->extract_features( $cand, $anaphor, $ord->[$i] );
        $instances->{ $cand->id } = $features;
    }
    return $instances;
}

before 'process_document' => sub {
    my ($self, $document) = @_;

    if ( !$document->get_bundles() ) {
        return;
    }
    my @trees = map { $_->get_tree( 
        $self->language, 't', $self->selector ) }
        $document->get_bundles;

    my $fe = $self->_feature_extractor;

    $fe->count_collocations( \@trees );
    $fe->count_np_freq( \@trees );
    $fe->mark_doc_clause_nums( \@trees );
    $fe->mark_doc_deepord( \@trees );
};

sub process_tnode {
    my ( $self, $t_node ) = @_;

    return if ( $t_node->is_root );

    if ( _is_anaphoric($t_node) ) {

        my $ante_cands = $self->_get_ante_cands($t_node);

        # instances is a reference to a hash in the form { id => instance }
        my $instances = $self->_create_instances( $t_node, $ante_cands );

        # at this point we have to count on a very common case, when the true
        # antecedent lies in the previous sentence, which is however not
        # available (because of filtering and document segmentation)
        my $ranker = $self->_ranker;
        my $antec  = $ranker->pick_winner( $instances );

        $t_node->set_attr( 'coref_text.ref', [$antec] );
    }
}

1;

=over

=item Treex::Block::A2T::CS::MarkTextPronCoref


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
