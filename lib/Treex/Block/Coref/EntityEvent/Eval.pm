package Treex::Block::Coref::EntityEvent::Eval;
use Moose;
use Moose::Util::TypeConstraints;
use List::MoreUtils qw/any/;
use Treex::Core::Common;
use Treex::Tool::Coreference::Utils;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Block::Write::BaseTextWriter';

subtype 'NodeTypeCommaArrayRef' => as 'ArrayRef';
coerce 'NodeTypeCommaArrayRef'
    => from 'Str'
    => via { [split /,/] };

has 'node_types' => ( is => 'ro', isa => 'NodeTypeCommaArrayRef', coerce => 1, default => '' ); 
has 'gold_selector' => ( is => 'ro', isa => 'Str', default => 'ref' );
has 'pred_selector' => ( is => 'ro', isa => 'Str', default => 'src' );
has '+extension' => ( default => '.tsv' );

sub process_bundle {
    my ($self, $bundle) = @_;

    my $ref_ttree = $bundle->get_tree($self->language, 't', $self->gold_selector);
    my $src_ttree = $bundle->get_tree($self->language, 't', $self->pred_selector);

    my %covered_src_nodes = ();
    foreach my $ref_tnode ($ref_ttree->get_descendants({ordered => 1})) {
        # process only the gold nodes that match the node type
        next if (!Treex::Tool::Coreference::NodeFilter::matches($ref_tnode, $self->node_types));

        my $gold_eval_class = $ref_tnode->wild->{entity_event} // "OTHER";
                
        my ($ali_nodes, $ali_types) = $ref_tnode->get_undirected_aligned_nodes({language => $self->language, selector => $self->pred_selector});
        # process the ref nodes that have a src counterpart
        for (my $i = 0; $i < @$ali_nodes; $i++) {
            my $ali_src_tnode = $ali_nodes->[$i];
            # do not process it if a loosely aligned node does not match the node type
            # tightly aligned counterparts that do not match the node type must be processed
            # e.g. if a Czech perspron "je" is mislabeled as a verb "byt" in src
            next if (!Treex::Tool::Coreference::NodeFilter::matches($ali_src_tnode, $self->node_types) && $ali_types->[$i] eq 'monolingual.loose');
            #printf STDERR "ALI SRC TNODE: %s\n", $ali_src_tnode->get_address;
            $covered_src_nodes{$ali_src_tnode->id}++;
            
            my $pred_eval_class = $ali_src_tnode->wild->{entity_event} // "OTHER";

            print {$self->_file_handle} join " ", ($gold_eval_class, $pred_eval_class, $ali_src_tnode->get_address);
            print {$self->_file_handle} "\n";
        }
        # process the ref nodes that have no src counterpart
        # considered correct if the ref node is non-anaphoric
        if (!@$ali_nodes) {
            #printf STDERR "NO SRC: %s %d\n", $ref_tnode->get_address, 1-$gold_eval_class;
            print {$self->_file_handle} join " ", ($gold_eval_class, "OTHER", $ref_tnode->get_address);
            print {$self->_file_handle} "\n";
        }
    }
    foreach my $src_tnode ($src_ttree->get_descendants({ordered => 1})) {
        next if (defined $covered_src_nodes{$src_tnode->id});
        next if (!Treex::Tool::Coreference::NodeFilter::matches($src_tnode, $self->node_types));

        my $pred_eval_class = $src_tnode->wild->{entity_event} // "OTHER";
        
        #printf STDERR "NO REF: %s %d\n", $src_tnode->get_address, 1-$pred_eval_class;
        
        print {$self->_file_handle} join " ", ("OTHER", $pred_eval_class, $src_tnode->get_address);
        print {$self->_file_handle} "\n";
    }
}

1;

=head1 NAME

Treex::Block::Coref::EntityEvent::Eval

=head1 DESCRIPTION

Evaluation of anaphor classification, whether it refers to an entity (ENTITY), event (EVENT) or
is either exophoric or non-anaphoric (OTHER).
For instances with no counterpart in either automatic or gold trees, a class OTHER is assigned.
Block C<Treex::Block::Coref::EntityEvent::IndicateForCoref> must be run on gold selector
before running this block.

=head1 SYNOPSIS

TODO: change synopsis

cd ~/projects/czeng_coref
treex -L cs 
    Read::Treex from=@data/cs/analysed/pdt/eval/0001/list 
    Util::SetGlobal selector=src 
    Coref::RemoveLinks type=all
    Coref::EntityEvent::CS::DemonPron::Resolve
    Util::SetGlobal selector=ref
    Coref::EntityEvent::IndicateForCoref
    Coref::EntityEvent::Eval node_types='demonpron'
| \$MLYN_DIR/scripts/eval.pl --prf --acc

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
