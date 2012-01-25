package Treex::Block::A2T::SRLParser;

use Moose;
use Treex::Core::Common;
use Treex::Tool::SRLParser::FeatureExtractor;
use Treex::Tool::SRLParser::PredicateIdentifier;

use lib '/net/projects/tectomt_shared/external_libs/';
use MaxEntToolkit;

extends 'Treex::Core::Block';

has 'empty_sign' => (
    is      => 'rw',
    isa     => 'Str',
    default => '_',
);

has 'feature_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

my $model;

sub BUILD {
    my ($self, @params) = @_;

    if (!$model) {
        $model = MaxEntToolkit::MaxentModel->new();
        # TODO make 'model' parameters
        $model->load("$ENV{TMT_ROOT}/share/data/models/srl_parser/srl_parser_model_cs");
    }
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my $feature_extractor = Treex::Tool::SRLParser::FeatureExtractor->new();
    my $predicate_identifier = Treex::Tool::SRLParser::PredicateIdentifier->new();
    
    my @a_nodes = $a_root->get_descendants;
    my %semantic_dependencies;
    my %id_to_a_node;
    my %has_parent;

    # predict labels with MaxEntToolkit
    foreach my $predicate (@a_nodes) {
        next if not $predicate_identifier->is_predicate($predicate);

        foreach my $depword (@a_nodes) {
            my @features = split /\s+/, $feature_extractor->extract_features($predicate, $depword);

            # TODO Use whole distribution (returned by eval_all).
            my $label = $model->predict(\@features);
            
            if ($label ne $self->empty_sign) {
                $semantic_dependencies{$predicate->id} = {} if not exists $semantic_dependencies{$predicate->id};
                $semantic_dependencies{$predicate->id}{$depword->id} = $label;
                $id_to_a_node{$predicate->id} = $predicate;
                $id_to_a_node{$depword->id} = $depword;
                $has_parent{$depword->id} = 1;
            } 
        }
    }

    # TODO submit to lpsolve to globally optimize labels
    # For now, we are using values predicted by MaxEntToolkit.

    # build t-root
    my $zone = $a_root->get_zone;
    my $t_root = $zone->create_ttree;
    $t_root->set_deref_attr( 'atree.rf', $a_root );

    # build t-tree
    my $visited_ref = {};

    # First, attach predicates without parent to t-root
    foreach my $predicate_id (keys %semantic_dependencies) {
        if (not exists $has_parent{$predicate_id} and not exists $visited_ref->{$predicate_id}) {
            _build_subtree($predicate_id, $t_root, "", $visited_ref, \%semantic_dependencies, \%id_to_a_node);
        }
    }

    # Now, run DFS to build t-tree
    foreach my $predicate_id (keys %semantic_dependencies) {
        if (not exists $visited_ref->{$predicate_id}) {
            _build_subtree($predicate_id, $t_root, "", $visited_ref, \%semantic_dependencies, \%id_to_a_node);
        }
    }

    $t_root->_normalize_node_ordering();
}

# DFS subroutine to build t-subtree
sub _build_subtree {
    my ($predicate_id, $t_parent, $functor, $visited_ref, $semantic_dependencies_ref, $id_to_a_node_ref) = @_;
  
    $visited_ref->{$predicate_id} = 1;
    my $t_node = $t_parent->create_child();
    $t_node = _add_anode_to_tnode($id_to_a_node_ref->{$predicate_id}, $t_node);
    $t_node->set_functor($functor) if length $functor;
  
    while (my ($child_id, $functor) = each %{$semantic_dependencies_ref->{$predicate_id}}) {
        next if exists $visited_ref->{$child_id};
        _build_subtree($child_id, $t_node, $functor, $visited_ref, $semantic_dependencies_ref, $id_to_a_node_ref);
    }
}

sub _add_anode_to_tnode {
    my ( $a_node, $t_node ) = @_; 

    # We know that we are adding only lexical nodes,
    # so we do not bother with auxiliary ones.
    $t_node->set_lex_anode($a_node);
    $t_node->_set_ord($a_node->ord);
    $t_node->set_t_lemma($a_node->lemma);

    return $t_node;
}
 
1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SRLParser

=head1 DESCRIPTION

SRL parser according to (L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>).

=head1 PARAMETERS

=over

=item feature_delim

Delimiter between features. Default is space, because Maximum Entropy Toolkit
expects spaces between features. 

=item empty_sign

A string for denoting empty or undefined values, such as no semantic relation
in a t-tree, no syntactic relation in an a-tree, empty values for features, etc.

=back

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
