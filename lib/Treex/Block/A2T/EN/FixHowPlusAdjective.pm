package Treex::Block::A2T::EN::FixHowPlusAdjective;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    return if ( $tnode->t_lemma ne 'how' );
    my @children = $tnode->get_children();
    return if ( @children != 1 );

    $children[0]->set_parent( $tnode->get_parent );
    $tnode->set_parent( $children[0] );

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::FixHowPlusAdjective;

=head1 DESCRIPTION

This rehangs adjectival children of t-nodes with the t-lemma 'how', so that the 'how'-node becomes their child.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
