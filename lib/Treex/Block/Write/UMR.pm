package Treex::Block::Write::UMR;
use Moose;
use Treex::Core::Common;
use experimental qw( signatures );

use Unicode::Normalize;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.umr' );

has '_curr_sentord' => ( isa => 'Int', is => 'rw' );
has '_used_variables' => ( isa => 'ArrayRef[Int]', is => 'rw' );

sub _clear_variables($self) {
    $self->_set_used_variables([(0) x (ord("z") - ord("a") + 1)]);
}

sub _assign_variable($self, $concept) {
    my $concept_norm = NFKD($concept);
    $concept_norm =~ s/\p{NonspacingMark}//g;
    $concept_norm = lc $concept_norm;

    my $varletter = $concept_norm =~ /^([a-z])/ ? $1 : "x";
    my $varord = $self->_used_variables->[ord($varletter) - ord("a")]++;

    return "s" . $self->_curr_sentord . $varletter . ($varord + 1)
}

sub process_utree($self, $utree, $sentord) {
    $self->_set_curr_sentord($sentord);
    $self->_clear_variables();

    print { $self->_file_handle } $self->_get_sent_header($utree);
    print { $self->_file_handle } $self->_get_sent_graph($utree);
}

sub _get_sent_header($self, $utree) {
    my $text = "# sent_id = " . $utree->id . "\n";
    my $troot = $utree->get_troot;
    $text .= "# :: snt" . $self->_curr_sentord . "\t"
           . $troot->get_bundle->get_zone($troot->language)->sentence . "\n";
    $text .= "\n";
    return $text
}

sub _get_sent_graph($self, $utechroot) {
    my $text = "# sentence level graph:\n";

    my @uroots = $utechroot->get_children();
    if (@uroots) {
        if (@uroots > 1) {
            log_warn('Multiple root U-nodes for the sentence = '
                     . $utechroot->id
                     . ". Printing the first root only.\n");
        }
        $text .= $self->_get_sent_subtree($uroots[0]);
    }
    $text .= "\n";
    return $text
}

sub _get_node_indent($self, $unode) {
    return ' ' x (4 * $unode->get_depth)
}

sub _get_sent_subtree($self, $unode) {
    my $umr_str = '';

    my $concept = $unode->concept;
    my $var = $self->_assign_variable($concept);

    $umr_str .= "( $var / $concept";

    for my $uchild ($unode->get_children({ordered => 1})) {
        $umr_str .= "\n" . $self->_get_node_indent($uchild);
        $umr_str .= ':' . $uchild->functor . ' ';
        $umr_str .= $self->_get_sent_subtree($uchild);
    }

    if ($unode->entity_refnumber) {
        $umr_str .= "\n" . $self->_get_node_indent($unode) . ' ' x 4;
        $umr_str .= ':refer-number ' . $unode->entity_refnumber;
    }
    $umr_str .= ")";
    return $umr_str
}

sub _get_alignment {
}

sub _get_doc_annot {
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::UMR

=head1 DESCRIPTION

Document writer of the U-layer into the UMR format.

=head1 ATTRIBUTES

=over

=item language

Language of the trees to be printed.

=item selector

Selector of the trees to be printed.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Jan Štěpánek <stepanek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2024 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
