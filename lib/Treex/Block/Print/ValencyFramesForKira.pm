package Treex::Block::Print::ValencyFramesForKira;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );



sub process_tnode
{
    my $self = shift;
    my $tnode = shift;
    my $frame = $tnode->val_frame_rf();
    return if(!$frame);
    my $troot = $tnode->root();
    my $id = $troot->id();
    $id =~ s/^t_tree-..-//;
    $id =~ s/^t-//;
    $id =~ s/-root$//;
    my $anode = $tnode->get_lex_anode();
    # We are only interested in predicates that have a lexical a-node in the same sentence.
    my $bundle = $troot->get_bundle();
    return if(!defined($anode) || $anode->get_bundle() != $bundle);
    my $form = $anode->form() // 'NOFORM';
    my $lemma = $anode->lemma() // 'NOLEMMA'; ###!!! If the a-layer has not been converted to Universal Dependencies, the lemma will not match the one in UD because it will still contain the "tail tags".
    my $upos = $anode->iset()->get_upos() // 'NOUPOS';
    my $ord = $anode->ord() // 'NOORD'; ###!!! If the a-layer has not been converted to Universal Dependencies and if there are multi-word tokens in the sentence, the ord will not match the word ID in UD!
    # To find the arguments, first get the list of effective children of the verb.
    my @children = $tnode->get_echildren();
    # We are only interested in children that have a lexical a-node in the same sentence.
    ###!!! We could follow intra-sentence coreference links but we do not do so at present.
    @children = grep {my $a = $_->get_lex_anode(); defined($a) && $a->get_bundle() == $bundle} (@children);
    @children = sort {$a->functor() cmp $b->functor()} (@children);
    my $children = join(', ', map {my $t = $_; my $a = $t->get_lex_anode(); join(':', ($t->functor(), $a->ord(), $a->form()))} (@children));
    print(join("\t", ($id, $lemma, $form, $upos, $ord, $frame, $children)), "\n");
}


1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::ValencyFramesForKira

=head1 DESCRIPTION

Print valency frame IDs for verbs + all their arguments, in a tab-separated format.
The individual columns are: sentence ID, predicate lemma, form, UPOS tag, token ordinal
number within the sentence, valency frame ID, list of effective children including
their functor, ordinal number and word form. Only those children are listed that
are overtly represented on the surface in the same sentence.

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
