package Treex::Block::MLFix::Oracle;
use Moose;
use Treex::Core::Common;
use utf8;
use Lingua::Interset 2.050 qw(encode);

extends 'Treex::Block::MLFix::MLFix';

has ref_alignment_type => (
    is => 'rw',
    isa => 'Str',
    default => 'monolingual'
);

has ref_parent_constraint => (
    is => 'ro',
    isa => 'Bool',
    default => 1 
);


sub _load_models {
    my ($self) = @_;

    # Nothing to do here

    return ();
}

sub _get_predictions {
    my ($self, $instances) = @_;
    my @predictions = ();
 
    foreach my $inst (@$instances) {
        my $prediction = {};

        my $pred = join ";", map { defined $inst->{$_} ? $inst->{$_} : "" } @{ $self->config->{predict} };
        log_info($inst->{"old_node_form"});
        log_info($pred);
        $prediction = { "Oracle" => { $pred => 1 } };
        push @predictions, $prediction;
    }

    return \@predictions;
}

sub _predict_new_tags {
	my ($self, $node, $predictions) = @_;
	my %tags = ();

    my $model_name = "Oracle";
    foreach my $prediction (keys %{ $predictions->{$model_name} }) {
        my $iset_hash = $node->get_iset_structure();

        log_info("prediction: $prediction");
        log_info("old: " . $node->form . " - " . $node->tag);
        use Data::Dumper;
#        log_info("---");
#        log_info(Dumper($iset_hash));
#        my @pred_values = split /;/, $prediction;
#        my $iterator = List::MoreUtils::each_arrayref($self->config->{predict}, \@pred_values);
#        while ( my ($key, $value) = $iterator->() ) {
#            $key =~ s/new_node_//;
#            $iset_hash->{ $key } = $value;
#        }
        my @targets = @{ $self->config->{predict} };
        @$iset_hash{ map { s/new_node_//; $_; } @targets } = split /;/, $prediction;

#        log_info("+++");
#        log_info(Dumper($iset_hash));
#        foreach my $key (keys %$iset_hash) {
#            delete $iset_hash->{$key} if !defined $iset_hash->{$key} || $iset_hash->{$key} eq "";
#        }

#        log_info(Dumper($iset_hash));
        $node->set_iset($iset_hash);

        my $fs = Lingua::Interset::FeatureStructure->new();
        $fs->set_hash($iset_hash);

        my $tag = encode( $self->iset_driver, $fs );
        log_info("new: " . $node->form . " - $tag");
        $tags{$tag} = $predictions->{$model_name}->{$prediction};
        $self->chosen_model->{$node->id . " $tag"} = $model_name;
    }

	return \%tags;
}

sub get_instance_info {
    my ($self, $node) = @_;
    my ($node_ref) = $node->get_aligned_nodes_of_type($self->ref_alignment_type);

    my ($parent) = $node->get_eparents({
        or_topological => 1,
        ignore_incorrect_tree_structure => 1
    });
    my $parent_ref = undef;
    if (defined $node_ref) {
        ($parent_ref) = $node_ref->get_eparents( {or_topological => 1, ignore_incorrect_tree_structure => 1} );
    }
    if (!defined $parent_ref || $parent_ref->is_root()) {
        ($parent_ref) = $parent->get_aligned_nodes_of_type($self->ref_alignment_type) if defined $parent;
    }
   
    my $info = {};
    my $names = [ "node" ];
    my $no_grandpa = [ "node", "parent", "precchild", "follchild", "precsibling", "follsibling" ];
    if (
        defined $node_ref && !$node_ref->is_root() &&
        $node->lemma eq $node_ref->lemma
    ) {
#        $info = { "NULL" => "", "parentold_node_lemma" => "", "parentnew_node_lemma" => "" };

        # smtout (old) and ref (new) nodes info
        $self->node_info_getter->add_info($info, 'old', $node, $names);
        $self->node_info_getter->add_info($info, 'new', $node_ref, $names);

#        $self->node_info_getter->add_info($info, 'parentold', $parent, $no_grandpa)
#            if defined $parent && !$parent->is_root();
#        $self->node_info_getter->add_info($info, 'parentnew', $parent_ref, $no_grandpa)
#            if defined $parent_ref && !$parent->is_root();
    }
    else {
        # use the original categories if there isn't proper ref node available
        $self->node_info_getter->add_info($info, 'old', $node, $names);
        $self->node_info_getter->add_info($info, 'new', $node, $names);
    }
    return $info;
}

1;

=head1 NAME 

Treex::Block::MLFix::ScikitLearn -- base class using reference sentence information for morphology fixing

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

