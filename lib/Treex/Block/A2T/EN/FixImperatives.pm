package Treex::Block::A2T::EN::FixImperatives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;


    foreach my $tnode ( grep { ( $_->sentmod // '' ) eq 'imper' } $t_root->get_descendants ) {

        my $anode = $tnode->get_lex_anode;
        
        # Fixing grammatemes + formeme (it's not an infinitive)
        $tnode->set_gram_verbmod('imp');
        $tnode->set_gram_tense('nil');
        $tnode->set_formeme('v:fin');

        # Adding a #PersPron node (2nd person, pl.)
        my $perspron = $tnode->create_child;
        $perspron->shift_before_node($tnode);

        $perspron->set_is_generated(1);
        
        $perspron->set_t_lemma('#PersPron');
        $perspron->set_functor('ACT');
        $perspron->set_formeme('n:subj');    # !!! elided?
        $perspron->set_nodetype('complex');
        $perspron->set_gram_sempos('n.pron.def.pers');
        $perspron->set_gram_number('pl');
        $perspron->set_gram_gender('anim');
        $perspron->set_gram_person('2');

    }

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::FixImperatives

=head1 DESCRIPTION

Fixing grammatemes and adding a new generated #PersPron subject node
for imperative clauses.

The L<Treex::Block::A2T::SetGrammatemes> block currently treats imperatives
as normal indicative verbs, so this block fixes the grammatemes (C<verbmod=imp>, 
C<tense=nil>). 

Formeme is also changed to C<v:fin>.  

=head1 SEE ALSO

L<Treex::Block::A2T::SetSentmod>
L<Treex::Block::A2T::EN::SetSentmod>

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
