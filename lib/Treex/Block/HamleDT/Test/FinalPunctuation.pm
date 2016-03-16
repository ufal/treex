package Treex::Block::HamleDT::Test::FinalPunctuation;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_zone
{
    my $self  = shift;
    my $zone  = shift;
    my $root  = $zone->get_atree();
    my @nodes = $root->get_descendants({'ordered' => 1});
    return if(!@nodes);
    # Mimic the function HamleDT::CoNLL2PDTStyle::attach_final_punctuation_to_root().
    # Just check attachment instead of attaching.
    my $rule1chars = '[-\.\x{2026}\x{964}\x{965}?!\x{61F};:,\x{61B}\x{60C}\x{2010}-\x{2015}]';
    my $rule2chars = '["`'."'".'\x{2018}-\x{201F}]';
    # Try rule 2 first (rule 1 will have to be checked anyway).
    my $rule1 = 0;
    my $rule2 = 0;
    my $rule1i0;
    my $rule2i0;
    my $rule1i1 = $#nodes;
    my $i = $#nodes;
    # Do not touch the last node if it heads coordination or apposition.
    return if($i>=0 && $nodes[$i]->deprel() =~ m/^(Coord|Apos)$/);
    while($i>=0 && $nodes[$i]->form() =~ m/^$rule2chars+$/)
    {
        $rule2 = 1;
        $rule2i0 = $i;
        $i--;
    }
    # Do not touch the last node if it heads coordination or apposition.
    return if($i>=0 && $nodes[$i]->deprel() =~ m/^(Coord|Apos)$/);
    while($i>=0 && $nodes[$i]->form() =~ m/^$rule1chars+$/)
    {
        $rule1 = 1;
        $rule1i0 = $i;
        $i--;
    }
    # Do not touch the last node if it heads coordination or apposition.
    return if($rule1i0>=0 && $rule1i0<=$#nodes && $nodes[$rule1i0]->deprel() =~ m/^(Coord|Apos)$/);
    if($rule2 && $rule1)
    {
        $rule1i1 = $rule2i0-1;
        for(my $i = $rule2i0; $i<=$#nodes; $i++)
        {
            if($nodes[$i]->parent() != $root)
            {
                $self->complain($nodes[$i], 'parent is not root');
            }
            elsif(!defined($nodes[$i]->deprel()) || $nodes[$i]->deprel() ne 'AuxG')
            {
                $self->complain($nodes[$i], 'deprel is '.$nodes[$i]->deprel().' instead of AuxG');
            }
            elsif($nodes[$i]->children())
            {
                $self->complain($nodes[$i], 'punctuation is not leaf');
            }
        }
    }
    if($rule1)
    {
        for(my $i = $rule1i0; $i<=$rule1i1; $i++)
        {
            my $expected_deprel;
            if($nodes[$i]->form() =~ m/^,\x{60C}$/)
            {
                $expected_deprel = 'AuxX';
            }
            else
            {
                $expected_deprel = 'AuxK';
            }
            if($nodes[$i]->parent() != $root)
            {
                $self->complain($nodes[$i], 'parent is not root');
            }
            elsif(!defined($nodes[$i]->deprel()) || $nodes[$i]->deprel() ne $expected_deprel)
            {
                $self->complain($nodes[$i], 'deprel is '.$nodes[$i]->deprel().' instead of '.$expected_deprel);
            }
            elsif($nodes[$i]->children())
            {
                $self->complain($nodes[$i], 'punctuation is not leaf');
            }
        }
    }
}

sub attach_final_punctuation_to_root
{
    my $self  = shift;
    my $root  = shift;
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
            $nodes[$i]->set_deprel('AuxG');
        }
    }
    if($rule1)
    {
        for(my $i = $rule1i0; $i<=$rule1i1; $i++)
        {
            $nodes[$i]->set_parent($root);
            if($nodes[$i]->form() =~ m/^,\x{60C}$/)
            {
                $nodes[$i]->set_deprel('AuxX');
            }
            else
            {
                $nodes[$i]->set_deprel('AuxK');
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::FinalPunctuation

Sentence-final punctuation should be attached directly to root, with the AuxK deprel.

There will be exceptions, e.g. if the sentence ends with a period and a quotation mark (in that order),
the current annotation scheme of PDT attaches the period as AuxK of the root, and the quotation mark
as AuxG of the main predicate (non-projectively!) We may want to change this in HamleDT.

=back

=cut

# Copyright 2013 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
