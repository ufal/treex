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

has 'follow_pred_chain_for_types' => (
    is => 'ro', isa => 'CommaArrayRef', coerce => 1, default => '',
    documentation => 'try following the coreferential chain if a predicted antecedent is of a certain type (e.g. relative pronouns and cors in the CoNLL2012 dataset, which have not been annotated)',
);

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
        # process only the gold nodes that match the node type
        next if (!Treex::Tool::Coreference::NodeFilter::matches($ref_tnode, $self->node_types));

        my $ref_tnode_eid = $self->_id_to_eid->{$ref_tnode->id};
        my $gold_eval_class = $ref_tnode->get_coref_nodes > 0 ? 1 : 0;
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
            my @ali_src_antes = $self->get_src_antes($ali_src_tnode);
            my ($pred_eval_class, $both_eval_class);
            # src counterpart is anaphoric
            if (@ali_src_antes) {
                $pred_eval_class = 1;
                $both_eval_class = $self->check_src_antes([$ref_tnode], \@ali_src_antes);
            }
            # src counterpart is not anaphoric
            else {
                $pred_eval_class = 0;
                $both_eval_class = ($pred_eval_class == $gold_eval_class) ? 1 : 0;
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

        my ($pred_eval_class, $both_eval_class);

        my @src_antes = $self->get_src_antes($src_tnode);
        $pred_eval_class = @src_antes ? 1 : 0;
        
        my ($ref_anaphs, $ali_types) = $src_tnode->get_undirected_aligned_nodes({language => $self->language, selector => $self->gold_selector});

        if (@$ref_anaphs) {
            $both_eval_class = $self->check_src_antes($ref_anaphs, \@src_antes);
        }
        else {
            $both_eval_class = @src_antes ? 0 : 1;
        }
        
        #printf STDERR "NO REF: %s %d\n", $src_tnode->get_address, 1-$pred_eval_class;
        
        print {$self->_file_handle} join " ", (0, $pred_eval_class, $both_eval_class, $src_tnode->get_address);
        print {$self->_file_handle} "\n";
    }
}

# return directly predicted antecedents, if follow_pred_chain_for_types is disabled
# return directly predicted antecedents, if there is no antecedent in a chain of any of the allowed types
#   - this ensures that such instance is still counted as predicted
# return first antecedents in a chain that are of any of the allowed types, otherwise
sub get_src_antes {
    my ($self, $src_anaph) = @_;
    my @src_antes_direct = $src_anaph->get_coref_nodes;
    return @src_antes_direct if (!@{$self->follow_pred_chain_for_types});

    #my %visited_ids = ( $src_anaph->id => 1 );
    my $debug = 0;
    if ($src_anaph->id eq "t_tree-en_src-s97-n3605") {
        $debug = 1;
    }
    print STDERR "ANAPH: ".$src_anaph->t_lemma."\n" if ($debug);

    my @src_antes = @src_antes_direct;
    print STDERR "ANTES: ".join(" ", map {$_->t_lemma} @src_antes)."\n" if ($debug);

    #$visited_ids{$_->id} = 1 foreach (@src_antes);
    while (@src_antes && all {Treex::Tool::Coreference::NodeFilter::matches($_, $self->follow_pred_chain_for_types)} @src_antes) {
        #print STDERR "ANTES: ".$src_anaph->id." -> ".(join " ", map {$_->id} @src_antes)."\n";
        @src_antes = map {$_->get_coref_nodes} @src_antes;
        print STDERR "ANTES: ".join(" ", map {$_->t_lemma} @src_antes)."\n" if ($debug);
        #$visited_ids{$_->id} = 1 foreach (@src_antes);
    }

    return @src_antes ? @src_antes : @src_antes_direct;
}

sub check_src_antes {
    my ($self, $ref_anaphs, $src_antes) = @_;

    my @ref_antes = map {
        my ($n, $t) = $_->get_undirected_aligned_nodes({language => $self->language, selector => $self->gold_selector}); 
        @$n
    } @$src_antes;
    
    my %ref_anaphs_id = map {$_->id => 1} @$ref_anaphs;
    return 1 if (any {$ref_anaphs_id{$_->id}} @ref_antes);
    
    my %ref_anaphs_eid = ();
    foreach my $ref_anaph (@$ref_anaphs) {
        my $anaph_eid = $self->_id_to_eid->{$ref_anaph->id};
        if (defined $anaph_eid) {
            $ref_anaphs_eid{$anaph_eid}++;
        }
    }
    return 1 if (any {
        my $ante_eid = $self->_id_to_eid->{$_->id}; 
        defined $ante_eid ? defined $ref_anaphs_eid{$ante_eid} : 0
    } @ref_antes);
    
    return 0;
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

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
