package Treex::Block::Align::T::Eval;

use Moose;
use Treex::Core::Common;

use List::MoreUtils qw/any/;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Filter::Node';

has 'align_language' => (is => 'ro', isa => 'Str', required => 1);
has 'align_reltypes' => (is => 'ro', isa => 'Str', default => '!gold,!coref_gold,!robust,!supervised,!coref_supervised,.*');

has 'penalize_analysis' => (is => 'ro', isa => 'Bool', default => 0);

sub _build_node_types {
    return 'all_anaph';
}

sub calculate_counts_for_node {
    my ($self, $src_tnode) = @_;

    my @ref_tnodes = $self->selector_counterparts($src_tnode, 'ref');
    my (@ref_true_ali, @ref_true_types);
    foreach my $ref_tnode (@ref_tnodes) {
        my ($true_ali_part, $true_types_part) = $ref_tnode->get_undirected_aligned_nodes({
            language => $self->align_language,
            selector => 'ref',
            rel_types => ['gold', 'coref_gold'],
        });
        push @ref_true_ali, @$true_ali_part;
        push @ref_true_types, @$true_types_part;
    }

    my @rel_types = split /,/, $self->align_reltypes;
    my ($src_pred_ali, $src_pred_types) = $src_tnode->get_undirected_aligned_nodes({
        language => $self->align_language,
        selector => $self->selector,
        rel_types => \@rel_types,
    });

    my @src_true_ali = map {$self->selector_counterparts($_, $src_tnode->selector)} @ref_true_ali;

    my @both_ali = grep { my $pred_node = $_; any {$_ == $pred_node} @src_true_ali } @$src_pred_ali;

    return map {scalar(@$_)} ($self->penalize_analysis ? \@ref_true_ali : \@src_true_ali, $src_pred_ali, \@both_ali);
}

sub selector_counterparts {
    my ($self, $node, $selector) = @_;

    if ($node->selector eq $selector) {
        return $node;
    }
    else {
        my ($ali_nodes, $ali_types) = $node->get_undirected_aligned_nodes({
            language => $node->language,
            selector => $selector,
        });
        return @$ali_nodes;
    }
}

sub process_filtered_tnode {
    my ($self, $tnode) = @_;
    
    my ($true, $pred, $both) = $self->calculate_counts_for_node($tnode);
    print {$self->_file_handle} join " ", ($true, $pred, $both, $tnode->get_address);
    print {$self->_file_handle} "\n";
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

A comma-separated list of the node types to be evaluated (see more in C<Treex::Block::Filter::Node>)

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
