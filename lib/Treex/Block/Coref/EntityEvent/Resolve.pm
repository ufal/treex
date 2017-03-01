package Treex::Block::Coref::EntityEvent::Resolve;
use Moose;
use Treex::Core::Common;
use Treex::Block::Coref::EntityEvent::IndicateForCoref;

extends 'Treex::Core::Block';
with 'Treex::Block::Coref::SupervisedBase';

has 'model_path' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
    documentation => 'path to a trained model',
);

has 'diagnostics' => ( is => 'ro', isa => 'Bool', default => 0);

# TODO  the best would be to pick among several rankers and corresponding models
has '_ranker' => (
    is          => 'ro',
    required    => 1,

    isa         => 'Treex::Tool::ML::Ranker',
    lazy        => 1,
    builder     => '_build_ranker'
);

# Attribute _ranker depends on the attribute model_path, whose value do not
# have to be accessible when building other attributes. Thus, _ranker is
# defined as lazy, i.e. it is built during its first access. However, we wish all
# models to be loaded while initializing a block. Following hack ensures it.
sub BUILD {
    my ($self) = @_;

    $self->_ranker;
    $self->_feature_extractor;
    $self->_ante_cands_selector;
}

sub _build_ranker {
    my ($self) = @_;
    return log_fatal "method _build_ranker must be overriden in " . ref($self);
}

sub process_document_one_zone_at_time {
    my ($self, $doc) = @_;
    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
    $self->SUPER::process_document($doc);
    return;
}

sub process_document {
    my ($self, $doc) = @_;
    $self->_apply_function_on_each_zone($doc, \&process_document_one_zone_at_time, $self, $doc);
    return;
}

sub process_filtered_tnode {
    my ( $self, $t_node ) = @_;

    return if ( $t_node->is_root );
   
    my @ante_cands = $self->_ante_cands_selector->get_candidates( $t_node );
    my @ee_cands = map {Treex::Block::Coref::EntityEvent::IndicateForCoref::is_event($_) ? "EVENT" : "ENTITY"} @ante_cands;

    if ($self->diagnostics) {
        $t_node->wild->{coref_diag}{is_anaph} = 1;
        $_->wild->{coref_diag}{cand_for}{$t_node->id} = 1 foreach (@ante_cands);
    }

# DEBUG
    #my $debug = 0;
    #if ($t_node->id eq "t_tree-cs_src-s9_1of2-n886") {
    #    $debug = 1;
    #}

    my $ee_inst_order = ["ENTITY", "EVENT"];
    my $ee_cands_struct = [ $ee_inst_order, \@ee_cands ];
    my ($instances) = $self->get_features_comments( $t_node, \@ante_cands, $ee_cands_struct);

    #if ($debug) {
    #    print STDERR Dumper($instances);
    #}

    # at this point we have to count on a very common case, when the true
    # antecedent lies in the previous sentence, which is however not
    # available (because of filtering and document segmentation)
    my $ranker = $self->_ranker;
    my ($ante_idx, $ante_prob)  = $ranker->pick_winner( $instances );

    return if (!defined $ante_idx);

    $t_node->wild->{entity_event} = (($ante_idx > 0) ? $ee_inst_order->[$ante_idx-1] : undef);
    $t_node->wild->{entity_event_prob} = $ante_prob;

# DEBUG
#        my $antec  = $ranker->pick_winner( $instances, $debug );

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

}

1;
#TODO adjust documentation

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::Resolve

=head1 DESCRIPTION

A base class for all textual coreference resolution blocks. 
It combines the following modules:
* anaphor candidate filter - it determines the nodes, for which an antecedent will be seleted
* antecedent candidate selector - for each anaphor, it selects a bunch of antecedent candidates
* feature extractor - it extracts features that describe an anaphor - antecedent candidate couple
* ranker - it ranks the antecedent candidates based on the feature values
ID of the predicted antecedent is filled in the anaphor's 'coref_text.rf' attribute.

=head1 PARAMETERS

=over

=item model_path

The path of the model used for resolution.

=item anaphor_as_candidate

If enabled, the block provides joint anaphoricity determination and antecedent selection.
If disabled, this block must be preceded by a block resolving anaphoricity of anaphor candidates. 

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
