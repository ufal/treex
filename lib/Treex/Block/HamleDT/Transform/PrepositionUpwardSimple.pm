package Treex::Block::HamleDT::Transform::PrepositionUpwardSimple;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    my $parent = $anode->parent;
    if ( $anode->conll_cpos eq 'ADP'
        && !$parent->is_root
        && $parent->conll_cpos ne 'ADP'
    ) {

        # dive through conjunctions
        # while ( $parent->conll_cpos eq 'CONJ' && !$parent->parent->is_root ) {
        #     $parent = $parent->parent;
        # }

        $anode->set_parent($parent->parent);
        $parent->set_parent($anode);

    }

    return;
}

1;

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

