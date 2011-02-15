package Treex::Block::A2T::EN::MarkRelClauseHeads;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if ( is_relclause_head($tnode) ) {
        $tnode->set_is_relclause_head(1);
    }

    return 1;
}

sub is_relclause_head {
    my ($t_node) = @_;
    return 0 if !$t_node->is_clause_head;

    # Usually wh-pronouns are children of the verb, but sometimes...
    # "licenses, the validity(parent=expire) of which(tparent=validity) will expire"
    return any { is_wh_pronoun($_) } $t_node->get_clause_descendants();
}

sub is_wh_pronoun {
    my ($t_node) = @_;
    my $a_node = $t_node->get_lex_anode() or return 0;
    return $a_node->tag =~ /W/;
}

1;

=over

=item Treex::Block::A2T::EN::MarkRelClauseHeads

Finds relative clauses and mark their heads using the C<is_relclause_head> attribute.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
