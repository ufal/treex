package Treex::Block::A2T::JA::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my $DEBUG => 0;


sub process_tnode {
    my ( $self, $t_node ) = @_;
    #return if $t_node->nodetype ne 'complex';

    # Sempos of all complex nodes should be defined,
    # so initialize it with a default value.
    # $t_node->set_gram_sempos('???');

    assign_grammatemes_to_tnode($t_node);
}

sub assign_grammatemes_to_tnode {
    my ($tnode) = @_;
    my $lex_anode = $tnode->get_lex_anode();
    return if !$lex_anode;
    my $tag = $lex_anode->tag;
    my $form = lc $lex_anode->form;
    
    # TODO: do it better and for all types of nodes
    # right now we only set negation grammateme for verbs
    # need to make solution compatible with our aproach towards japanese copulasor predicate verbs and adjectives with ommited copulas

    if ( $tag =~ /^Dōshi/ ) {
        _verb( $tnode, $tag, $form);
    }

    return;

}

# we only check for negation
sub _verb {
    my ($tnode, $tag, $form ) = @_;

    $tnode->set_gram_sempos('v');

    # negation (simple solution, should be revised)
    # negative copulas will probably not be set right
    my @negation_nodes = map { $_->form eq "ない" || $_->form eq "ん" } 
                            $tnode->get_aux_anodes();

    if (scalar @negation_nodes == 0) {
        $tnode->set_gram_negation('neg1');
    }
    else {
        $tnode->set_gram_negation('neg0');
    }
}

1;

=over

=item Treex::Block::A2T::JA::SetGrammatemes

Negation grammmatemes of Japanese verb nodes are filled by this block, using
POS tags and info about auxiliary words. Sempos is also set for verbs,
because it is needed to generate negative forms correctly after transfer

TODO: set other grammatemes too, mainly:
    - degcmp
    - politeness
    - tense
    - verbmod
... and maybe others

=back

=cut

=head1 AUTHORS

Dusan Varis
