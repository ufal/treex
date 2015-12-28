package Treex::Block::Align::T::Eval;

use Moose;
use Treex::Core::Common;

use List::MoreUtils qw/any/;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Filter::Node::T';

has '+node_types' => ( default => 'all_anaph' );
has 'align_language' => (is => 'ro', isa => 'Str', required => 1);
has 'align_reltypes' => (is => 'ro', isa => 'Str', default => '!gold,!robust,!supervised,.*');

sub _process_node {
    my ($self, $node) = @_;
    
    # get true and predicted aligned nodes
    my ($true_nodes, $true_types) = $node->get_undirected_aligned_nodes({
        language => $self->align_language,
        selector => $self->selector,
        rel_types => ['gold'],
    });
    log_debug "TRUE_TYPES: " . (join " ", @$true_types), 1;
    my @rel_types = split /,/, $self->align_reltypes;
    my ($pred_nodes, $pred_types) = $node->get_undirected_aligned_nodes({
        language => $self->align_language,
        selector => $self->selector,
        rel_types => \@rel_types,
    });
    log_debug "PRED_TYPES: " . (join " ", @$pred_types), 1;
   
    # get all candidates for alignment
    my $layer = $node->get_layer;
    my $aligned_tree = $node->get_bundle->get_tree($self->align_language, $layer, $self->selector);
    my @aligned_cands = ( $node, $aligned_tree->get_descendants({ordered => 1}) );
    
    # set true indexes
    my $true_idx;
    if (!defined $true_nodes || !@$true_nodes) {
        $true_nodes = [ $node ];
    }
    # +1 because the candidates are indexed from 1
    my @true_idxs = map {$_ + 1} grep {my $ali_c = $aligned_cands[$_]; any {$_ == $ali_c} @$true_nodes} 0 .. $#aligned_cands;
    $true_idx = join ",", @true_idxs;
    
    if (!defined $pred_nodes || !@$pred_nodes) {
        $pred_nodes = [ $node ];
    }
    for (my $i = 0; $i < @aligned_cands; $i++) {
        my $ali_c  = $aligned_cands[$i];
        my $loss = (any {$_ == $ali_c} @$pred_nodes) ? "0.00" : "1.00";
        print {$self->_file_handle} ($i+1).":$loss $true_idx-1\n";
    }
    print {$self->_file_handle} "\n";
}

sub process_filtered_tnode {
    my ($self, $tnode) = @_;
    
    $self->_process_node($tnode);
}

# TODO for the time being, ignoring alignment of anodes with no tnode counterpart
#sub process_anode {
#    my ($self, $anode) = @_;
#    $self->_process_node($anode);
#}

1;

__END__

=head1 NAME

Treex::Block::Align::T::Eval

=head1 SYNOPSIS

 treex
    Read::Treex from=sample.treex.gz
    Align::T::Eval language=en align_language=cs node_types=all_anaph align_reltypes='!gold,.*'
 | $ML_FRAMEWORK_DIR/scripts/results_to_triples.pl --ranking 
 | $ML_FRAMEWORK_DIR/scripts/eval.pl --acc --prf
 
=head1 DESCRIPTION

Evaluation of alignment. It compares the predicted alignment (its labels to be specified 
by the parameted C<align_reltypes>) against the true alignment (labelled as C<gold>)
and prints out the result in the Vowpal Wabbit result format. This must be postprocessed
afterwards to calculate the desired scores. The set of nodes under scrutiny is specified
by the C<language> and C<node_types> parameters, and all alignment link must point into
the language specified in C<align_language>.

=head1 PARAMETERS

=over

=item language

Specifies the source language of the evaluated alignment,

=item node_types

A comma-separated list of the node types to be evaluated (see more in C<Treex::Block::Filter::Node::T>)

=item align_reltypes

The comma-separated list of types of alignment links to be evaluated. The format of the list must satisfy
the format required by the C<rel_types> parameter in C<Treex::Core::Node::Aligned>.

=item align_language

Specifies the target language of the evaluated alignment.

=back

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
