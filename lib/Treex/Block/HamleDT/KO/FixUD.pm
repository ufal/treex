package Treex::Block::HamleDT::KO::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
use Treex::Tool::PhraseBuilder::StanfordToUD;
extends 'Treex::Core::Block';
# The following libraries are currently available in the old part of TectoMT.
use translit; # Dan's transliteration library
use translit::greek; # Dan's transliteration table for Greek script
use translit::cyril; # Dan's transliteration table for Cyrillic script
use translit::armen; # Dan's transliteration table for Armen script
use translit::arab; # Dan's transliteration table for the Arabic script
use translit::urdu; # variant of Arabic script for Urdu
use translit::uyghur; # variant of Arabic script for Uyghur
use translit::brahmi; # Dan's transliteration tables for Brahmi-based scripts
use translit::tibetan; # Dan's transliteration table for Tibetan script
use translit::mkhedruli; # Dan's transliteration table for Georgian script
use translit::ethiopic; # Dan's transliteration table for Ethiopic (Amharic) script
use translit::khmer; # Dan's transliteration table for Khmer script
use translit::hebrew; # Rudolf's transliteration table for Hebrew script
use translit::hangeul; # Dan's transliteration table for Korean Hangeul script
use translit::han2pinyin; # Dan's conversion of Han characters to pinyin (table from Unicode.org)
has 'table' => (isa => 'HashRef', is => 'ro', default => sub {{}});
has 'maxl' => (isa => 'Int', is => 'rw', default => 1, writer => '_set_maxl');
has 'language' => (isa => 'Str', is => 'ro'); # source language code (optional)
has 'scientific' => (isa => 'Bool', is => 'rw', default => 1); # romanization type



#------------------------------------------------------------------------------
# Initializes the transliteration tables.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    my $arg_ref = shift;
    my $table = $self->table();
    my $language = $self->language(); # optional source language code
    my $scientific = $self->scientific(); # type of romanization
    # 0x374: Greek script.
    translit::greek::inicializovat($table);
    # 0x400: Cyrillic.
    translit::cyril::inicializovat($table, $language);
    # 0x500: Armenian script.
    translit::armen::inicializovat($table);
    # 0x600: Arabic script.
    if($language eq 'ug')
    {
        translit::uyghur::inicializovat($table);
    }
    elsif($language eq 'ur')
    {
        translit::urdu::inicializovat($table);
    }
    else
    {
        translit::arab::inicializovat($table);
    }
    # 0x900: Devanagari script (Hindi etc.)
    translit::brahmi::inicializovat($table, 2304, $scientific);
    # 0x980: Bengali script.
    translit::brahmi::inicializovat($table, 2432, $scientific);
    # 0xA00: Gurmukhi script (for Punjabi).
    translit::brahmi::inicializovat($table, 2560, $scientific);
    # 0xA80: Gujarati script.
    translit::brahmi::inicializovat($table, 2688, $scientific);
    # 0xB00: Oriya script.
    translit::brahmi::inicializovat($table, 2816, $scientific);
    # 0xB80: Tamil script.
    translit::brahmi::inicializovat($table, 2944, $scientific ? 2 : 0);
    # 0xC00: Telugu script.
    translit::brahmi::inicializovat($table, 3072, $scientific);
    # 0xC80: Kannada script.
    translit::brahmi::inicializovat($table, 3200, $scientific);
    # 0xD00: Malayalam script.
    translit::brahmi::inicializovat($table, 3328, $scientific);
    # 0xF00: Tibetan script.
    translit::tibetan::inicializovat($table);
    # 0x10A0: Georgian script.
    translit::mkhedruli::inicializovat($table);
    # 0x1200: Ethiopic script (for Amhar etc.)
    translit::ethiopic::inicializovat($table);
    # 0x1780: Khmer script.
    translit::khmer::inicializovat($table);
    # Hebrew script
    translit::hebrew::inicializovat($table);
    # Korean Hangeul script
    translit::hangeul::inicializovat($table);
    # Figure out and return the maximum length of an input sequence.
    my $maxl = 1; map {$maxl = max2($maxl, length($_))} (keys(%{$table}));
    $self->_set_maxl($maxl);
}



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_relations($root);
    # Coordinating conjunctions and punctuation should now be attached to the following conjunct.
    # The Coordination phrase class already outputs the new structure, hence simple
    # conversion to phrases and back should do the trick.
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToUD
    (
        'prep_is_head'           => 0,
        'coordination_head_rule' => 'first_conjunct'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
}



#------------------------------------------------------------------------------
# Fixes known issues in features. For Korean, this also means retokenization!
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    # We will have to recompute transliteration of nodes that we retokenize.
    my $table = $self->table();
    my $maxl = $self->maxl();
    my @nodes = $root->get_descendants({ordered => 1});
    my @nodes_to_delete;
    foreach my $node (@nodes)
    {
        # Rejoin nouns with case-marking postpositions.
        if($node->is_particle() && scalar($node->children())==0)
        {
            my $parent = $node->parent();
            # Do not check that the parent is noun. There are similar patterns
            # with adjectives, gerunds etc.
            if(#$parent->is_noun() &&
                $parent->ord() == $node->ord()-1 && $parent->no_space_after())
            {
                $parent->set_misc_attr('MSeg', $parent->form().'-'.$node->form());
                $parent->set_lemma($parent->form());
                $parent->set_form($parent->form().$node->form());
                $parent->set_no_space_after($node->no_space_after());
                $parent->set_conll_pos($parent->conll_pos().'+'.$node->conll_pos());
                $parent->iset()->merge_hash_soft($node->iset()->get_hash());
                my $translit = translit::prevest($table, $parent->form(), $maxl);
                $translit = translit::han2pinyin::pinyin($translit); ###!!! BETA
                $parent->set_attr('translit', $translit);
                my $ltranslit = translit::prevest($table, $parent->lemma(), $maxl);
                $ltranslit = translit::han2pinyin::pinyin($ltranslit); ###!!! BETA
                $parent->set_attr('ltranslit', $ltranslit);
                push(@nodes_to_delete, $node);
            }
        }
        # Set lemma of punctuation, numbers and remaining particles to the form.
        if($node->form() =~ m/^[\d\pP]+$/ || $node->is_particle())
        {
            $node->set_lemma($node->form());
        }
    }
    foreach my $node (@nodes_to_delete)
    {
        $node->remove(); # will take care of renumbering ords of the other nodes
    }
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
# Fixes known issues in dependency relations.
#------------------------------------------------------------------------------
sub fix_relations
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if($deprel eq 'numc')
        {
            $deprel = 'flat';
        }
        elsif($deprel eq 'precomp')
        {
            $deprel = 'compound:lvc';
        }
        elsif($deprel eq 'obl:poss')
        {
            $deprel = 'obl';
        }
        elsif($deprel eq 'pref')
        {
            $deprel = 'det';
        }
        $node->set_deprel($deprel);
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



#------------------------------------------------------------------------------
# Returns maximum of two values.
#------------------------------------------------------------------------------
sub max2
{
    my $a = shift;
    my $b = shift;
    return $a>=$b ? $a : $b;
}



1;

=over

=item Treex::Block::HamleDT::KO::FixUD

This is a temporary block that should fix selected known problems in the Korean UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016-2018 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
