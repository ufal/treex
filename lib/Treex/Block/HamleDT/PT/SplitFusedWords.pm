package Treex::Block::HamleDT::PT::SplitFusedWords;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::SplitFusedWords';



#------------------------------------------------------------------------------
# Splits certain tokens to syntactic words according to the guidelines of the
# Universal Dependencies. This block should be called after the tree has been
# converted to UD, not before!
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    $self->mark_multiword_tokens($root);
    # Some of the above transformations may have split or removed nodes.
    # Make sure that the full sentence text corresponds to the nodes again.
    ###!!! Note that for the Prague treebanks this may introduce unexpected differences.
    ###!!! If there were typos in the underlying text or if numbers were normalized from "1,6" to "1.6",
    ###!!! the sentence attribute contains the real input text, but it will be replaced by the normalized word forms now.
    my @nodes = $root->get_descendants({'ordered' => 1});
    my $text = $self->collect_sentence_text(@nodes);
    $zone->set_sentence($text);
}



my %contractions =
(
    'a:o'        => 'ao',
    'a:os'       => 'aos',
    'a:a'        => 'à',
    'a:as'       => 'às',
    'a:aquela'   => 'àquela',
    'a:aquelas'  => 'àquelas',
    'a:aquele'   => 'àquele',
    'a:aqueles'  => 'àqueles',
    'de:o'       => 'do',
    'de:os'      => 'dos',
    'de:a'       => 'da',
    'de:as'      => 'das',
    'de:algum'   => 'dalgum',
    'de:alguma'  => 'dalguma',
    'de:algumas' => 'dalgumas',
    'de:alguns'  => 'dalguns',
    'de:alguém'  => 'dalguém',
    'de:ali'     => 'dali',
    'de:aquela'  => 'daquela',
    'de:aquelas' => 'daquelas',
    'de:aquele'  => 'daquele',
    'de:aqueles' => 'daqueles',
    'de:aqui'    => 'daqui',
    'de:aquilo'  => 'daquilo',
    'de:ela'     => 'dela',
    'de:elas'    => 'delas',
    'de:ele'     => 'dele',
    'de:eles'    => 'deles',
    'de:entre'   => 'dentre',
    'de:essa'    => 'dessa',
    'de:essas'   => 'dessas',
    'de:esse'    => 'desse',
    'de:esses'   => 'desses',
    'de:esta'    => 'desta',
    'de:estas'   => 'destas',
    'de:este'    => 'deste',
    'de:estes'   => 'destes',
    'de:isso'    => 'disso',
    'de:isto'    => 'disto',
    'de:onde'    => 'donde',
    'de:outra'   => 'doutra',
    'de:outras'  => 'doutras',
    'de:outro'   => 'doutro',
    'de:outros'  => 'doutros',
    'de:um'      => 'dum',
    'de:uma'     => 'duma',
    'de:uns'     => 'duns',
    'em:o'       => 'no',
    'em:os'      => 'nos',
    'em:a'       => 'na',
    'em:as'      => 'nas',
    'em:algumas' => 'nalgumas',
    'em:alguns'  => 'nalguns',
    'em:aquela'  => 'naquela',
    'em:aquele'  => 'naquele',
    'em:aquelas' => 'naquelas',
    'em:aquilo'  => 'naquilo',
    'em:ela'     => 'nela',
    'em:elas'    => 'nelas',
    'em:ele'     => 'nele',
    'em:eles'    => 'neles',
    'em:essa'    => 'nessa',
    'em:essas'   => 'nessas',
    'em:esse'    => 'nesse',
    'em:esses'   => 'nesses',
    'em:esta'    => 'nesta',
    'em:estas'   => 'nestas',
    'em:este'    => 'neste',
    'em:estes'   => 'nestes',
    'em:isso'    => 'nisso',
    'em:isto'    => 'nisto',
    'em:outra'   => 'noutra',
    'em:outras'  => 'noutras',
    'em:outro'   => 'noutro',
    'em:outros'  => 'noutros',
    'em:um'      => 'num',
    'em:uma'     => 'numa',
    'em:umas'    => 'numas',
    'por:o'      => 'pelo',
    'por:os'     => 'pelos',
    'por:a'      => 'pela',
    'por:as'     => 'pelas',
);



my %lex =
(
    'o'  => {'gender' => 'masc', 'number' => 'sing', 'xpos' => 'M|S'},
    'a'  => {'gender' => 'fem',  'number' => 'sing', 'xpos' => 'F|S'},
    'os' => {'gender' => 'masc', 'number' => 'plur', 'xpos' => 'M|P'},
    'as' => {'gender' => 'fem',  'number' => 'plur', 'xpos' => 'F|P'}
);



#------------------------------------------------------------------------------
# Identifies nodes from the original Portuguese treebank that are part of a
# larger surface token. Marks them as such (multi-word tokens will be visible
# in the CoNLL-U file).
#------------------------------------------------------------------------------
sub mark_multiword_tokens
{
    my $self = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    for(my $i = 0; $i < $#nodes; $i++)
    {
        my $x = $nodes[$i]->form();
        my $y = $nodes[$i+1]->form();
        my $xy = "$x:$y";
        my $lcxy = lc($xy);
        if(exists($contractions{$lcxy}))
        {
            my $fused_form = $self->copy_capitalization($xy, $contractions{$lcxy});
            $self->mark_multiword_token($fused_form, $nodes[$i], $nodes[$i+1]);
            $i++;
        }
        # Verb + clitic.
        # Warning! The original treebank keeps the hyphen with the verb ("Trata- se") while we want to move it to the clitic ("Trata -se").
        # Exceptionally there are two clitics:
        # apresenta-se-lhe (originally tokenized as "apresenta- se- lhe")
        elsif($nodes[$i]->is_verb() && $y =~ m/^se-$/i && $i+2 <= $#nodes && $nodes[$i+2]->form() =~ m/^lhe$/i)
        {
            $x =~ s/-$//;
            $y =~ s/-$//;
            $y = '-'.$y;
            my $z = '-'.$nodes[$i+2]->form();
            $nodes[$i]->set_form($x);
            $nodes[$i+1]->set_form($y);
            $nodes[$i+2]->set_form($z);
            $self->mark_multiword_token($x.$y.$z, $nodes[$i], $nodes[$i+1], $nodes[$i+2]);
            $i += 2;
        }
        # In 1st person plural the final "-s" is omitted on the surface:
        # encontramo-nos = encontramos -nos = encontramos- nos
        # In certain cases the clitic is infixed:
        # centrar-se-á = centrará -se
        # far-se-á = fará -se
        # proceder-se-á = procederá -se
        # ver-se-á = verá -se
        # juntar-se-ão = juntarão -se = juntarão- se-
        elsif($nodes[$i]->is_verb() && $nodes[$i+1]->is_pronoun() && $x =~ m/-$/ && $y =~ m/^-?(a|as|de|la|las|lhe|lhes|lo|los|me|na|nas|no|nos|o|os|se|te|vos)-?$/i)
        {
            $x =~ s/-$//;
            $y =~ s/-$//;
            $y = '-'.$y unless($y =~ m/^-/);
            $nodes[$i]->set_form($x);
            $nodes[$i+1]->set_form($y);
            $xy = $x.$y;
            $xy =~ s/os-nos$/o-nos/i;
            $xy =~ s/r(á|ão)$y$/r$y-$1/i;
            $self->mark_multiword_token($xy, $nodes[$i], $nodes[$i+1]);
            $i++;
        }
    }
    # In contrast, contractions within longer multi-word expressions that we split
    # during conversion to UD may contain contractions that need attention now.
    # Example: The original treebank contained "Junta_da_Justiça_do_Trabalho" as one
    # node. We have split it to 5 normal tokens but we still need to further split
    # the contractions "da" and "do".
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        if($node->is_adposition() && $form =~ m/^(ao|à|(d|n|pel)[oa])s?$/i)
        {
            my $w1 = $self->copy_capitalization($form, $form =~ m/^[aà]/i ? 'a' : $form =~ m/^d/i ? 'de' : $form =~ m/^n/i ? 'en' : 'por');
            my $w2 = $form =~ m/[aà]$/i ? 'a' : $form =~ m/[aà]s$/i ? 'as' : $form =~ m/o$/i ? 'o' : 'os';
            # The current $node will be deleted. The new nodes will be created as sibling children of the parent of the current node.
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => $w1, 'lemma'  => lc($w1), 'tag' => 'ADP', 'conll_pos' => 'ADP',
                                'iset'   => {'pos' => 'adp', 'adpostype' => 'prep'},
                                'deprel' => 'case'},
                {'form' => $w2, 'lemma'  => 'o',     'tag' => 'DET', 'conll_pos' => 'DET',
                                'iset'   => {'pos' => 'adj', 'prontype' => 'art', 'definite' => 'def', 'gender' => $lex{$w2}{gender}, 'number' => $lex{$w2}{number}},
                                'deprel' => 'det'}
            );
            # It may happen that the parent is root. We do not want to attach two nodes to the root.
            if(scalar(@new_nodes)>=2 && $new_nodes[1]->parent()->is_root())
            {
                $new_nodes[0]->set_parent($new_nodes[1]);
                $new_nodes[0]->set_deprel('case');
            }
        }
    }
    ###!!! The following is not really about splitting multi-word tokens.
    ###!!! But it is a temporary code to make the two conversions of Bosque converge, and this block is only used with Bosque.
    @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # The feature AdpType=Prep is not used in UD_Portuguese-Bosque.
        $node->iset()->clear('adpostype');
        # The negative particle is tagged ADV in both versions and it should have Polarity=Neg.
        if($node->form() =~ m/^não$/i)
        {
            $node->iset()->set('polarity', 'neg');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::PT::SplitFusedWords

Splits certain tokens to syntactic words according to the guidelines of the
Universal Dependencies. Some of them have already been split in the original
Portuguese treebank but at least we have to annotate that they belong to a
multi-word token.

In contrast, contractions within longer multi-word expressions that we split
during conversion to UD may contain contractions that need attention now.
Example: The original treebank contained "Junta_da_Justiça_do_Trabalho" as one
node. We have split it to 5 normal tokens but we still need to further split
the contractions "da" and "do".

This block should be called after the tree has been converted to Universal
Dependencies so that the tags and dependency relation labels are from the UD
set.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
