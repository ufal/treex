package Treex::Block::T2U::ConvertCoreference;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

# only return the 1st node in a coref chain + never go across the sentence boundary
# (return undefs instead)
sub _filter_coref_node {
    my ( $self, $tnode, $tantec ) = @_;
    return first { $_->get_root == $tnode->get_root } $tantec->get_coref_chain( { add_self => 1, ordered => 1 } );
}

sub process_unode {

    my ( $self, $unode ) = @_;

    my $tnode = $unode->get_tnode;
    # this can happen for e.g. the generated polarity node
    return if !defined $tnode;

    # skip if the tnode is not an anaphor
    my @ante_tnodes = $tnode->get_coref_nodes();
    return if (!@ante_tnodes);
    # TODO: what are the cases with multiple antecedents? Skip for the time being.
    return if (@ante_tnodes > 1);

    # TODO: special treatment of event concept modifiers, i.e. relative clauses and participles
        
    # look for the antecedent that is the first mention
    my $sentfirst_ante_tnode = $self->_filter_coref_node($tnode, $ante_tnodes[0]);

    # intra-sentential link
    # the current node is just a reference to the antecedent concept
    if (defined $sentfirst_ante_tnode) {
        my ($sentfirst_ante_unode) = $sentfirst_ante_tnode->get_referencing_nodes('t.rf');
        $unode->make_referential($sentfirst_ante_unode);
    }
    # inter-sentential link
    else {
        # TODO: implement this    
    }
    
    return;
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::T2U::ConvertCoreference

=head1 DESCRIPTION

Tecto-to-UMR converter of coreference relations.
It converts all coreferential links from the t- to the u-layer.
Three kinds of representation of tecto-like coreference are distinguished:
1. inversed participant role
2. reference to a concept within the same graph
3. document-level coreference annotation

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
