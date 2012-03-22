package Treex::Block::Eval::ReferentialIt;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use List::MoreUtils qw/ uniq /;

has 'print_types' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
);

has 'exo_as_pleo' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
    documentation => "Treat non-anaphoric (e.g. exophoric) 'it' as pleonastic",
);

has 'verb_child' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
    documentation => "Examination is conducted just for those 'it' that are governed by a verb",
);

has 'attr_name' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    default => 'referential',
    documentation => "The name of the wild attribute that contains referential info",
);

# confusion matrix indexed with {real_value}{predicted_value}
has '_confusion_matrix' => (
    is  => 'rw',
    isa => 'HashRef[HashRef[Int]]',
    default => sub {{}},
);

my $noprint_stack = 1;
log_set_error_level('DEBUG');

sub _is_it {
    my ($anode) = @_;
    #return ($anode->form =~ /^[Ii]t$/);
    return ($anode->lemma eq 'it');
}

sub _is_verb_child {
    my ($anode) = @_;
    
    # get tnode for anode
    my ($tnode) = grep {defined $_} (map {$anode->get_referencing_nodes($_)} ('a/lex.rf', 'a/aux.rf'));
    my $verb;

    if (!defined $tnode) {
        print STDERR "TNODE UNDEF: " . $anode->id . "\n";
    }

    if ( $tnode->t_lemma ne "#PersPron" ) {
        $verb = $tnode;
    }
    else {
        ($verb) = $tnode->get_eparents( { or_topological => 1} );
    }
    return (($verb->gram_sempos || "") eq "v") && (!$tnode->is_generated);
}

sub _get_src_tnode_for_lex {
    my ($self, $ref_tnode) = @_;

    my @src_tnodes = $ref_tnode->get_aligned_nodes_of_type('monolingual');
    if (@src_tnodes == 0) {
        log_debug "Ref-node " . $ref_tnode->id . " aligned with no src-node", $noprint_stack;
    }
    if (@src_tnodes > 1) {
        log_debug "Ref-node " . $ref_tnode->id . " aligned with several src-nodes", $noprint_stack;
    }
    my $src_tnode = shift @src_tnodes;
    return $src_tnode;
}

sub _get_src_tnode_for_aux {
    my ($self, $ref_anode) = @_;

    my @src_anodes = $ref_anode->get_aligned_nodes_of_type('monolingual');
    if (@src_anodes == 0) {
        log_debug "Ref-node " . $ref_anode->id . " aligned with no src-node", $noprint_stack;
        return undef;
    }
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

    if (!defined $src_tnode) {
        print STDERR "NO COUNTERPART IN SRC\n";
        return 0;
    }

    my $refer = $src_tnode->wild->{$self->attr_name};
    if (!defined $refer) {
        log_debug "Src-node " . $src_tnode->id . 
            " is aligned with ref-'it' but 'referential' flag is not assigned", $noprint_stack;
    }
    return $refer;
}

sub _print_confusion_matrix {
    my ($self, $size) = @_;

    my $conf_mat = $self->_confusion_matrix;

    my @true_values = keys %$conf_mat;
    my @pred_values = uniq( map {keys %{$conf_mat->{$_}}} @true_values);

    # print the top header
    printf STDERR "%*s", $size, ""; 
    foreach my $pred (@pred_values) {
        printf STDERR "%*s", $size, $pred; 
    }
    print STDERR "\n"; 

    # print the rest of the table
    foreach my $true (@true_values) {
        # print the left header
        printf STDERR "%*s", $size, $true;
        foreach my $pred (@pred_values) {
            # print the body of the table
            printf STDERR "%*s", $size, $conf_mat->{$true}{$pred}; 
        }
        print STDERR "\n";
    }
}

sub process_anode {
    my ($self, $ref_anode) = @_;
    my $conf_mat = $self->_confusion_matrix;

    # skip everything that is not "it"
    # TODO what about "It's" etc.
    return if (!_is_it($ref_anode));

    # evaluate just those geverned by a verb
    return if ($self->verb_child && !_is_verb_child($ref_anode));

    my @lex_tnodes = $ref_anode->get_referencing_nodes('a/lex.rf');
    
    # referential it
    if (@lex_tnodes > 0) {
        if (@lex_tnodes != 1) {
            log_debug "T-nodes " . (join ", ", (map {$_->id} @lex_tnodes)) . " point lexically to the same a-node", $noprint_stack;
        }
        my $lex_tnode = shift @lex_tnodes;
            
        my $src_tnode = $self->_get_src_tnode_for_lex($lex_tnode);
        if (!defined $src_tnode) {
            log_debug "LEX TNODE UNDEF", $noprint_stack;
        }
        # node was incorrectly labeled as pleonastic (or correctly as reffering to a segment)
        my $is_ref_pred =  $self->_is_referential($src_tnode);
        my @antes_ref = $lex_tnode->get_coref_nodes;

        
        if (@antes_ref == 0) {
            if ($is_ref_pred) {
                $conf_mat->{'exo'}{'ref'}++;
            }
            else {
                $conf_mat->{'exo'}{'pleo'}++;
                #print STDERR "PROB: " . $src_tnode->wild->{referential_prob} . "\n";
                #print STDERR "ID: " . $src_tnode->id . "\n";
            }
        }
        else {
            if ($is_ref_pred) {
                $conf_mat->{'ref'}{'ref'}++;
            }
            else {
                $conf_mat->{'ref'}{'pleo'}++;
            }
        }
    }
    
    # pleonastic it
    else {
        my $src_tnode = $self->_get_src_tnode_for_aux($ref_anode);
        if (!defined $src_tnode) {
            log_debug "AUX TNODE UNDEF", $noprint_stack;
        }
        # node was correctly labeled as pleonastic
        if ($self->_is_referential($src_tnode)) {
            $conf_mat->{'pleo'}{'ref'}++;
        }
        else {
            $conf_mat->{'pleo'}{'pleo'}++;
                #print STDERR "PROB: " . $src_tnode->wild->{referential_prob} . "\n";
        }
    }
}

sub process_end {
    my ($self) = shift;

    return if ($self->print_types);

    my $conf_mat = $self->_confusion_matrix;
    my $tp_count = $conf_mat->{'pleo'}{'pleo'} || 0;
    my $tn_count = $conf_mat->{'ref'}{'ref'} || 0;
    my $fp_count = $conf_mat->{'ref'}{'pleo'} || 0;
    my $fn_count = $conf_mat->{'pleo'}{'ref'} || 0;

    if ($self->exo_as_pleo) {
        $tp_count += $conf_mat->{'exo'}{'pleo'} || 0;
        $fn_count += $conf_mat->{'exo'}{'ref'} || 0;
    }
    else {
        $fp_count += $conf_mat->{'exo'}{'pleo'} || 0;
        $tn_count += $conf_mat->{'exo'}{'ref'} || 0;
    }

    print join "\t", ($tp_count, $tn_count, $fp_count, $fn_count);
    print "\n";
}

1;

=over

=item Treex::Block::Eval::ReferentialIt

Evaluation of "it" resolution - determining whether "it" is referential
or pleonastic. It returns four columns of aggregated counts - true positive,
true negatie, false positive and false negative, which must be then 
post-processed to compute accuracy, precision, recall and f-score.

=back

=cut

# Copyright 2012 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
