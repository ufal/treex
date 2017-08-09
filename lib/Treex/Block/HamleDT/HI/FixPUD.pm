package Treex::Block::HamleDT::HI::FixPUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Core::Block';



sub process_anode
{
    my $self = shift;
    my $node = shift;
    #--------------------------------------------------------------------------
    # PART OF SPEECH
    if ($node->deprel() eq 'mark' && $node->form() =~ m/^(कि|क्योंकि|हालांकि|चाहे|यद्यपि|मानो|यदि|इसलिए|जब|तब|जबतक|तबतक|जबकि|जैसाकि|जैसेकि|जहां|जैसे|वैसे|ऐसा|ऐसी|तो|इफ)$/)
    {
        $node->iset()->set_hash({'pos' => 'conj', 'conjtype' => 'sub'});
    }
    #--------------------------------------------------------------------------
    # DEPENDENCY RELATIONS
    # I don't know what attr is supposed to mean. There are two occurrences.
    # It seems to be non-verbal predicate so maybe it should be restructured.
    if ($node->deprel() eq 'attr')
    {
        $node->set_deprel('xcomp');
    }
    # Compound:plur is a conversion error (it would work in Indonesian).
    elsif ($node->deprel() eq 'compound:plur')
    {
        $node->set_deprel('compound:redup');
    }
    # Neg seems to be an annotation error. There is only one occurrence.
    elsif ($node->deprel() eq 'neg')
    {
        $node->set_deprel('case');
    }
    # Obl:poss is a conversion error, it should be nmod:poss (unless it is also an annotation error).
    elsif ($node->deprel() eq 'obl:poss')
    {
        $node->set_deprel('nmod:poss');
    }
    # Ref attaches a relative pronoun to its antecedent. Instead, it should be part of the relative clause.
    elsif ($node->deprel() eq 'ref')
    {
        my $form = $node->form();
        # The right sibling should be an acl:relcl.
        my $rs = $node->get_right_neighbor();
        # थे is an annotation error.
        if ($form eq 'थे')
        {
            $node->set_deprel('aux');
        }
        # In one case the sibling is not attached as acl:relcl but I think the relative pronoun should still be attached to it.
        elsif (defined($rs)) # && $rs->deprel() eq 'acl:relcl'
        {
            my @children = $rs->get_children({'ordered' => 1});
            my $candidate = scalar(@children) > 0 ? $children[0] : $rs;
            if ($form =~ m/^(जिसने|जिन्होंने)$/)
            {
                $node->set_parent($rs);
                $node->set_deprel('nsubj');
            }
            elsif ($form =~ m/^(जिसे|जिन्हें)$/)
            {
                $node->set_parent($rs);
                $node->set_deprel('obj');
            }
            # Note that इसमें is probably an annotation error.
            elsif ($form =~ m/^(जिसमें|जिनमें|जिससे|जिनसे|जिसपर|जहां|जब|इसमें)$/)
            {
                $node->set_parent($rs);
                $node->set_deprel('obl');
            }
            elsif ($form =~ m/^(जिसका|जिनका|जिसकी|जिनकी|जिसके|जिनके)$/)
            {
                $node->set_parent($candidate);
                $node->set_deprel('nmod:poss');
                ###!!! set MISC ToDo=RelPoss?
            }
            elsif ($form eq 'जो')
            {
                $node->set_parent($rs);
                $node->set_deprel('nsubj');
                my @misc;
                @misc = split(/\|/, $node->wild()->{misc}) if (exists($node->wild()->{misc}) && defined($node->wild()->{misc}));
                push(@misc, 'ToDo=जो');
                $node->wild()->{misc} = join('|', @misc);
            }
            # If there is punctuation to the left of the relative word, it should not be attached to the relative word.
            my @punct = grep {$_->deprel() eq 'punct' && $_->ord() < $node->ord()} ($node->children());
            foreach my $p (@punct)
            {
                $p->set_parent($node->parent());
            }
        }
        else
        {
            ###!!! We don't have the candidate for the new parent. So what?
            # In one case the ref was already attached to the head of the relative clause.
            if ($form =~ m/^(जिसने|जिन्होंने)$/ && $node->parent()->deprel() eq 'acl:relcl')
            {
                $node->set_deprel('nsubj');
            }
        }
    }
    # Auxiliary verbs must be tagged AUX, not VERB.
    if ($node->is_verb() && $node->deprel() =~ m/^aux(:|$)/)
    {
        $node->iset()->set('verbtype' => 'aux');
    }
    # Punctuation must be tagged PUNCT, not X.
    if ($node->form() =~ m/^\pP+$/ && $node->deprel() eq 'punct')
    {
        $node->iset()->set_hash({'pos' => 'punc'});
    }
    # वाले: Google attaches it to previous word as affix. Martin makes it PART and fixed.
    # I would make it compound (and perhaps PART).
    # However, in UD Hindi 2.0 it is ADP and case. And we want to be consistent with UD Hindi.
    if (any {$_ eq 'ToDo=affix'} ($node->get_misc()))
    {
        # However, these "postpositions" have gender, number and sometimes case. Let's not discard it!
        $node->iset()->set('pos' => 'adp');
        $node->set_deprel('case');
        $node->set_misc(grep {$_ ne 'ToDo=affix'} ($node->get_misc()));
    }
    #--------------------------------------------------------------------------
    # TREE STRUCTURE
    # Postpositions are often attached to the right as siblings of their noun phrases,
    # rather than to the left as children of their noun phrases.
    if ($node->is_adposition() && $node->deprel() eq 'case' && $node->parent()->ord() > $node->ord())
    {
        my $ls = $node->get_left_neighbor();
        if (defined($ls))
        {
            # We don't even check whether the left sibling is a noun. It can be an infinitive.
            $node->set_parent($ls);
        }
    }
    # Sentence-initial coordinating conjunction is sometimes attached as dep but it should be cc.
    if ($node->is_coordinator() && $node->deprel() eq 'dep')
    {
        $node->set_deprel('cc');
    }
    # Multiple objects: if one of them has the postposition 'को', label it as indirect object.
    my @obj = grep {$_->deprel() =~ m/^(obj|ccomp)(:|$)/} ($node->children());
    if (scalar(@obj) > 1)
    {
        my @ko = grep {my $c = $_; any {$_->form() eq 'को'} ($c->children());} (@obj);
        foreach my $ko (@ko)
        {
            $ko->set_deprel('iobj');
        }
    }
    # If there are still two objects, one of them obj and the other ccomp, assume that the ccomp should depend on the obj.
    @obj = grep {$_->deprel() =~ m/^(obj|ccomp)(:|$)/} ($node->children());
    if (scalar(@obj) == 2 && $obj[0]->deprel() eq 'obj' && $obj[1]->deprel() eq 'ccomp')
    {
        $obj[1]->set_parent($obj[0]);
        $obj[1]->set_deprel('acl');
    }
    # An infinitive attached to another verb should not be acl but xcomp.
    # The Google annotation does not contain VerbForm=Inf but the XPOS tag is VINF.
    if ($node->conll_pos() eq 'VINF')
    {
        $node->iset()->set('verbform', 'inf');
        if ($node->parent()->is_verb() && $node->deprel() eq 'acl')
        {
            $node->set_deprel('xcomp');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HI::FixPUD

Fixes certain known problems with Google annotation of the Hindi part of the parallel treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
