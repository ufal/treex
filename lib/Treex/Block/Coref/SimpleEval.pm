package Treex::Block::Coref::SimpleEval;
use Moose;
use Moose::Util::TypeConstraints;
use List::MoreUtils qw/any/;
use Treex::Core::Common;
use Treex::Tool::Coreference::Utils;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Block::Write::BaseTextWriter';

subtype 'CommaArrayRef' => as 'ArrayRef';
coerce 'CommaArrayRef'
    => from 'Str'
    => via { [split /,/] };

has 'node_types' => ( is => 'ro', isa => 'CommaArrayRef', coerce => 1, default => '' ); 
has 'gold_selector' => ( is => 'ro', isa => 'Str', default => 'ref' );
has 'pred_selector' => ( is => 'ro', isa => 'Str', default => 'src' );
has '+extension' => ( default => '.tsv' );

has '_id_to_eid' => ( is => 'rw', isa => 'HashRef' );

sub build_id_to_entity {
    my ($chains) = @_;
    my %id_to_entity = ();
    my $id = 1;
    foreach my $chain (@$chains) {
        foreach my $mention (@$chain) {
            $id_to_entity{$mention->id} = $id;
        }
        $id++;
    }
    return \%id_to_entity;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;
    
    my @ref_ttrees = map {$_->get_tree($self->language, 't', $self->gold_selector)} $doc->get_bundles;
    my @ref_chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ref_ttrees);
    my $ref_id_to_entity = build_id_to_entity(\@ref_chains);
    $self->_set_id_to_eid($ref_id_to_entity);
};

sub process_bundle {
    my ($self, $bundle) = @_;

    my $ref_ttree = $bundle->get_tree($self->language, 't', $self->gold_selector);
    my $src_ttree = $bundle->get_tree($self->language, 't', $self->pred_selector);

    my %covered_src_nodes = ();
    foreach my $ref_tnode ($ref_ttree->get_descendants({ordered => 1})) {
        next if (!Treex::Tool::Coreference::NodeFilter::matches($ref_tnode, $self->node_types));

        my $ref_tnode_eid = $self->_id_to_eid->{$ref_tnode->id};
        my $gold_eval_class = defined $ref_tnode_eid ? 1 : 0;
        my ($ali_nodes, $ali_types) = $ref_tnode->get_undirected_aligned_nodes({language => $self->language, selector => $self->pred_selector});
        # process the ref nodes that have a src counterpart
        foreach my $ali_src_tnode (@$ali_nodes) {
            #printf STDERR "ALI SRC TNODE: %s\n", $ali_src_tnode->get_address;
            $covered_src_nodes{$ali_src_tnode->id}++;
            my @ali_src_antes = $ali_src_tnode->get_coref_nodes;
            my $pred_eval_class = @ali_src_antes ? 1 : 0;
            my $both_eval_class = 0;
            # both the src and the ref mentions are anaphoric - find out if they refer to the same antecedent
            if ($gold_eval_class && $pred_eval_class) {
                my @ali_ali_ref_antes = map {
                    my ($ali, $at) = $_->get_undirected_aligned_nodes({language => $self->language, selector => $self->gold_selector});
                    @$ali
                } @ali_src_antes;
                my @ali_ali_ref_antes_eids = grep {defined $_} map {$self->_id_to_eid->{$_->id}} @ali_ali_ref_antes;

                $both_eval_class = (any {$_ == $ref_tnode_eid} @ali_ali_ref_antes_eids) ? 1 : 0;
            }
            # both the src and the ref mentions are non-anaphoric
            elsif (!$gold_eval_class && !$pred_eval_class) {
                $both_eval_class = 1;
            }

            print {$self->_file_handle} join " ", ($gold_eval_class, $pred_eval_class, $both_eval_class, $ali_src_tnode->get_address);
            print {$self->_file_handle} "\n";
        }
        # process the ref nodes that have no src counterpart
        # considered correct if the ref node is non-anaphoric
        if (!@$ali_nodes) {
            #printf STDERR "NO SRC: %s %d\n", $ref_tnode->get_address, 1-$gold_eval_class;
            print {$self->_file_handle} join " ", ($gold_eval_class, 0, 1-$gold_eval_class, $ref_tnode->get_address);
            print {$self->_file_handle} "\n";
        }
    }
    foreach my $src_tnode ($src_ttree->get_descendants({ordered => 1})) {
        next if (defined $covered_src_nodes{$src_tnode->id});
        next if (!Treex::Tool::Coreference::NodeFilter::matches($src_tnode, $self->node_types));

        my @src_antes = $src_tnode->get_coref_nodes;
        my $pred_eval_class = $src_tnode->get_coref_nodes ? 1 : 0;
        # check if the generated node is not coreferential with the node that plays the same role (has the same parents and fills the same functor) in the reference
        my $both_eval_class = $self->_antes_play_the_same_role($src_tnode, @src_antes) ? 1 : 0;
        
        #printf STDERR "NO REF: %s %d\n", $src_tnode->get_address, 1-$pred_eval_class;
        
        print {$self->_file_handle} join " ", (0, $pred_eval_class, $both_eval_class, $src_tnode->get_address);
        print {$self->_file_handle} "\n";
    }
}

sub _antes_play_the_same_role {
    my ($self, $src_tnode, @src_antes) = @_;

    # monolingual alignment filter
    my $ali_filter = {language => $self->language, selector => $self->gold_selector};
    
    # from the given node, retrieve its parents' referntial counterparts
    return 0 if (!$src_tnode->is_generated);
    my @src_pars = $src_tnode->get_eparents;
    return 0 if (!@src_pars);
    my @ref_pars = map {my ($n, $t) = $_->get_undirected_aligned_nodes($ali_filter); @$n} @src_pars;
    return 0 if (!@ref_pars);

    # create an index of parents referential counterparts
    my %ref_pars_hash = map {$_->id => $_} @ref_pars;

    # find antecedents' referential counterparts of the given node
    my @ref_antes;
    my $curr_src_tnode = $src_tnode;
    do {
        my @src_antes = $curr_src_tnode->get_coref_nodes;
        @ref_antes = map {my ($n, $t) = $_->get_undirected_aligned_nodes($ali_filter); @$n} @src_antes;
        ($curr_src_tnode) = @src_antes;
    } while (defined $curr_src_tnode && !@ref_antes);

    # filter only those antecedents' refernetial counterparts that share the parent with the given node
    my @ref_same_par_antes = grep {
        my @ref_ante_pars = $_->get_eparents;
        (grep {defined $ref_pars_hash{$_->id}} @ref_ante_pars) ? 1 : 0
    } @ref_antes;

    # filter only those whose role is the same as the role of the given node
    my @ref_same_role_antes = grep {$_->functor eq $src_tnode->functor} @ref_same_par_antes;
    return (@ref_same_role_antes > 0);
}
 

# TODO: consider refactoring to produce the VW result format, which can be consequently processed by the MLyn eval scripts
# see Align::T::Eval for more

1;

=head1 NAME

Treex::Block::Coref::SimpleEval

=head1 DESCRIPTION

Precision, recall and F-measure for coreference.

=head1 SYNOPSIS

cd ~/projects/czeng_coref
treex -L cs 
    Read::Treex from=@data/cs/analysed/pdt/eval/0001/list 
    Util::SetGlobal selector=src 
    Coref::RemoveLinks type=all 
    A2T::CS::MarkRelClauseHeads 
    A2T::CS::MarkRelClauseCoref 
    Util::SetGlobal selector=ref 
    Coref::SimpleEval node_types='relpron,perspron'
| \$MLYN_DIR/scripts/eval.pl --prf --acc


=head1 METHODS

=over

=item _antes_play_the_same_role 

It checks, if a given generated node plays the same role as its antecedents.
This function is supposed to be tailored to automatically generated nodes
that can be possibly missing in the referential structure. However, a coreference
resolver might possibly reveal the actual identity of the node with its antecedent.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
