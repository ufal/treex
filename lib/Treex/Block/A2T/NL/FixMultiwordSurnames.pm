package Treex::Block::A2T::NL::FixMultiwordSurnames;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {

    my ( $self, $ttree ) = @_;

    # get only MWU heads, i.e. last words of MWUs
    my (@tnodes) = grep {
        my $anode = $_->get_lex_anode();
        $anode and $anode->wild->{mwu_id} and !$anode->get_parent->wild->{mwu_id}
    } $ttree->get_descendants();

    foreach my $tnode (@tnodes) {

        my ($anode) = $tnode->get_lex_anode();

        # go forward and search for surname prefixes, merge them with main node
        my $prev_tnode = $tnode->get_prev_node();
        my $prev_anode = $prev_tnode ? $prev_tnode->get_lex_anode() : undef;

        while (
            $prev_tnode and $prev_tnode->get_parent == $tnode
            and ( $prev_anode->wild->{mwu_id} // '' ) eq $anode->wild->{mwu_id}
            and lc( $prev_anode->form ) =~ /^(van|de|den|von|het)$/
            )
        {
            $tnode->add_aux_anodes( $prev_tnode->get_anodes() );
            $tnode->set_t_lemma( $prev_tnode->t_lemma . '_' . $tnode->t_lemma );
            $prev_tnode->remove();

            # move on to further prefixes
            $prev_tnode = $tnode->get_prev_node();
            $prev_anode = $prev_tnode ? $prev_tnode->get_lex_anode() : undef;
        }
    }

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::NL::FixMultiwordSurnames

=head1 DESCRIPTION

Prepositions and articles that are (most likely) part of surnames, i.e. within
a named entity and preceding the last word of the named entity, are 
merged into the t-lemma of the surname and their t-nodes are removed.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
