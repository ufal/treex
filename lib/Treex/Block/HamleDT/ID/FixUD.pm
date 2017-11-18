package Treex::Block::HamleDT::ID::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
}



#------------------------------------------------------------------------------
# Fixes known issues in lemma, tag and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # After UD release 2.1, we generated MorphInd analysis for every word and stored it in the MISC column.
        # http://septinalarasati.com/morphind/ (Septina Dian Larasati)
        # Because it is a MISC attribute, any | and & were escaped; decode them.
        my @morphind = map {s/&vert;/|/g; s/&amp;/&/g; $_} (grep {m/^MorphInd=/} ($node->get_misc()));
        if(scalar(@morphind)>0)
        {
            $morphind[0] =~ m/^MorphInd=\^(.*)\$$/;
            my $morphind = $1;
            # Simple words have just lemma, lemma tag and POS tag:
            # ini<b>_B--
            if($morphind =~ m/^([^_]+)_(...)$/)
            {
                my $lemma = $1;
                my $tag = $2;
                $lemma = $self->normalize_lemma($lemma);
                $node->set_lemma($lemma) unless($lemma eq '');
                $node->set_conll_pos($tag);
                # Features.
                $self->set_features($node, $tag);
            }
            # peN+huni<v>_NSD+dia<p>_PS3
            elsif($morphind =~ m/^([^_]+)_(...)\+([^_]+)_(P..)$/)
            {
                my $lemma = $1;
                my $tag = $2;
                my $plemma = $3;
                my $ptag = $4;
                $lemma = $self->normalize_lemma($lemma);
                $node->set_lemma($lemma) unless($lemma eq '');
                $node->set_conll_pos("$tag+$ptag");
                # Features.
                $self->set_features($node, $tag);
                $self->set_features($node, 'Poss'.$ptag);
            }
            # siapa<w>_W--+kah<t>_T
            # http://indodic.com/affixeng.html
            elsif($morphind =~ m/^([^_]+)_(...)\+([kl]ah|pun)<t>_T--$/)
            {
                # The -kah suffix marks the focus word of a question.
                # We may want to define a language-specific feature for that but right now we must just discard it.
                # The -lah suffix has many different and confusing usages but for simplicity we can say it is often used to give emphasis, to soften a command or to add politeness to an expression. Only about one in every 400 words in Indonesian publications will have the "-lah" suffix.
                my $lemma = $1;
                my $tag = $2;
                my $ptag = 'T--';
                $lemma = $self->normalize_lemma($lemma);
                $node->set_lemma($lemma) unless($lemma eq '');
                $node->set_conll_pos("$tag+$ptag");
                # Features.
                $self->set_features($node, $tag);
            }
            # Pronominal prefix of verb is a subject clitic.
            elsif($morphind =~ m/^([^_]+)_(P..)\+([^_]+)_(V..)(?:\+([kl]ah<t>)_(T--))?$/)
            {
                my $plemma = $1;
                my $ptag = $2;
                my $lemma = $3;
                my $tag = $4;
                my $ttag = $6;
                $tag .= "+$ttag" if(defined($ttag));
                $lemma = $self->normalize_lemma($lemma);
                $node->set_lemma($lemma) unless($lemma eq '');
                $node->set_conll_pos("$ptag+$tag");
                # Features.
                $self->set_features($node, $tag);
                $self->set_features($node, $ptag);
                $node->iset()->clear('prontype');
            }
            # anti<a>_ASP+gizi<n>_NSD
            # The prefix anti- has the same function as in English.
            # para- similar to English para-
            # pasca- similar to English post-
            elsif($morphind =~ m/^([^_]+)(?:<a>_ASP|<r>_R--|<f>_F--|<x>_X--)\+([^_]+)_(...)$/)
            {
                my $lemma = $1.$2;
                my $tag = $3;
                $lemma = $self->normalize_lemma($lemma);
                $node->set_lemma($lemma) unless($lemma eq '');
                $node->set_conll_pos($tag);
                # Features.
                $self->set_features($node, $tag);
            }
            # Prefixes tagged G-- signal negation.
            # ke+tidak<g>_G--+jelas<a>+an_NSD (form: ketidakjelasan)
            elsif($morphind =~ m/^[^_]+<g>_G--\+([^_]+)_(...)$/)
            {
                my $lemma = $1;
                my $tag = $2;
                $lemma = $self->normalize_lemma($lemma);
                $node->set_lemma($lemma) unless($lemma eq '');
                $node->set_conll_pos($tag);
                # Features.
                $self->set_features($node, $tag);
                $node->iset()->set('polarity', 'neg');
            }
            # Some unknown words actually do contain the underscore:
            # assisted_gps<x>_X--
            elsif($morphind =~ m/^[^<>]+<x>_X--$/)
            {
                $node->set_lemma(lc($node->form()));
            }
            else
            {
                my $form = $node->form();
                log_warn("Unexpected MorphInd format: $morphind (form: $form)");
                $node->set_lemma(lc($form));
            }
        }
    }
}



#------------------------------------------------------------------------------
# Cleans up a lemma candidate taken from MorphInd.
#------------------------------------------------------------------------------
sub normalize_lemma
{
    my $self = shift;
    my $lemma = shift;
    # Example string from MorphInd: everything left of the underscore is the lemma candidate, the three characters on the right are the POS tag.
    # ini<b>_B--
    # Remove lemma tags (for example "<b>") from the lemma.
    $lemma =~ s/<.>//g;
    # Remove morpheme boundaries from the lemma.
    $lemma =~ s/\+//g unless($lemma =~ m/^\++$/);
    # Uppercase lemma characters trigger morphonological changes but we don't want them in the lemma.
    # (On the other hand, we would like to have capitalized lemmas of proper nouns but we would need to look at the original form and use heuristics to achieve that.)
    $lemma = lc($lemma);
    return $lemma;
}



#------------------------------------------------------------------------------
# Sets individual interset features based on MorphInd three-character POS tag.
# Ideally we should just call Lingua::Interset::decode() but the driver for
# MorphInd is not available at present. ###!!!
#------------------------------------------------------------------------------
sub set_features
{
    my $self = shift;
    my $node = shift;
    my $tag = shift;
    if($tag =~ m/^N([SP])([MFD])$/)
    {
        my $n = $1;
        my $g = $2;
        $node->iset()->set('number', $n eq 'P' ? 'plur' : 'sing');
        $node->iset()->set('gender', $g eq 'F' ? 'fem' : 'masc') unless($g eq 'D');
    }
    elsif($tag =~ m/^P([SP])([123])$/)
    {
        my $n = $1;
        my $p = $2;
        $node->iset()->set('prontype', 'prs');
        $node->iset()->set('number', $n eq 'P' ? 'plur' : 'sing');
        $node->iset()->set('person', $p);
        if($node->lemma() eq 'kami')
        {
            $node->iset()->set('clusivity', 'ex');
        }
        elsif($node->lemma() eq 'kita')
        {
            $node->iset()->set('clusivity', 'in');
        }
        if($node->lemma() =~ m/^(saya|anda|beliau)$/)
        {
            $node->iset()->set('polite', 'form');
        }
        elsif($node->lemma() =~ m/^(aku|engkau|kamu)$/)
        {
            $node->iset()->set('polite', 'infm');
        }
    }
    elsif($tag =~ m/^PossP([SP])([123])$/)
    {
        my $n = $1;
        my $p = $2;
        $node->iset()->set('possnumber', $n eq 'P' ? 'plur' : 'sing');
        $node->iset()->set('possperson', $p);
    }
    elsif($tag =~ m/^B--$/)
    {
        # ini = this, it
        # itu = that, it
        # begini = like this (takovýhle)
        # para = the
        # tersebut = mentioned
        if($node->lemma() =~ m/^((beg)?(ini|itu)|para|tersebut)$/)
        {
            $node->iset()->set('prontype', 'dem');
        }
        # segala = all
        # segenap = all
        # semua = all, every
        # setiap = every, each
        # tiap = each
        # seluruh = whole, entire
        # keseluruhan = whole
        elsif($node->lemma() =~ m/^(segala|segenap|semua|setiap|tiap|seluruh|keseluruhan)$/)
        {
            $node->iset()->set('prontype', 'tot');
        }
        # sebuah = a, an
        # seorang = a, an
        # suatu = one, some
        # berbagai = various
        # adanya = existing
        # tertentu = certain
        elsif($node->lemma() =~ m/^(sebuah|seorang|suatu|berbagai|adanya|tertentu)$/)
        {
            $node->iset()->set('prontype', 'ind');
        }
        # sepasang = pair, couple
        # beberapa = some, several, few
        # sejumlah = a number of
        # banyak = many, much
        elsif($node->lemma() =~ m/^(beberapa|sepasang|sejumlah|banyak)$/)
        {
            $node->iset()->set('prontype', 'ind');
            $node->iset()->set('numtype', 'card');
        }
    }
    elsif($tag =~ m/^V([SP])([AP])$/)
    {
        my $n = $1;
        my $v = $2;
        $node->iset()->set('number', $n eq 'P' ? 'plur' : 'sing');
        $node->iset()->set('voice', $v eq 'P' ? 'pass' : 'act');
    }
    elsif($tag =~ m/^A([SP])([PS])$/)
    {
        my $n = $1;
        my $d = $2;
        $node->iset()->set('number', $n eq 'P' ? 'plur' : 'sing');
        $node->iset()->set('degree', $d eq 'S' ? 'sup' : 'pos');
    }
    elsif($tag =~ m/^W--$/)
    {
        $node->iset()->set('prontype', 'int');
    }
    # MorphInd documentation claims that S-- means "subordinating conjunction".
    # But it is also assigned to the very frequent relative pronoun "yang".
    elsif($tag =~ m/^S--$/)
    {
        # If the UPOS tag is PRON or DET, the main Interset part of speech will be noun or adj.
        # This way we can distinguish relative pronouns/determiners from real subordinating conjunctions.
        if($node->is_noun() || $node->is_adjective())
        {
            $node->iset()->set('prontype', 'rel');
        }
    }
    # Remaining tags are featureless. Just one character and two dashes.
    # H ... coordinating conjunction
    # F ... foreign word
    # R ... preposition
    # M ... modal
    # D ... adverb
    # T ... particle
    # G ... negation
    # I ... interjection
    # O ... copula
    # X ... unknown
    # Z ... punctuation
}



#------------------------------------------------------------------------------
# After changes done to Interset (including part of speech) generates the
# universal part-of-speech tag anew.
#------------------------------------------------------------------------------
sub regenerate_upos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        $node->set_tag($node->iset()->get_upos());
    }
}



#------------------------------------------------------------------------------
# Collects all nodes in a subtree of a given node. Useful for fixing known
# annotation errors, see also get_node_spanstring(). Returns ordered list.
#------------------------------------------------------------------------------
sub get_node_subtree
{
    my $self = shift;
    my $node = shift;
    my @nodes = $node->get_descendants({'add_self' => 1, 'ordered' => 1});
    return @nodes;
}



#------------------------------------------------------------------------------
# Collects word forms of all nodes in a subtree of a given node. Useful to
# uniquely identify sentences or their parts that are known to contain
# annotation errors. (We do not want to use node IDs because they are not fixed
# enough in all treebanks.) Example usage:
# if($self->get_node_spanstring($node) =~ m/^peça a URV em a sua mesada$/)
#------------------------------------------------------------------------------
sub get_node_spanstring
{
    my $self = shift;
    my $node = shift;
    my @nodes = $self->get_node_subtree($node);
    return join(' ', map {$_->form() // ''} (@nodes));
}



1;

=over

=item Treex::Block::HamleDT::ZH::FixUD

This is a temporary block that should fix selected known problems in the Indonesian UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
