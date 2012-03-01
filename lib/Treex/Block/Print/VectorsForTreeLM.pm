package Treex::Block::Print::VectorsForTreeLM;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $t_parent = $t_node->get_parent();

    my $a_node   = $t_node->get_lex_anode();
    my $a_parent = $t_parent->get_lex_anode();

    say join "\t", (

        # t-lemma
        ( $t_node->t_lemma // '' ),

        # parent t-lemma
        ( $t_parent->is_root ? '_ROOT' : $t_parent->t_lemma // '_UNDEF' ),

        # formeme
        ( $t_node->formeme // '???' ),

        # m-layer part-of-speech (return 'P' for generated #PersProns (they cannot have children, so only handle them here))
        ( $a_node ? substr( $a_node->tag, 0, 1 ) // '#' : ( $t_node->formeme eq 'drop' ? 'P' : '#' ) ),

        # parent m-layer part-of-speech
        ( $t_parent->is_root ? '#' : ( $a_parent ? substr( $a_parent->tag, 0, 1 ) // '#' : '#' ) )
    );
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::VectorsForTreeLM – print training vectors for TreeLM

=head1 DESCRIPTION

Prints the following information about each node, tab-separated, one node per line:

=over
=item t-lemma
=item parent t-lemma
=item formeme
=item surface part-of-speech
=item parent surface part-of-speech
=back 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
