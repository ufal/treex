package Treex::Block::Print::VectorsForTreeLM;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my ($t_parent) = $t_node->get_eparents( { or_topological => 1 } ); # use effective parents

    # get a-nodes and their morphological tags
    my $a_node   = $t_node->get_lex_anode();
    my $a_parent = $t_parent->get_lex_anode();
    
    # set tag to 'P' for generated #PersProns (they cannot have children, so only handle them here)
    my $tag = $a_node ? $a_node->tag // '#' : ( $t_node->formeme eq 'drop' ? 'P' : '#' );
    my $parent_tag = ( $t_parent->is_root ? '#' : ( $a_parent ? $a_parent->tag // '#' : '#' ) );
    
    # Czech-specific: using one-letter POS tags instead of Interset POS
    if ( $self->language eq 'cs' ){
        $tag = substr( $tag, 0, 1 );
        $parent_tag = substr( $parent_tag, 0, 1 );
    }

    print { $self->_file_handle } join("\t", (

        # t-lemma
        ( $t_node->t_lemma // '' ),

        # parent t-lemma
        ( $t_parent->is_root ? '_ROOT' : $t_parent->t_lemma // '' ),

        # formeme
        ( $t_node->formeme // '???' ),

        # m-layer part-of-speech
        $tag,

        # parent m-layer part-of-speech
        $parent_tag
    )), "\n";
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

The block expects either Czech 15-position POS tags or the Interset "pos" attribute
as the value of the "tag" attribute on the a-layer (use 
C<Util::Eval anode='$.set_tag($.iset->pos)'> before this block when using Interset). 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012–2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
