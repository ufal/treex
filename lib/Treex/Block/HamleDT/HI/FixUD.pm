package Treex::Block::HamleDT::HI::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    #$self->fix_features($root);
    $self->fix_auxiliary_lemmas($root);
    $self->fix_functional_leaves($root);
}



#------------------------------------------------------------------------------
# Fix lemmas of auxiliary verbs so that they can be identified by the
# validator.
#------------------------------------------------------------------------------
sub fix_auxiliary_lemmas
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->tag() eq 'AUX' && $node->lemma() eq 'पड')
        {
            $node->set_lemma('पड़');
        }
    }
}



#------------------------------------------------------------------------------
# Makes sure that functional nodes do not have children other than the
# exceptions permitted by guidelines.
#------------------------------------------------------------------------------
sub fix_functional_leaves
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Functional nodes normally do not have modifiers of their own, with a few
        # exceptions, such as coordination. Most modifiers should be attached
        # directly to the content word.
        my @badchildren;
        if($node->deprel() =~ m/^(aux|cop)(:|$)/)
        {
            @badchildren = grep {$_->deprel() !~ m/^(goeswith|fixed|reparandum|conj|cc|punct)(:|$)/} ($node->children());
        }
        elsif($node->deprel() =~ m/^(case|mark)(:|$)/)
        {
            @badchildren = grep {$_->deprel() !~ m/^(advmod|obl|goeswith|fixed|reparandum|conj|cc|punct)(:|$)/} ($node->children());
        }
        elsif($node->deprel() =~ m/^(cc)(:|$)/)
        {
            @badchildren = grep {$_->deprel() !~ m/^(goeswith|fixed|reparandum|conj|punct)(:|$)/} ($node->children());
        }
        elsif($node->deprel() =~ m/^(fixed)(:|$)/)
        {
            @badchildren = grep {$_->deprel() !~ m/^(goeswith|reparandum|conj|punct)(:|$)/} ($node->children());
        }
        elsif($node->deprel() =~ m/^(goeswith)(:|$)/)
        {
            @badchildren = $node->children();
        }
        elsif($node->deprel() =~ m/^(punct)(:|$)/)
        {
            @badchildren = grep {$_->deprel() !~ m/^(punct)(:|$)/} ($node->children());
        }
        if(scalar(@badchildren) > 0)
        {
            my $parent = $node->parent();
            while($parent->deprel() =~ m/^(aux|cop|case|mark|cc|punct|fixed|goeswith)(:|$)/)
            {
                $parent = $parent->parent();
            }
            foreach my $child (@badchildren)
            {
                $child->set_parent($parent);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Features are stored in conll/feat and their format is not compatible with
# Universal Dependencies.
#------------------------------------------------------------------------------
sub fix_features
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $shakfeatures = $node->conll_feat();
        $shakfeatures = '' if(!defined($shakfeatures) || $shakfeatures eq '_');
        # Discard features with empty values.
        my @shakfeatures = grep {!m/-(any)?$/} (split(/\|/, $shakfeatures));
        # Some features will be preserved in the MISC field.
        my @miscfeatures;
        my @morfeatures;
        my $cat = '_';
        foreach my $feature (@shakfeatures)
        {
            if($feature =~ m/^(chunkId|chunkType|stype)-/)
            {
                $feature =~ s/^(.)/\u$1/;
                $feature =~ s/-/=/;
                push(@miscfeatures, $feature);
            }
            elsif($feature =~ m/^cat-(.*)$/)
            {
                $cat = $1;
            }
            elsif($feature =~ m/^(vib|tam)-/)
            {
                push(@morfeatures, $feature);
                $feature =~ s/^(.)/\u$1/;
                $feature =~ s/-/=/;
                push(@miscfeatures, $feature);
            }
            else
            {
                push(@morfeatures, $feature);
            }
        }
        # Convert the remaining features to Interset.
        # The driver hi::conll also expects the Hyderabad CPOS tag, which we now have in the POS column.
        my $conll_pos = $node->conll_pos();
        my $conll_feat = scalar(@morfeatures)>0 ? join('|', @morfeatures) : '_';
        my $src_tag = "$conll_pos\t$cat\t$conll_feat";
        my $f = decode('hi::conll', $src_tag);
        # Changed features may cause a change of UPOS but it is probably not desirable. Or is it?
        my $tag0 = $node->tag();
        my $tag1 = $f->get_upos();
        if($tag1 ne $tag0)
        {
            # Adjust Interset to the original tag.
            $f->set_upos($tag0);
            unless($tag1 eq 'X')
            {
                unshift(@miscfeatures, "AltTag=$tag0-$tag1");
            }
            # Only replace the original tag if it is an error.
            if($tag0 !~ m/^(NOUN|PROPN|PRON|ADJ|DET|NUM|VERB|AUX|ADV|ADP|CONJ|SCONJ|PART|INTJ|SYM|PUNCT|X)$/)
            {
                $node->set_tag($tag1);
            }
        }
        $node->set_iset($f);
        ###!!! We do not check the previous contents of MISC because we know that in this particular data it is empty.
        $node->wild()->{misc} = join('|', @miscfeatures);
    }
}



1;

=over

=item Treex::Block::HamleDT::HI::FixUD

This is a temporary block used to prepare the Hindi UD 1.2 treebank.
We got new data from Riyaz Ahmad / IIIT Hyderabad. The data is larger than the
previous Hindi data we had, and the dependency relations already follow the UD
guidelines. However, features have to be converted.

Update: For the conversion from UD 1.4 to UD 2.0, the method fix_features() is
no longer called. The main UD 1 to 2 conversion is done in a separate block.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
