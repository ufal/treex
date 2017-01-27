package Treex::Block::HamleDT::PT::SplitFusedWords;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



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
        if(exists($contractions{$xy}))
        {
            $self->mark_multiword_token($contractions{$xy}, $nodes[$i], $nodes[$i+1]);
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
            my $w1 = $form =~ m/^[aà]/i ? 'a' : $form =~ m/^d/i ? 'de' : $form =~ m/^n/i ? 'en' : 'por';
            my $w2 = $form =~ m/[aà]$/i ? 'a' : $form =~ m/[aà]s$/i ? 'as' : $form =~ m/o$/i ? 'o' : 'os';
            # The current $node will be deleted. The new nodes will be created as sibling children of the parent of the current node.
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => $w1, 'lemma'  => lc($w1), 'tag' => 'ADP', 'conll_pos' => 'prp|<sam->',
                                'iset'   => {'pos' => 'adp', 'adpostype' => 'prep'},
                                'deprel' => 'case'},
                {'form' => $w2, 'lemma'  => 'o',     'tag' => 'DET', 'conll_pos' => "art|<-sam>|<artd>|$lex{$w2}{xpos}",
                                'iset'   => {'pos' => 'adj', 'prontype' => 'art', 'definite' => 'def', 'gender' => $lex{$w2}{gender}, 'number' => $lex{$w2}{number}},
                                'deprel' => 'det'}
            );
        }
    }
}



#------------------------------------------------------------------------------
# Marks a sequence of existing nodes as belonging to one multi-word token.
#------------------------------------------------------------------------------
sub mark_multiword_token
{
    my $self = shift;
    my $fused_form = shift;
    # The nodes that form the group. They should form a contiguous span in the sentence.
    # And they should be sorted by their ords.
    my @nodes = @_;
    return if(scalar(@nodes) < 2);
    my $fsord = $nodes[0]->ord();
    my $feord = $nodes[-1]->ord();
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $nnw = $nodes[$i]->wild();
        ###!!! Later we will want to make these attributes normal (not wild).
        $nnw->{fused_form} = $fused_form;
        $nnw->{fused_start} = $fsord;
        $nnw->{fused_end} = $feord;
        $nnw->{fused} = ($i == 0) ? 'start' : ($i == $#nodes) ? 'end' : 'middle';
    }
}



#------------------------------------------------------------------------------
# Splits a node of a fused token into multiple new nodes, then deletes the old
# one.
#------------------------------------------------------------------------------
sub split_fused_token
{
    my $self = shift;
    my $fused_node = shift;
    my @new_node_descriptions = @_; # array of hash references
    my $parent = $fused_node->parent();
    my $root = $fused_node->get_root();
    my @new_nodes;
    foreach my $nn (@new_node_descriptions)
    {
        my $node = $parent->create_child();
        $node->set_form($nn->{form});
        $node->set_lemma($nn->{lemma});
        # Assuming that we are splitting fused words for Universal Dependencies, and after the Udep harmonization block,
        # we have to use the node attributes in the same fashion as the Udep harmonization does.
        # The 'tag' attribute should contain the universal POS tag, and the 'conll/pos' attribute should contain the treebank-specific tag.
        $node->set_tag($nn->{tag});
        $node->set_conll_cpos($nn->{tag});
        $node->set_conll_pos($nn->{conll_pos});
        $node->iset()->set_hash($nn->{iset});
        my $ufeat = join('|', $node->iset()->get_ufeatures());
        $node->set_conll_feat($ufeat);
        # The parent should not be root but it may happen if something in the previous transformations got amiss.
        if($parent->is_root())
        {
            $node->set_deprel('root');
        }
        else
        {
            $node->set_deprel($nn->{deprel});
        }
        push(@new_nodes, $node);
    }
    # We do not expect any children but since it is not guaranteed, let's make sure they are moved to $n1.
    my @children = $fused_node->children();
    foreach my $child (@children)
    {
        $child->set_parent($new_nodes[0]);
    }
    # Take care about node ordering.
    my $ord = $fused_node->ord();
    for(my $i = 0; $i <= $#new_nodes; $i++)
    {
        my $nn = $new_nodes[$i];
        my $nnw = $nn->wild();
        # We want the new node's ord to be between the fused node's ord and the next node's ord.
        # But we cannot set ord to a decimal number. Type control will not allow it. So we will use a wild attribute.
        $nn->_set_ord($ord);
        $nnw->{fused_ord} = $ord.'.'.($i+1);
    }
    # Remember the fused form and delete the fused node so that we can sort the nodes that are going to survive.
    my $fused_form = $fused_node->form();
    $fused_node->remove();
    # Recompute node ordering so that all ords in the tree are integers again.
    my @nodes = sort
    {
        my $result = $a->ord() <=> $b->ord();
        unless($result)
        {
            $result = $a->wild->{fused_ord} <=> $b->wild->{fused_ord}
        }
        $result;
    }
    ($root->get_descendants({ordered => 0}));
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        $nodes[$i]->_set_ord($i+1);
        delete($nodes[$i]->wild()->{fused_ord});
    }
    # Now that all nodes have their ord correct (we need to refer to the ords now),
    # save information about the group in every new node.
    my $fsord = $new_nodes[0]->ord();
    my $feord = $new_nodes[-1]->ord();
    for(my $i = 0; $i <= $#new_nodes; $i++)
    {
        my $nnw = $new_nodes[$i]->wild();
        ###!!! Later we will want to make these attributes normal (not wild).
        $nnw->{fused_form} = $fused_form;
        $nnw->{fused_start} = $fsord;
        $nnw->{fused_end} = $feord;
        $nnw->{fused} = ($i == 0) ? 'start' : ($i == $#new_nodes) ? 'end' : 'middle';
    }
    return @new_nodes;
}



#------------------------------------------------------------------------------
# Returns the sentence text, observing the current setting of no_space_after
# and of the fused multi-word tokens (still stored as wild attributes).
#------------------------------------------------------------------------------
sub collect_sentence_text
{
    my $self = shift;
    my @nodes = @_;
    my $text = '';
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $wild = $node->wild();
        my $fused = $wild->{fused};
        if(defined($fused) && $fused eq 'start')
        {
            my $first_fused_node_ord = $node->ord();
            my $last_fused_node_ord = $wild->{fused_end};
            my $last_fused_node_no_space_after = 0;
            # We used to save the ord of the last element with every fused element but now it is no longer guaranteed.
            # Let's find out.
            if(!defined($last_fused_node_ord))
            {
                for(my $j = $i+1; $j<=$#nodes; $j++)
                {
                    $last_fused_node_ord = $nodes[$j]->ord();
                    $last_fused_node_no_space_after = $nodes[$j]->no_space_after();
                    last if(defined($nodes[$j]->wild()->{fused}) && $nodes[$j]->wild()->{fused} eq 'end');
                }
            }
            else
            {
                my $last_fused_node = $nodes[$last_fused_node_ord-1];
                log_fatal('Node ord mismatch') if($last_fused_node->ord() != $last_fused_node_ord);
                $last_fused_node_no_space_after = $last_fused_node->no_space_after();
            }
            if(defined($first_fused_node_ord) && defined($last_fused_node_ord))
            {
                $i += $last_fused_node_ord - $first_fused_node_ord;
            }
            else
            {
                log_warn("Cannot determine the span of a fused token");
            }
            $text .= $wild->{fused_form};
            $text .= ' ' unless($last_fused_node_no_space_after);
        }
        else
        {
            $text .= $node->form();
            $text .= ' ' unless($node->no_space_after());
        }
    }
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
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
