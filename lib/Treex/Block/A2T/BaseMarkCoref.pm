package Treex::Block::A2T::BaseMarkCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'model_path' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
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
    isa         => 'Treex::Tool::Coreference::CorefFeatures',
    builder     => '_build_feature_extractor',
);

has '_ante_cands_selector' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::AnteCandsGetter',
    builder     => '_build_ante_cands_selector',
);

has '_anaph_cands_filter' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::AnaphFilter',
    builder     => '_build_anaph_cands_filter',
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
    return log_fatal "method _build_ranker must be overriden in " . ref($self);
}
sub _build_feature_extractor {
    my ($self) = @_;
    return log_fatal "method _build_feature_extractor must be overriden in " . ref($self);
}
sub _build_ante_cands_selector {
    my ($self) = @_;
    return log_fatal "method _build_ante_cands_selector must be overriden in " . ref($self);
}
sub _build_anaph_cands_filter {
    my ($self) = @_;
    return log_fatal "method _build_anaph_cands_filter must be overriden in " . ref($self);
}


sub _create_instances {
    my ( $self, $anaphor, $ante_cands, $ords ) = @_;


    if (!defined $ords) {
        $ords = [ 0 .. @$ante_cands-1 ];
    }

    my $instances;
    #print STDERR "ANTE_CANDS: " . @$ante_cands . "\n";
    for (my $i = 0; $i < @$ante_cands; $i++) {
        my $cand = $ante_cands->[$i];
        my $fe = $self->_feature_extractor;
        my $features = $fe->extract_features( $cand, $anaphor, $ords->[$i] );
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
};

sub process_tnode {
    my ( $self, $t_node ) = @_;

    return if ( $t_node->is_root );

    if ( $self->_anaph_cands_filter->is_candidate( $t_node ) ) {

        my $ante_cands = $self->_ante_cands_selector->get_candidates( $t_node );

        # instances is a reference to a hash in the form { id => instance }
        my $instances = $self->_create_instances( $t_node, $ante_cands );

        # at this point we have to count on a very common case, when the true
        # antecedent lies in the previous sentence, which is however not
        # available (because of filtering and document segmentation)
        my $ranker = $self->_ranker;
        my $antec  = $ranker->pick_winner( $instances );

        # DEBUG
        #print "ANAPH: " . $t_node->id . "; ";
        #print "PRED: $antec\n";
        #print (join "\n", map {$_->id} @$ante_cands);
        #print "\n";

        # DEBUG
        #my $test_id = 't-ln95045-100-p2s1w13';
        #if (defined $instances->{$test_id}) {
        #    my $feat = $instances->{$test_id};

         #   foreach my $name (sort keys %$feat) {
         #       print $name . ": " . $feat->{$name} . "\n";
         #   }
            
        #}

        if (defined $antec) {
            $t_node->set_attr( 'coref_text.rf', [$antec] );
        }
    }
}

1;

=over

=item Treex::Block::A2T::BaseMarkCoref


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
