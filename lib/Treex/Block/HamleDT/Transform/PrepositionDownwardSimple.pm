package Treex::Block::HamleDT::Transform::PrepositionDownwardSimple;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    if ( $anode->conll_cpos eq 'ADP' ) {
        my @children = grep { $_->conll_cpos ne 'ADP' } $anode->get_children();
        if ( @children > 0 ) {

            # first child becomes new head
            my ($first, @tail) = @children;
            $first->set_parent($anode->parent);
            foreach my $child (@tail) {
                $child->set_parent($first);
            }
            
            # dive through conjunctions
            if ( $first->conll_cpos eq 'CONJ' ) {
                my @first_children = grep { $_->conll_cpos ne 'ADP' } $first->get_children();
                while ( $first->conll_cpos eq 'CONJ' && @first_children > 0 ) {
                    $first = $first_children[0];
                    @first_children = grep { $_->conll_cpos ne 'ADP' } $first->get_children();
                }
            }

            $anode->set_parent($first);

        }
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

