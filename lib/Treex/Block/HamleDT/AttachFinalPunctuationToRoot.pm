package Treex::Block::HamleDT::AttachFinalPunctuationToRoot;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_atree {
    my ($self, $root) = @_;

    my @nodes = $root->get_descendants({'ordered' => 1});
    # Rule 1: If the last token (or sequence of tokens) is
    # - a period ('.') or three dots ('...' or the corresponding Unicode character) or devanagari danda
    # - question or exclamation mark ('?', '!', Arabic question mark)
    # - semicolon, colon, comma or dash (';', ':', ',', '-', Arabic semicolon or comma, Unicode dashes)
    # - any combination of the above
    # => then all these nodes are attached directly to the root.
    # => comma is AuxX, anything else is AuxK
    # Rule 2: If the last token (or sequence of tokens) is
    # - single or double quotation mark ("ASCII", ``Penn-style'', or Unicode)
    # - and if it is preceded by anything matching Rule 1
    # => then it is attached to the root and labeled AuxG
    # => the preceding punctuation is treated according to Rule 1
    # - note that we currently do not attempt to find out whether the corresponding initial quotation mark is present
    # - (normally we want to know whether quotation marks are paired)
    # - also note that if there are tokens matching Rule 1 after the quotation mark, then the quotation mark is not affected by this function at all
    #   and other methods that normalize punctuation inside the sentence will apply
    # Note that nothing happens if the final token is a bracket, a slash or a less common symbol.
    my $rule1chars = '[-\.\x{2026}\x{964}\x{965}?!\x{61F};:,\x{61B}\x{60C}\x{2010}-\x{2015}]';
    my $rule2chars = '["`'."'".'\x{2018}-\x{201F}]';
    # Try rule 2 first (rule 1 will have to be checked anyway).
    my $rule1 = 0;
    my $rule2 = 0;
    my $rule1i0;
    my $rule2i0;
    my $rule1i1 = $#nodes;
    my $i = $#nodes;
    while($i>=0 && $nodes[$i]->form() =~ m/^$rule2chars+$/)
    {
        $rule2 = 1;
        $rule2i0 = $i;
        $i--;
    }
    while($i>=0 && $nodes[$i]->form() =~ m/^$rule1chars+$/)
    {
        $rule1 = 1;
        $rule1i0 = $i;
        $i--;
    }
    if($rule2 && $rule1)
    {
        $rule1i1 = $rule2i0-1;
        for(my $i = $rule2i0; $i<=$#nodes; $i++)
        {
            $nodes[$i]->set_parent($root);
            $nodes[$i]->set_afun('AuxG');
            # Even though some treebanks think otherwise, final punctuation marks are neither conjunctions nor conjuncts.
            delete($nodes[$i]->wild()->{conjunct});
            delete($nodes[$i]->wild()->{coordinator});
            $nodes[$i]->set_is_member(0);
            # Sentence-terminating punctuation should be a leaf node.
            # If it governs anything it should be probably reattached to the root.
            foreach my $child ($nodes[$i]->children())
            {
                $child->set_parent($root);
                if($child->get_iset('pos') eq 'verb')
                {
                    $child->set_afun('Pred');
                }
                else
                {
                    $child->set_afun('ExD');
                }
            }
        }
    }
    if($rule1)
    {
        for(my $i = $rule1i0; $i<=$rule1i1; $i++)
        {
            $nodes[$i]->set_parent($root);
            if($nodes[$i]->form() =~ m/^,\x{60C}$/)
            {
                $nodes[$i]->set_afun('AuxX');
            }
            else
            {
                $nodes[$i]->set_afun('AuxK');
            }
            delete($nodes[$i]->wild()->{conjunct});
            delete($nodes[$i]->wild()->{coordinator});
            $nodes[$i]->set_is_member(0);
            # Sentence-terminating punctuation should be a leaf node.
            # If it governs anything it should be probably reattached to the root.
            foreach my $child ($nodes[$i]->children())
            {
                $child->set_parent($root);
                if($child->get_iset('pos') eq 'verb')
                {
                    $child->set_afun('Pred');
                }
                else
                {
                    $child->set_afun('ExD');
                }
            }
        }
    }

    return;
}

1;

=head1 NAME 

Treex::Block::HamleDT::AttachFinalPunctuationToRoot

=head1 DESCRIPTION

Examines the last node of the sentence. If it is a punctuation, makes sure
that it is attached to the artificial root node. We deviate here from PDT.
In PDT, if there is a quotation mark after sentence-terminating period, they
attach it non-projectively to the main predicate. We remove the non-
projectivity and attach the quotation mark directly to the root. It is in
line with the rule that quotation marks should be attached to the root of the
stuff inside.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

