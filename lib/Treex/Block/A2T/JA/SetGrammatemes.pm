package Treex::Block::A2T::JA::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my $DEBUG => 0;


sub process_tnode {
    my ( $self, $t_node ) = @_;
    return if $t_node->nodety ne 'complex';

    # Sempos of all complex nodes should be defined,
    # so initialize it with a default value.
    $t_node->set_gram_sempos('???');

    assign_grammatemes_to_tnode($t_node);
}

sub assign_grammatemes_to_node {
    my ($tnode) = @_;
    my $lex_anode = $tnode->get_lex_anode();
    return if !lex_anode;
    my $tag = $lex_anode->tag;
    my $form = lc $lex_anode->form;
    
    # TODO: do it better and for all types of nodes
    # right now we only set negation grammateme for verbs
    # need to make solution compatible with our aproach towards japanese copulas
    if ( $tag eq "Dōshi" ) {
        _verb( $tnode, $tag, $form);
    }

    return;

}

# we only check for negation
sub _verb {
    my ($tnode, $tag, $form ) = @_;

    # negation (simple solution, should be revised)
    # negative copulas will probably not be set right
    @negation_nodes = map { $_->form eq "ない" || $_->form eq "ん" } 
                            $tnode->get_aux_nodes();

    if (@negation_nodes) {
        $tnode->set_gram_negation('neg1');
    }
    else {
        $tnode->set_gram_negation('neg0');
    }
}

1;

=over

=item Treex::Block::A2T::JA::SetGrammatemes

Negation grammmatemes of Japanese complex nodes are filled by this block, using
POS tags and info about auxiliary words.

TODO: set other grammatemes too

=back

=cut

=head1 AUTHORS

Dusan Varis
