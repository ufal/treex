package Treex::Block::Test::A::NounGovernsDet;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    if(defined($parent))
    {
        my $pos = $node->get_iset('pos');
        my $prn = $node->get_iset('prontype');
        # Two pronouns, one modifying the other, are not error (da: "det andet").
        # Thus we want to catch only real nouns/adjectives below.
        $pos = 'pronoun' if($prn ne '');
        my $ppos = $parent->get_iset('pos');
        my $pprn = $parent->get_iset('prontype');
        $ppos = 'pronoun' if($pprn ne '');
        if($pos =~ m/^(noun|adj)$/ && $ppos =~ m/^(pronoun|num)$/)
        {
            $self->complain($node, $parent->form().'->'.$node->form());
        }
    }
}

1;

=over

=item Treex::Block::Test::A::NounGovernsDet

Determiners and numerals depend on nouns, not vice versa (as in Danish Dependency Treebank).
Similarly, adjectives should not depend on determiners or numerals.
This test will also catch certain Czech examples from PDT (numeral is child in "čtyři lidé", "s pěti lidmi" but it is parent in "pět lidí").

Danish also makes adjectives and genitive nouns heads of noun phrases.
Such cases are harder to detect because we cannot exclude that a noun really will modify an adjective (cf. Czech "bledý strachy").

=back

=cut

# Copyright 2011 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

