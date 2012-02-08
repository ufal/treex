package Treex::Block::Eval::ReferentialIt;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'print_types' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
);

has 'segmref_as_pleo' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
);


my $noprint_stack = 1;
log_set_error_level('DEBUG');

my $tp_count  = 0;
my $src_count = 0;
my $ref_count = 0;

sub _is_it {
    my ($str) = @_;
    return ($str =~ /^[Ii]t$/);
}

sub _get_src_tnode_for_lex {
    my ($self, $ref_tnode) = @_;

    my @src_tnodes = $ref_tnode->get_aligned_nodes_of_type('monolingual');
    if (@src_tnodes > 1) {
        log_debug "Ref-node " . $ref_tnode->id . " aligned with several src-nodes", $noprint_stack;
    }
    my $src_tnode = shift @src_tnodes;
    return $src_tnode;
}

sub _get_src_tnode_for_aux {
    my ($self, $ref_anode) = @_;

    my @src_anodes = $ref_anode->get_aligned_nodes_of_type('monolingual');
    if (@src_anodes > 1) {
        log_debug "Ref-node " . $ref_anode->id . " aligned with several src-nodes", $noprint_stack;
    }
    my $src_anode = shift @src_anodes;

    my ($src_tnode) = $src_anode->get_referencing_nodes('a/lex.rf');
    my ($src_aux_tnode) = $src_anode->get_referencing_nodes('a/aux.rf');
    if (defined $src_aux_tnode) {
        log_debug "Src-tnode " . $src_aux_tnode->id . " is auxilliary", $noprint_stack;
    }

    if (!defined $src_tnode) {
        $src_tnode = $src_aux_tnode;
        log_debug "Src-tnode does not exist for the src-anode " . $src_anode->id, $noprint_stack;
    }
    return $src_tnode;
}

sub _is_referential {
    my ($self, $src_tnode) = @_;

    my $refer = $src_tnode->wild->{referential};
    if (!defined $refer) {
        log_debug "Src-node " . $src_tnode->id . 
            " is aligned with ref-'it' but 'referential' flag is not assigned", $noprint_stack;
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
            log_debug "T-nodes " . (join ", ", (map {$_->id} @lex_tnodes)) . " point lexically to the same a-node", $noprint_stack;
        }
        my $lex_tnode = shift @lex_tnodes;

        if ($self->print_types) {
            my @coref_tnodes = $lex_tnode->get_coref_nodes;
            if (@coref_tnodes > 0) {
                print "LEX WITH COREF\n"
            }
            else {
                print "LEX WITHOUT COREF\n";
            }
            return;
        }
            
        my $src_tnode = $self->_get_src_tnode_for_lex($lex_tnode);
        # node was incorrectly labeled as pleonastic (or correctly as reffering to a segment)
        my $is_pleo =  !$self->_is_referential($src_tnode);
        
        if ($self->segmref_as_pleo) {
            my @antes_ref = $lex_tnode->get_coref_nodes;
            # it really refers to a larger segment
            if (@antes_ref == 0) {
                # correctly marked as pleonastic
                if ($is_pleo) {
                    $tp_count++;    # true positive
                }
                $ref_count++;   # true
            }
        }
        # marked as pleonastic
        if ($is_pleo) {
            $src_count++;   # positive
        }
    }
    
    # pleonastic it
    else {
        if ($self->print_types) {
            print "AUX\n";
            return;
        }

        my $src_tnode = $self->_get_src_tnode_for_aux($ref_anode);
        # node was correctly labeled as pleonastic
        if (!$self->_is_referential($src_tnode)) {
            $tp_count++;    # true positive
            $src_count++;   # positive
        }
        $ref_count++;   # true
    }
}

sub process_end {
    my ($self) = shift;

    return if ($self->print_types);

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
