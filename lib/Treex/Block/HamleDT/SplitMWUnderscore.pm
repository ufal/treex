package Treex::Block::HamleDT::SplitMWUnderscore;
use utf8;
use open ':utf8';
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::PragueToUD;
extends 'Treex::Core::Block';

has store_orig_filename => (is=>'ro', isa=>'Bool', default=>1);

has 'last_loaded_from' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'     => ( is => 'rw', isa => 'Int', default => 0 );

#------------------------------------------------------------------------------
# Reads a Prague-style tree and transforms it to Universal Dependencies.
#------------------------------------------------------------------------------
sub process_atree {
    my ($self, $root) = @_;
    $self->split_tokens_on_underscore($root);
    # Some of the above transformations may have split or removed nodes.
    # Make sure that the full sentence text corresponds to the nodes again.
    ###!!! Note that for the Prague treebanks this may introduce unexpected differences.
    ###!!! If there were typos in the underlying text or if numbers were normalized from "1,6" to "1.6",
    ###!!! the sentence attribute contains the real input text, but it will be replaced by the normalized word forms now.
    $root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Some treebanks have multi-word expressions collapsed to one node and the
# original words are connected with the underscore character. For example, in
# Portuguese there is the token "Ministério_do_Planeamento_e_Administração_do_Território".
# This is not allowed in Universal Dependencies. Multi-word expressions must be
# split again and the individual words can then be connected using relations
# that will mark the multi-word expression.
#------------------------------------------------------------------------------
sub split_tokens_on_underscore
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my $ap = "'";
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $form = $node->form();
        if(defined($form) && $form =~ m/._./)
        {
            # Preserve the original multi-word expression as a MISC attribute, otherwise we would loose the information.
            my $mwe = $node->form();
            $mwe =~ s/&/&amp;/g;
            $mwe =~ s/\|/&verbar;/g;
            # Two expressions in Portuguese contain a typo: two consecutive underscores.
            $mwe =~ s/_+/_/g;
            my $mwepos = $node->iset()->get_upos();
            my $wild = $node->wild();
            my @misc;
            @misc = split(/\|/, $wild->{misc}) if(exists($wild->{misc}) && defined($wild->{misc}));
            push(@misc, "MWE=$mwe");
            push(@misc, "MWEPOS=$mwepos");
            $wild->{misc} = join('|', @misc);
            # Remember the attachment of the MWE. It is possible that the first node will not be the head and we will have to attach the new head somewhere.
            my $mwe_parent = $node->parent();
            my $mwe_is_member = $node->is_member();
            my $mwe_deprel = $node->deprel();
            # Split the multi-word expression.
            my @words = split(/_/, $mwe);
            my $n = scalar(@words);
            # Percentage.
            if($form =~ m/^[^_]+_(per_cent|por_ciento|%)$/i)
            {
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'nmod');
                $self->tag_nodes(\@subnodes);
                if(scalar(@subnodes)==3)
                {
                    # Attach "por" to "ciento".
                    $subnodes[1]->set_parent($subnodes[2]);
                    $subnodes[1]->set_deprel('case');
                }
            }
            # MW prepositions: a banda de, a causa de, referente a
            # MW adverbs: al fin, de otro lado, eso sí
            # MW subordinating conjunctions: al mismo tiempo que, de manera que, en caso de que
            # MW coordinating conjunctions: así como, mientras que, no sólo, sino también
            elsif($node->is_adposition() ||
               $node->is_adverb() ||
               $node->is_conjunction())
            {
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'fixed');
                $self->tag_nodes(\@subnodes, {'pos' => 'noun', 'nountype' => 'com'});
            }
            # MW determiners or pronouns: [ca] el seu, la seva; [es] el mío; [pt] todo o
            # We want to attach both parts separately to the current parent. But only if they work as determiners.
            # When Spanish "el mío" is the subject of the sentence, then "mío" should be pronoun and "el" should be attached to it as 'det'.
            elsif($node->is_determiner() && $node->deprel() eq 'det' && scalar(@words)==2)
            {
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'det');
                $self->tag_nodes(\@subnodes, {'pos' => 'adj', 'prontype' => 'art'});
                $subnodes[1]->set_parent($subnodes[0]->parent());
            }
            # MW adjectives: de moda, ex comunista, non grato
            elsif($node->is_adjective() && !$node->is_pronominal())
            {
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'amod');
                $self->tag_nodes(\@subnodes, {'pos' => 'adj'});
                @subnodes = $self->attach_left_function_words(@subnodes);
                for(my $i = 1; $i <= $#subnodes; $i++)
                {
                    if(any {$_->is_adposition()} ($subnodes[$i]->children()))
                    {
                        $subnodes[$i]->set_tag('NOUN');
                        $subnodes[$i]->iset()->set('pos' => 'noun');
                        $subnodes[$i]->set_deprel('nmod');
                    }
                }
            }
            # MW nouns: aire acondicionado, cabeza de serie, artigo 1º do código da estrada
            elsif($node->is_noun() && !$node->is_pronominal() && !$node->is_proper_noun())
            {
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'compound');
                $self->tag_nodes(\@subnodes, {'pos' => 'noun', 'nountype' => 'com'});
                @subnodes = $self->attach_left_function_words(@subnodes);
            }
            # If the MWE is tagged as proper noun then the words will also be
            # proper nouns and they will be connected using the 'flat' relation.
            # We have to ignore that some of these proper "nouns" are in fact
            # adjectives (e.g. "San" in "San Salvador"). But we will not ignore
            # function words such as "de". These are language-specific.
            elsif($node->is_proper_noun())
            {
                # This is currently the only type of MWE where a non-first node may become the head (in case of coordination).
                # Thus we have to temporarily reset the is_member flag (and later carry it over to the new head).
                ###!!!$node->set_is_member(undef);
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'flat');
                $self->tag_nodes(\@subnodes, {'pos' => 'noun', 'nountype' => 'prop'});
                # Change the 'flat' relation of punctuation and numbers. (Do not touch the head node!)
                for(my $i = 1; $i<=$#subnodes; $i++)
                {
                    if($subnodes[$i]->is_numeral())
                    {
                        $subnodes[$i]->set_deprel('nummod');
                    }
                    elsif($subnodes[$i]->is_punctuation())
                    {
                        $subnodes[$i]->set_deprel('punct');
                    }
                }
                @subnodes = $self->attach_left_function_words(@subnodes);
                # Connect clusters of content words. Treat them all as PROPN, albeit some of them are actually adjectives
                # (Aeropuertos Españoles y Navegación Aérea).
                my $left_neighbor =$subnodes[0];
                for(my $i = 1; $i <= $#subnodes; $i++)
                {
                    # If there are no intervening nodes between two proper nouns, connect them.
                    if($subnodes[$i-1]->is_proper_noun() &&
                       ($subnodes[$i]->is_proper_noun() || $subnodes[$i]->is_numeral()) &&
                       ($subnodes[$i]->ord() == $subnodes[$i-1]->ord() + 1 || $left_neighbor->parent() == $subnodes[$i-1]))
                    {
                        $subnodes[$i]->set_parent($subnodes[$i-1]);
                        $left_neighbor = $subnodes[$i];
                        splice(@subnodes, $i--, 1);
                    }
                    else
                    {
                        $left_neighbor = $subnodes[$i];
                    }
                }
                # Solve occasional coordination: Ministerio de Agricultura , Pesca y Alimentación
                # This function is called before trees have been transformed from Prague to UD, so we must construct a Prague coordination here.piopi
                for(my $i = $#subnodes; $i > 1; $i--)
                {
                    if($subnodes[$i-1]->is_coordinator())
                    {
                        # Right now the conjunction probably depends on one of the conjuncts.
                        # If this is the case, reattach it to its grandparent so we can attach the conjunct to the conjunction without creating a cycle.
                        my $coord = $subnodes[$i-1];
                        $coord->set_deprel('coord');
                        if($coord->is_descendant_of($subnodes[$i-2]))
                        {
                            $coord->set_parent($subnodes[$i-2]->parent());
                        }
                        $subnodes[$i]->set_parent($coord);
                        $subnodes[$i]->set_is_member(1);
                        $subnodes[$i-2]->set_parent($coord);
                        $subnodes[$i-2]->set_is_member(1);
                        # $subnodes[$i-2] might be the first conjunct. But if there is a comma and another cluster, look further.
                        my $j = $i-2;
                        while($j > 1 && $subnodes[$j-1]->form() eq ',')
                        {
                            if($coord->is_descendant_of($subnodes[$j-2]))
                            {
                                $coord->set_parent($subnodes[$j-2]->parent());
                            }
                            $subnodes[$j-1]->set_parent($coord);
                            $subnodes[$j-1]->set_deprel('punct');
                            $subnodes[$j-1]->set_is_member(undef);
                            $subnodes[$j-2]->set_parent($coord);
                            $subnodes[$j-2]->set_deprel('flat');
                            $subnodes[$j-2]->set_is_member(1);
                            $j -= 2;
                        }
                        splice(@subnodes, $j, $i-$j+1, $coord);
                        $i = $j+1;
                    }
                }
                ###!!! The 'flat' relations should not bypass prepositions.
                ###!!! Nouns with prepositions should be attached to the head of the prevous cluster as 'nmod', not 'flat'.
                # Now the first subnode is the head even if it is not the original node (Prague coordination).
                # The parent is set correctly but the is_member flag is not; fix it.
                $subnodes[0]->set_is_member($mwe_is_member);
                if($subnodes[0]->deprel() eq 'coord')
                {
                    foreach my $child ($subnodes[0]->children())
                    {
                        if($child->is_member())
                        {
                            $child->set_deprel($mwe_deprel);
                        }
                    }
                }
            }
            # MW verbs are light-verb constructions such as "tener en cuenta", "tomar en cuenta", "llevarse a cabo", "cerrar en banda", "dar derecho".
            elsif($node->is_verb())
            {
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'compound');
                my $iset_hash = $node->iset()->get_hash();
                $self->tag_nodes(\@subnodes, $iset_hash);
                my $n = scalar(@subnodes);
                # Two-word compound verbs. The expected decomposition is VERB+NOUN, as in "dar derecho".
                # Occasionally the second word is infinitive, as in [ca] "fer servir".
                if($n==2 && $subnodes[1]->is_verb() && lc($subnodes[1]->form()) ne 'servir')
                {
                    my $form = $subnodes[1]->form();
                    my $number = $form =~ m/s$/i ? 'plur' : 'sing';
                    my $gender = $form =~ m/os?$/i ? 'masc' : $form =~ m/as?$/i ? 'fem' : '';
                    $subnodes[1]->set_tag('NOUN');
                    $subnodes[1]->iset()->set_hash({'pos' => 'noun', 'nountype' => 'com', 'gender' => $gender, 'number' => $number});
                }
                # Most verb compounds consist of three words. The expected decomposition is VERB+ADP+NOUN, as in "tener en cuenta" / "tenir en compte".
                # Occasionally, there can be infinitive instead of the noun, as in [ca] "donar a conèixer", "to give to know" = "release, publish".
                elsif($n==3)
                {
                    $subnodes[1]->set_parent($subnodes[2]);
                    my $form = $subnodes[2]->form();
                    if($form eq 'conèixer')
                    {
                        $subnodes[2]->iset()->set_hash({'pos' => 'verb', 'verbform' => 'inf'});
                        $subnodes[1]->set_deprel('mark');
                    }
                    else
                    {
                        my $number = $form =~ m/s$/i ? 'plur' : 'sing';
                        my $gender = $form =~ m/os?$/i ? 'masc' : $form =~ m/as?$/i ? 'fem' : '';
                        $subnodes[2]->set_tag('NOUN');
                        $subnodes[2]->iset()->set_hash({'pos' => 'noun', 'nountype' => 'com', 'gender' => $gender, 'number' => $number});
                        $subnodes[1]->set_deprel('case');
                    }
                }
            }
            # MW interjections: bendita sea (bless her), cómo no, qué caramba, qué mala suerte
            elsif($node->is_interjection())
            {
                # It is only a few expressions but we would have to analyze them all manually.
                # Neither fixed nor compound seems to be a good fit for these. Let's get around with 'dep' for the moment.
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'dep');
                $self->tag_nodes(\@subnodes, {'pos' => 'int'});
            }
            else # all other multi-word expressions
            {
                # MW numerals such es "cuatro de cada diez".
                my @subnodes = $self->generate_subnodes(\@nodes, $i, \@words, 'compound');
                my $iset_hash = $node->iset()->get_hash();
                $self->tag_nodes(\@subnodes, $iset_hash);
            }
        }
    }
}



#------------------------------------------------------------------------------
# This method is called at several places in split_tokens_on_underscore() and
# it is responsible for creating the new nodes, distributing words and lemmas
# connecting the new subtree in a canonical way and taking care of ords.
#------------------------------------------------------------------------------
sub generate_subnodes
{
    my $self = shift;
    my $nodes = shift; # ArrayRef: all existing nodes, ordered
    my $i = shift; # index of the current node (this node will be split)
    my $node = $nodes->[$i];
    my $ord = $node->ord();
    my $words = shift; # ArrayRef: word forms to generate from the current node
    my $n = scalar(@{$words});
    my $deprel = shift; # deprel to use when connecting the new nodes to the current one
    my @lemmas = split(/_/, $node->lemma());
    if(scalar(@lemmas) != $n)
    {
        log_warn("MWE '".$node->form()."' contains $n words but its lemma '".$node->lemma()."' contains ".scalar(@lemmas)." words.");
    }
    my @new_nodes;
    for(my $j = 1; $j < $n; $j++)
    {
        my $new_node = $node->create_child();
        $new_node->_set_ord($ord+$j);
        $new_node->set_form($words->[$j]);
        my $lemma = $lemmas[$j];
        $lemma = '_' if(!defined($lemma));
        $new_node->set_lemma($lemma);
        # Copy all Interset features. It may be wrong, e.g. if we are splitting "Presidente_da_República", the MWE may be masculine but "República" is not.
        # Unfortunately there is no dictionary-independent way to deduce the features of the individual words.
        $new_node->set_iset($node->iset());
        $new_node->set_deprel($deprel);
        push(@new_nodes, $new_node);
    }
    # The original node will now represent only the first word.
    $node->set_form($words->[0]);
    $node->set_lemma($lemmas[0]);
    # Adjust ords of the subsequent old nodes!
    for(my $j = $i + 1; $j <= $#{$nodes}; $j++)
    {
        $nodes->[$j]->_set_ord( $ord + $n + ($j - $i - 1) );
    }
    # If the original node had no_space_after set, this flag must be now set at the last subnode!
    if($node->no_space_after() && scalar(@new_nodes)>0)
    {
        $node->set_no_space_after(undef);
        $new_nodes[-1]->set_no_space_after(1);
    }
    # In addition, some guessing of no_space_after that we did in W2W::EstimateNoSpaceAfter must now be redone on the new nodes.
    # For example, if the MWE was "La_Casa_d'_Andalusia", we now have "d'" that does not know that it should be adjacent to "Andalusia".
    # The same holds for single quotes, e.g. "Fundació_'_la_Caixa_'".
    if(scalar(@new_nodes) > 0)
    {
        my @all_nodes = ($node, @new_nodes);
        my $nsq = 0;
        for(my $i = 0; $i < $#all_nodes; $i++)
        {
            my $current_node = $all_nodes[$i];
            if($current_node->form() =~ m/\pL'$/)
            {
                $current_node->set_no_space_after(1);
            }
            # Odd undirected quotes are considered opening, even are closing.
            # It will not work if a quote is missing or if the quoted text spans multiple sentences.
            if($current_node->form() eq "'")
            {
                $nsq++;
                # If the number of quotes is even, the no_space_after flag has been set at the previous token.
                # If the number of quotes is odd, we must set the flag now.
                if($nsq % 2 == 1)
                {
                    $current_node->set_no_space_after(1);
                }
            }
            # If the current number of quotes is odd, the next quote will be even.
            if($all_nodes[$i+1]->form() eq "'" && $nsq % 2 == 1)
            {
                $current_node->set_no_space_after(1);
            }
        }
    }
    # Return the list of new nodes.
    return ($node, @new_nodes);
}

my %DETHASH =
(
    'all' =>
    {
        # Definite and indefinite articles.
        'el'  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'},
        'lo'  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'},
        'la'  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'sing'},
        "l'"  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'number' => 'sing'},
        'els' => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'},
        'les' => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'plur'},
        'los' => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'},
        'las' => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'plur'},
        'os'  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'},
        'as'  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'plur'},
        'un'  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'ind', 'gender' => 'masc', 'number' => 'sing'},
        'una' => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'ind', 'gender' => 'fem',  'number' => 'sing'},
        'um'  => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'ind', 'gender' => 'masc', 'number' => 'sing'},
        'uma' => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'ind', 'gender' => 'fem',  'number' => 'sing'},
        # Fused preposition + determiner.
        'al'    => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'}, # a+el
        'als'   => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'}, # a+els
        'ao'    => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'}, # a+o
        'aos'   => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'}, # a+os
        'à'     => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'sing'}, # a+a
        'às'    => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'plur'}, # a+as
        'del'   => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'}, # de+el
        'dels'  => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'}, # de+els
        'do'    => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'}, # de+o
        # "dos" is in the language-specific part.
        'da'    => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'sing'}, # de+a
        'das'   => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'plur'}, # de+as
        'pelo'  => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'}, # por+o
        'pelos' => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'}, # por+os
        'pela'  => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'sing'}, # por+a
        'pelas' => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'plur'}, # por+as
        # Possessive determiners.
        'su'    => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'number' => 'sing'}, # es
        'sus'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'number' => 'plur'}, # es
        'suyo'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'masc', 'number' => 'sing'}, # es
        'suya'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'fem',  'number' => 'sing'}, # es
        'suyos' => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'masc', 'number' => 'plur'}, # es
        'suyas' => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'fem',  'number' => 'plur'}, # es
        'seu'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'masc', 'number' => 'sing'}, # ca, pt
        'seva'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'fem',  'number' => 'sing'}, # ca
        'seus'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'masc', 'number' => 'plur'}, # ca
        'seves' => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'fem',  'number' => 'plur'}, # ca
        'sua'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'gender' => 'fem',  'number' => 'sing'}, # pt
        'mío'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'masc', 'number' => 'sing', 'possnumber' => 'sing'}, # es
        'mía'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'fem',  'number' => 'sing', 'possnumber' => 'sing'}, # es
        'míos'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'masc', 'number' => 'plur', 'possnumber' => 'sing'}, # es
        'mías'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'fem',  'number' => 'plur', 'possnumber' => 'sing'}, # es
        'meu'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'masc', 'number' => 'sing', 'possnumber' => 'sing'}, # ca, pt
        'meus'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'masc', 'number' => 'plur', 'possnumber' => 'sing'}, # ca
        'nuestro'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'masc', 'number' => 'sing', 'possnumber' => 'plur'}, # es
        'nuestra'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'fem',  'number' => 'sing', 'possnumber' => 'plur'}, # es
        'nuestros' => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'masc', 'number' => 'plur', 'possnumber' => 'plur'}, # es
        'nuestras' => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'fem',  'number' => 'plur', 'possnumber' => 'plur'}, # es
        'nostre'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'masc', 'number' => 'sing', 'possnumber' => 'plur'}, # ca
        'nostra'   => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'gender' => 'fem',  'number' => 'sing', 'possnumber' => 'plur'}, # ca
        'nostres'  => {'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'number' => 'plur', 'possnumber' => 'plur'}, # ca
        # Other determiners and pronouns.
        'aquel' => {'pos' => 'adj', 'prontype' => 'dem', 'gender' => 'masc', 'number' => 'sing'},
        'todo'  => {'pos' => 'adj', 'prontype' => 'tot', 'gender' => 'masc', 'number' => 'sing'},
        'tot'   => {'pos' => 'adj', 'prontype' => 'tot', 'gender' => 'masc', 'number' => 'sing'},
        # Numerals.
        'zero'   => {'pos' => 'num', 'numtype' => 'card'},
        'cero'   => {'pos' => 'num', 'numtype' => 'card'},
        # "dos" is in the language-specific part.
        'dues'   => {'pos' => 'num', 'numtype' => 'card', 'gender' => 'fem'},
        'dois'   => {'pos' => 'num', 'numtype' => 'card', 'gender' => 'masc'},
        'duas'   => {'pos' => 'num', 'numtype' => 'card', 'gender' => 'fem'},
        'tres'   => {'pos' => 'num', 'numtype' => 'card'},
        'três'   => {'pos' => 'num', 'numtype' => 'card'},
        'quatre' => {'pos' => 'num', 'numtype' => 'card'},
        'cuatro' => {'pos' => 'num', 'numtype' => 'card'},
        'quatro' => {'pos' => 'num', 'numtype' => 'card'},
        'cinc'   => {'pos' => 'num', 'numtype' => 'card'},
        'cinco'  => {'pos' => 'num', 'numtype' => 'card'},
        'sis'    => {'pos' => 'num', 'numtype' => 'card'},
        'seis'   => {'pos' => 'num', 'numtype' => 'card'},
        'set'    => {'pos' => 'num', 'numtype' => 'card'},
        'siete'  => {'pos' => 'num', 'numtype' => 'card'},
        'sete'   => {'pos' => 'num', 'numtype' => 'card'},
        'vuit'   => {'pos' => 'num', 'numtype' => 'card'},
        'ocho'   => {'pos' => 'num', 'numtype' => 'card'},
        'oito'   => {'pos' => 'num', 'numtype' => 'card'},
        'nou'    => {'pos' => 'num', 'numtype' => 'card'},
        'nueve'  => {'pos' => 'num', 'numtype' => 'card'},
        'nove'   => {'pos' => 'num', 'numtype' => 'card'},
        'deu'    => {'pos' => 'num', 'numtype' => 'card'},
        'diez'   => {'pos' => 'num', 'numtype' => 'card'},
        'dez'    => {'pos' => 'num', 'numtype' => 'card'},
        'onze'   => {'pos' => 'num', 'numtype' => 'card'},
        'once'   => {'pos' => 'num', 'numtype' => 'card'},
        'dotze'  => {'pos' => 'num', 'numtype' => 'card'},
        'doce'   => {'pos' => 'num', 'numtype' => 'card'},
        'doze'   => {'pos' => 'num', 'numtype' => 'card'},
        'tretze' => {'pos' => 'num', 'numtype' => 'card'},
        'trece'  => {'pos' => 'num', 'numtype' => 'card'},
        'treze'  => {'pos' => 'num', 'numtype' => 'card'},
        'catorze' => {'pos' => 'num', 'numtype' => 'card'},
        'catorce' => {'pos' => 'num', 'numtype' => 'card'},
        'quinze' => {'pos' => 'num', 'numtype' => 'card'},
        'quince' => {'pos' => 'num', 'numtype' => 'card'},
        'setze'  => {'pos' => 'num', 'numtype' => 'card'},
        'dieciséis' => {'pos' => 'num', 'numtype' => 'card'},
        'dezasseis' => {'pos' => 'num', 'numtype' => 'card'},
        'disset' => {'pos' => 'num', 'numtype' => 'card'},
        'diecisiete' => {'pos' => 'num', 'numtype' => 'card'},
        'dezassete' => {'pos' => 'num', 'numtype' => 'card'},
        'divuit' => {'pos' => 'num', 'numtype' => 'card'},
        'dieciocho' => {'pos' => 'num', 'numtype' => 'card'},
        'dezoito' => {'pos' => 'num', 'numtype' => 'card'},
        'dinou'  => {'pos' => 'num', 'numtype' => 'card'},
        'diecinueve' => {'pos' => 'num', 'numtype' => 'card'},
        'dezanove' => {'pos' => 'num', 'numtype' => 'card'},
        'vint'   => {'pos' => 'num', 'numtype' => 'card'},
        'veinte' => {'pos' => 'num', 'numtype' => 'card'},
        'vinte'  => {'pos' => 'num', 'numtype' => 'card'},
        'trenta' => {'pos' => 'num', 'numtype' => 'card'},
        'treinta' => {'pos' => 'num', 'numtype' => 'card'},
        'trinta' => {'pos' => 'num', 'numtype' => 'card'},
        'quaranta' => {'pos' => 'num', 'numtype' => 'card'},
        'cuaranta' => {'pos' => 'num', 'numtype' => 'card'},
        'quarenta' => {'pos' => 'num', 'numtype' => 'card'},
        'cinquanta' => {'pos' => 'num', 'numtype' => 'card'},
        'cincuenta' => {'pos' => 'num', 'numtype' => 'card'},
        'cinquenta' => {'pos' => 'num', 'numtype' => 'card'},
        'seixanta' => {'pos' => 'num', 'numtype' => 'card'},
        'sesenta' => {'pos' => 'num', 'numtype' => 'card'},
        'sessenta' => {'pos' => 'num', 'numtype' => 'card'},
        'setanta' => {'pos' => 'num', 'numtype' => 'card'},
        'setenta' => {'pos' => 'num', 'numtype' => 'card'},
        'vuitanta' => {'pos' => 'num', 'numtype' => 'card'},
        'ochenta' => {'pos' => 'num', 'numtype' => 'card'},
        'oitenta' => {'pos' => 'num', 'numtype' => 'card'},
        'noranta' => {'pos' => 'num', 'numtype' => 'card'},
        'noventa' => {'pos' => 'num', 'numtype' => 'card'},
        'cent'   => {'pos' => 'num', 'numtype' => 'card'},
        'cien'   => {'pos' => 'num', 'numtype' => 'card'},
        'ciento' => {'pos' => 'num', 'numtype' => 'card'},
        'cem'    => {'pos' => 'num', 'numtype' => 'card'},
        'cemto'  => {'pos' => 'num', 'numtype' => 'card'},
        'mil'    => {'pos' => 'num', 'numtype' => 'card'},
        'milió'  => {'pos' => 'num', 'numtype' => 'card'},
        'millón' => {'pos' => 'num', 'numtype' => 'card'},
        'milhão' => {'pos' => 'num', 'numtype' => 'card'},
        # nouns
        'ejemplo' => {'pos' => 'noun', 'nountype' => 'com', 'gender' => 'masc', 'number' => 'sing'},
        'embargo' => {'pos' => 'noun', 'nountype' => 'com', 'gender' => 'masc', 'number' => 'sing'},
    },
    'ca' =>
    {
        'dos' => {'pos' => 'num', 'numtype' => 'card', 'gender' => 'masc'}, # two
        'com' => {'pos' => 'conj', 'conjtype' => 'sub'}, # how
        'no'  => {'pos' => 'part', 'negativeness' => 'neg'},
    },
    'es' =>
    {
        'dos' => {'pos' => 'num', 'numtype' => 'card'}, # two (both masculine and feminine)
        'no'  => {'pos' => 'part', 'negativeness' => 'neg'},
    },
    'pt' =>
    {
        # Definite and indefinite articles.
        'o'   => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'},
        'a'   => {'pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'sing'},
        # Fused preposition + determiner.
        'dos' => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'}, # de+os
        'no'  => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'sing'}, # em+o
        'nos' => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'masc', 'number' => 'plur'}, # em+os
        'na'  => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'sing'}, # em+a
        'nas' => {'pos' => 'adp', 'adpostype' => 'preppron', 'definiteness' => 'def', 'gender' => 'fem',  'number' => 'plur'}, # em+as
        # Other.
        'com' => {'pos' => 'adp', 'adpostype' => 'prep'}, # with
        'não' => {'pos' => 'part', 'negativeness' => 'neg'},
    }
);

#------------------------------------------------------------------------------
# A primitive method to tag unambiguous function words in certain Romance
# languages. Used to tag new nodes when MWE nodes are split. Language
# dependent! Nodes whose form is not recognized will be left intact.
#------------------------------------------------------------------------------
sub tag_nodes
{
    my $self = shift;
    my $nodes = shift; # ArrayRef: nodes that should be (re-)tagged
    my $default = shift; # HashRef: Interset features to set for unrecognized nodes

    # Currently supported languages: Catalan, Spanish and Portuguese.
    # In general, we want to use a mixed dictionary. If there is a foreign named entity (such as Catalan "L'Hospitalet" in Spanish text),
    # we still want to recognize the "L'" as a determiner. If it was "La", it would become a DET anyway, regardless whether it is
    # Spanish, Catalan, French or Italian.
    # However, some words should be in a language-specific dictionary to reduce homonymy.
    # For example, Portuguese "a" is either a DET or an ADP. In Catalan and Spanish, it is only ADP.
    # We do not want to extend the Portuguese homonymy issue to the other languages.
    my $language = $nodes->[0]->language;
    my $ap = "'";

    # Note that "a" in Portuguese can be either ADP or DET. Within a multi-word preposition we will only consider DET if it is neither the first nor the last word of the expression.
    my $adp = "a|amb|ante|con|d${ap}|de|des|em|en|entre|hasta|in|para|pels?|per|por|sem|sin|sob|sobre";
    my $sconj = 'como|que|si';
    my $conj = 'e|i|mentre|mientras|ni|o|ou|sino|sinó|y';
    # In addition a few open-class words that appear in multi-word prepositions.
    my $adj = 'baix|bell|bons|certa|cierto|debido|devido|especial|gran|grande|igual|junt|junto|larga|libre|limpio|maior|mala|mesmo|mismo|muitas|nou|nuevo|otro|outro|poca|primeiro|próximo|qualquer|rara|segundo';
    my $adv = 'abaixo|acerca|acima|además|agora|ahí|ahora|aí|així|além|ali|alrededor|amén|antes|aparte|apesar|aquando|aqui|aquí|asi|así|bien|cerca|cómo|cuando|darrere|debaixo|debajo|delante|dentro|después|detrás|diante|encara|encima|enfront|enllà|enlloc|enmig|entonces|entorn|fins|ja|já|juntament|lejos|longe|luego|mais|más|menos|menys|més|mucho|muchísimo|només|onde|poco|poquito|pouco|prop|quando|quant|quanto|sempre|siempre|sólo|tard|tarde|ya';
    for(my $i = 0; $i <= $#{$nodes}; $i++)
    {
        my $node = $nodes->[$i];
        my $form = lc($node->form());
        # Current tag of the node is the tag of the multi-word expression. It can help us in resolving the homonymous Portuguese "a".
        my $current_tag = $node->tag() // '';
        if($language eq 'pt' && $form eq 'a' && $current_tag eq 'ADP')
        {
            if($i==0 || $i==$#{$nodes})
            {
                $node->iset()->set_hash({'pos' => 'adp', 'adpostype' => 'prep'});
            }
            else
            {
                $node->iset()->set_hash($DETHASH{$language}{$form});
            }
            $node->set_tag($node->iset()->get_upos());
        }
        # Ali Abdullah Saleh: in this case "Ali" is not adverb.
        elsif($form eq 'ali' && $current_tag eq 'PROPN')
        {
            # Do nothing. Keep the current tag.
        }
        elsif(exists($DETHASH{$language}{$form}))
        {
            $node->iset()->set_hash($DETHASH{$language}{$form});
            $node->set_tag($node->iset()->get_upos());
        }
        elsif(exists($DETHASH{all}{$form}))
        {
            $node->iset()->set_hash($DETHASH{all}{$form});
            $node->set_tag($node->iset()->get_upos());
        }
        elsif($form =~ m/^($adp)$/i)
        {
            $node->set_tag('ADP');
            $node->iset()->set_hash({'pos' => 'adp', 'adpostype' => 'prep'});
        }
        elsif($form =~ m/^($sconj)$/i)
        {
            $node->set_tag('SCONJ');
            $node->iset()->set_hash({'pos' => 'conj', 'conjtype' => 'sub'});
        }
        elsif($form =~ m/^($conj)$/i)
        {
            $node->set_tag('CONJ');
            $node->iset()->set_hash({'pos' => 'conj', 'conjtype' => 'coor'});
        }
        elsif($form =~ m/^($adj)$/i)
        {
            $node->set_tag('ADJ');
            $node->iset()->add('pos' => 'adj', 'prontype' => '');
        }
        elsif($form =~ m/^($adv)$/i)
        {
            $node->set_tag('ADV');
            $node->iset()->add('pos' => 'adv');
        }
        elsif($form =~ m/^[-+.,:]*[0-9]+[-+.,:0-9]*$/)
        {
            $node->set_tag('NUM');
            $node->iset()->set_hash({'pos' => 'num', 'numtype' => 'card', 'numform' => 'digit'});
        }
        elsif($form eq '%')
        {
            $node->set_tag('SYM');
            $node->iset()->add('pos' => 'sym');
        }
        elsif($form =~ m/^\pP+$/)
        {
            $node->set_tag('PUNCT');
            $node->iset()->set_hash({'pos' => 'punc'});
        }
        else
        {
            $node->iset()->set_hash($default);
            $node->set_tag($node->iset()->get_upos());
        }
    }
}



#------------------------------------------------------------------------------
# Attaches prepositions and determiners to the following nodes. Assumes that
# the first node is the current head and all other nodes are attached to it.
# Thus cycles must be treated only if the first node is to be re-attached.
#------------------------------------------------------------------------------
sub attach_left_function_words
{
    my $self = shift;
    my @nodes = @_;
    my $content_word; # the non-function node to the right, if any
    for(my $i = $#nodes; $i >= 0; $i--)
    {
        my $reattach = 0;
        my $original_deprel = $nodes[$i]->deprel();
        if($nodes[$i]->is_determiner() && defined($content_word))
        {
            $reattach = 1;
            $nodes[$i]->set_deprel('det');
        }
        elsif(($nodes[$i]->is_adposition() || $nodes[$i]->is_subordinator()) && defined($content_word))
        {
            $reattach = 1;
            $nodes[$i]->set_deprel('case');
        }
        elsif($nodes[$i]->is_particle() && $nodes[$i]->is_negative() && defined($content_word))
        {
            $reattach = 1;
            $nodes[$i]->set_deprel('neg');
        }
        if($reattach)
        {
            if($content_word->is_descendant_of($nodes[$i]))
            {
                $content_word->set_parent($nodes[$i]->parent());
                $content_word->set_deprel($original_deprel);
            }
            $nodes[$i]->set_parent($content_word);
            splice(@nodes, $i, 1);
        }
        else
        {
            $content_word = $nodes[$i];
        }
    }
    # The function words that had found their parents were removed from the array. Return the new array.
    return @nodes;
}



1;

=over

=item Treex::Block::HamleDT::SplitMWUnderscore

Converts dependency trees from the HamleDT/Prague style to the Universal
Dependencies. This block is experimental. In the future, it may be split into
smaller blocks, moved elsewhere in the inheritance hierarchy or otherwise
rewritten. It is also possible (actually quite likely) that the current
Harmonize* blocks will be modified to directly produce Universal Dependencies,
which will become our new default central annotation style.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
