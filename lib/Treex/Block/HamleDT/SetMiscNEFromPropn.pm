package Treex::Block::HamleDT::SetMiscNEFromPropn;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my $first_propn;
    my $last_propn;
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $node = $nodes[$i];
        if($node->is_proper_noun())
        {
            $node->set_misc_attr('NamedEntity', 'Yes');
            $first_propn = $i if(!defined($first_propn));
            $last_propn = $i;
        }
    }
    if(defined($first_propn))
    {
        # Tag non-major POS categories adjacent to the right of a PROPN.
        my $adjacent;
        for(my $i = $first_propn; $i <= $#nodes; $i++)
        {
            my $node = $nodes[$i];
            if($node->is_proper_noun())
            {
                $adjacent = 1;
            }
            elsif($adjacent &&
                  ($node->is_pronominal() || $node->is_numeral() || $node->is_adposition() || $node->is_conjunction() ||
                   $node->iset()->is_auxiliary() || $node->is_symbol() || $node->is_punctuation()))
            {
                $node->set_misc_attr('NamedEntity', 'Maybe');
            }
            else
            {
                $adjacent = 0;
            }
        }
        for(my $i = $last_propn; $i >= 0; $i--)
        {
            my $node = $nodes[$i];
            if($node->is_proper_noun())
            {
                $adjacent = 1;
            }
            elsif($adjacent &&
                  ($node->is_pronominal() || $node->is_numeral() || $node->is_adposition() || $node->is_conjunction() ||
                   $node->iset()->is_auxiliary() || $node->is_symbol() || $node->is_punctuation()))
            {
                $node->set_misc_attr('NamedEntity', 'Maybe');
            }
            else
            {
                $adjacent = 0;
            }
        }
    }
}



1;

=head1 NAME

Treex::Block::HamleDT::SetMiscNEFromPropn

=head1 DESCRIPTION

Certain treebanks (especially those donated to UD by Google) overuse the PROPN
tag (proper noun). They use the tag for every word in a multi-word named entity,
although the word should actually be something else (e.g., a title of a movie
is a named entity but it may consist entirely of regular words).

Some of these words can be identified and re-tagged automatically, in particular
function words such as determiners and adpositions. However, it would be a pity
to lose the information that there is a multi-word named entity. So we run this
simple block, which will project the PROPN tag to the MISC attribute NamedEntity=Yes.

This block was created when some function words in the multi-word named entities
had already been re-tagged. We will have to look at the old version of the data
(e.g., UD release 1.0 of UD_German) in order to find out whether these words
were a part of the named entity or not. Before we do so, we will take every
word that is in the neighborhood of a named entity and has a non-major category
(UPOS other than NOUN, PROPN, ADJ, VERB, ADV), and give it the MISC attribute
NamedEntity=Maybe.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2020 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
