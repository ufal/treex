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

            print {$self->_file_handle} join " ", ($gold_eval_class, $pred_eval_class, $both_eval_class);
            print {$self->_file_handle} "\n";
        }
        # process the ref nodes that have no src counterpart
        # considered correct if the ref node is non-anaphoric
        if (!@$ali_nodes) {
            printf STDERR "NO SRC: %s\n", $ref_tnode->id;
            print {$self->_file_handle} join " ", ($gold_eval_class, 0, 1-$gold_eval_class);
            print {$self->_file_handle} "\n";
        }
    }
    foreach my $src_tnode ($src_ttree->get_descendants({ordered => 1})) {
        next if (defined $covered_src_nodes{$src_tnode->id});
        next if (!Treex::Tool::Coreference::NodeFilter::matches($src_tnode, $self->node_types));
        
        printf STDERR "NO REF: %s\n", $src_tnode->id;
        
        my $pred_eval_class = $src_tnode->get_coref_nodes ? 1 : 0;
        print {$self->_file_handle} join " ", (0, $pred_eval_class, 1-$pred_eval_class);
        print {$self->_file_handle} "\n";
    }
}

# TODO: consider refactoring to produce the VW result format, which can be consequently processed by the MLyn eval scripts
# see Align::T::Eval for more

1;

=over

=item Treex::Block::Coref::SimpleEval

Precision, recall and F-measure for coreference.

USAGE:

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

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
