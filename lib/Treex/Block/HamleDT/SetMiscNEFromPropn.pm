package Treex::Block::HamleDT::SetMiscNEFromPropn;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



has 'nelist' => ( is => 'ro', isa => 'Str', documentation => 'Optional path to file with a list of named entities '.
                 '(each possibly followed by a TAB and frequency). If available, the list will be used to judge '.
                 'neighboring words that are no longer tagged PROPN.' );
has '_nehash' => (isa => 'HashRef', is => 'rw', lazy_build => 1, builder => '_build_nehash');



#------------------------------------------------------------------------------
# Reads the list of known named entities from the file supplied into a hash.
#------------------------------------------------------------------------------
sub _build_nehash
{
    my $self = shift;
    my $nelist = $self->nelist();
    my %hash;
    open(NELIST, $nelist) or log_fatal("Cannot read $nelist: $!");
    while(<NELIST>)
    {
        chomp();
        # The named entity may be optionally followed by a tab and a frequency, which we ignore.
        s/\t.*//;
        $hash{$_}++;
    }
    close(NELIST);
    return \%hash;
}



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my $nehash;
    if(defined($self->nelist()))
    {
        $nehash = $self->_nehash();
    }
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
    # If the data originally tagged even determiners in multi-word named entities
    # as PROPN but the tags have been partially fixed, we may not see that the
    # determiner (or other function word) was part of the named entity. We may
    # look at the list of the named entities from the original data, if available.
    if(defined($first_propn) && defined($nehash))
    {
        for(my $i = 0; $i <= $#nodes; $i++)
        {
            if($nodes[$i]->is_proper_noun() ||
               $nodes[$i]->is_pronominal() || $nodes[$i]->is_numeral() ||
               $nodes[$i]->is_adposition() || $nodes[$i]->is_conjunction() ||
               $nodes[$i]->iset()->is_auxiliary() ||
               $nodes[$i]->is_symbol() || $nodes[$i]->is_punctuation())
            {
                my @entities_found;
                my $jmax;
                my $current_ne = $nodes[$i]->form();
                # Try all possible named entities starting at word $i.
                ###!!! We ignore fused multi-word tokens at present. The German GSD treebank does not contain named entities with multi-word tokens.
                for(my $j = $i + 1; $j <= $#nodes; $j++)
                {
                    if($nodes[$j]->is_proper_noun() ||
                       $nodes[$j]->is_pronominal() || $nodes[$j]->is_numeral() ||
                       $nodes[$j]->is_adposition() || $nodes[$j]->is_conjunction() ||
                       $nodes[$j]->iset()->is_auxiliary() ||
                       $nodes[$j]->is_symbol() || $nodes[$j]->is_punctuation())
                    {
                        $current_ne .= ' ' unless($nodes[$j-1]->no_space_after());
                        $current_ne .= $nodes[$j]->form();
                        if(exists($nehash->{$current_ne}))
                        {
                            push(@entities_found, $current_ne);
                            $jmax = $j;
                        }
                    }
                    else
                    {
                        # The sequence of candidate words has been interrupted. Take the longest entity found, if any.
                        # Note that it may be shorter than up to the previous word.
                        if(defined($jmax))
                        {
                            for(my $k = $i; $k <= $jmax; $k++)
                            {
                                $nodes[$k]->set_misc_attr('NamedEntity', 'Yes');
                            }
                            $i = $jmax - 1;
                        }
                        last; # $j
                    }
                }
            }
        }
    }
    # If the list of known named entities is not available, we may still mark
    # the non-major-class words in the neighborhood of a proper noun as potential
    # candidates for inclusion in the named entity.
    elsif(defined($first_propn))
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
