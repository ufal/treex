package Treex::Block::Eval::Coref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $tp_count  = 0;
my $src_count = 0;
my $ref_count = 0;

sub _is_it {
    my ($str) = @_;
    return ($str =~ /^[Ii]t$/);
}

sub _check_true_referential_node {
    my ($self, $ref_tnode) = @_;

    my @src_tnodes = $ref_tnode->get_aligned_nodes_of_type('monolingual');
    if (@src_tnodes > 1) {
        log_warn "Ref-node " . $ref_tnode->id . " aligned with several src-nodes";
    }
    my $src_tnode = shift @src_tnodes;

    my $refer = $src_tnode->wild->{referential};
    if (!defined $refer) {
        log_warn "Src-node " . $src_tnode->id . 
            " is aligned with ref-'it' but 'referential' flag is not assigned";
    }
    return $refer;
}

sub _check_true_pleonastic_node {
    my ($self, $ref_anode) = @_;

    my @src_anodes = $ref_anode->get_aligned_nodes_of_type('monolingual');
    if (@src_anodes > 1) {
        log_warn "Ref-node " . $ref_anode->id . " aligned with several src-nodes";
    }
    my $src_anode = shift @src_anodes;

    my $src_tnode = $src_anode->get_referencing_nodes('a/lex.rf');
    if ($src_anode->get_referencing_nodes('a/aux.rf')) {
        log_warn "Src-tnode " . $src_tnode->id . " is auxilliary";
    }

    my $refer = $src_tnode->wild->{referential};
    if (!defined $refer) {
        log_warn "Src-node " . $src_tnode->id . 
            " is aligned with ref-'it' but 'referential' flag is not assigned";
    }
    return $refer;
}

sub process_anode {
    my ($self, $ref_anode) = @_;

    # skip everything that is not "it"
    # TODO what about "It's" etc.
    return if (!_is_it($ref_anode->form));

    my @lex_tnodes = $ref_anode->get_referencing_nodes('a/lex.rf');
    
    # referential it
    if (@lex_tnodes > 0) {
        if (@lex_tnodes != 1) {
            log_warn "T-nodes " . (join ", ", (map {$_->id} @lex_tnodes)) . " point lexically to the same a-node";
        }
        my $lex_tnode = shift @lex_tnodes;
        
        # node was correctly labeled as referential
        if ($self->_check_true_referential_node($lex_tnode)) {
            $tp_count++;    # true positive
            $src_count++;   # positive
        }
        $ref_count++;   # true
    }
    
    # pleonastic it
    else {
        # true pleonastic was incorrectly labeled as referential
        if (!$self->_check_true_pleonastic_node($ref_anode)) {
            $src_count++;   # positive
        }
    }
}

sub process_end {
    my ($self) = shift;

    print join "\t", ($tp_count, $src_count, $ref_count);
    print "\n";
}

1;

=over

=item Treex::Block::Eval::ReferentialIt

Evaluation of "it" resolution - determining whether "it" is referential
or pleonastic. It returns three columns of aggregated counts - true positive,
positive and true, which must be then post-processed to compute P, R and F.

=back

=cut

# Copyright 2012 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
