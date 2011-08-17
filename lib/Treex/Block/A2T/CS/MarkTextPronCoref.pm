package Treex::Block::A2T::CS::MarkTextPronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'model_path' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',

    #default => ''
    documentation => 'path to the trained model',
);

# TODO initialize ranker
# the best would be to pick among several rankers and corresponding models
has '_ranker' => (
    is       => 'ro',
    required => 1,

    #isa => '',
    builder => '_build_ranker'
);

sub _build_ranker {
    my ($self) = @_;

    log_fatal "File " . $self->model_path . " with pronominal coreference model doesn't exist."
        if ( !-e $self->model_path );

    #TODO
    return;    #PerceptronRanker->new( { model_path => $self->model_path } );
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
sub _get_ante_cands {
    my ($t_node) = @_;

    # current sentence
    my @sent_preceding = grep { $_->precedes($t_node) }
        $t_node->get_root->get_descendants( { ordered => 1 } );

    # previous sentence
    my $sent_num = $t_node->get_bundle->get_position;
    if ( $sent_num > 0 ) {
        my $prev_bundle = $t_node->get_document->get_bundles[ $sent_num - 1 ];
        my $prev_tree   = $prev_bundle->get_tree(
            $t_node->language,
            $t_node->get_layer,
            $t_node->selector
        );
        unshift @sent_preceding, $prev_tree->get_descendants( { ordered => 1 } );
    }
    else {

        # TODO
        # it should inform that the previous context is not complete
    }

    # semantic noun filtering
    my @cands = grep { $_->gram_sempos =~ /^n/ && $_->gram_person !~ /1|2/ }
        @curr_sent_preceding;

    # reverse to ensure the closer candidates to be indexed with lower numbers
    return reverse @cands;
}

sub _create_instances {
    my ( $anaphor, @ante_cands ) = @_;

    #TODO
}

before 'process_document' => sub {
    my $self = shift; 
    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );
    if ( !$document->get_bundles() ) {
        log_fatal "There are no bundles in the document and block " . $self->get_block_name() .
            " doesn't override the method process_document";
    }
    my @trees = map { $_->get_tree( 
        $self->$language, 't', $self->$selector ) }
        $document->get_bundles;

    my $fe = $self->feature_extractor;

    $collocations = $fe->count_collocations( \@trees );
    $np_freq = $fe->count_np_freq( \@trees );
    $fe->mark_sentence_nums( \@trees );
    $fe->mark_clause_nums( \@trees );
}

sub process_tnode {
    my ( $self, $t_node ) = @_;

    return if ( $t_node->is_root );

    if ( _is_anaphoric($t_node) ) {

        my @ante_cands = _get_ante_cands($t_node);

        # instances is a reference to hash in the form { id => instance }
        my $instances = _create_instances( $t_node, @ante_cands );

        # at this point we have to count on a very common case, when the true
        # antecedent lies in the previous sentence, which is however not
        # available (because of filtering and document segmentation)
        my $ranker = $self->_ranker;
        my $antec  = $ranker->pick_winner(@ante_cands);

        $t_node->set_deref_attr( 'coref_text.ref', [$antec] );
    }

}

1;

=over

=item Treex::Block::A2T::CS::MarkTextPronCoref


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
