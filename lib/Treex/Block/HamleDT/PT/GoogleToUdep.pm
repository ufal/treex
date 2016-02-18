package Treex::Block::HamleDT::PT::GoogleToUdep;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToUD;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'mul::google',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Stačilo by nám process_atree(), ale nadřazená třída zatím z historických
# důvodů používá process_zone(), takže kdybychom tady použili process_atree(),
# vůbec by se nezavolalo.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    $self->convert_tags($root);
    $self->convert_deprels($root);
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToUD
    (
        'prep_is_head'           => 0,
        'coordination_head_rule' => 'first_conjunct'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
}



#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and UPOS.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self   = shift;
    my $root   = shift;
    foreach my $node ( $root->get_descendants() )
    {
        # We will want to save the original tag (or a part thereof) in conll/pos.
        my $origtag = $self->get_input_tag_for_interset($node);
        # 3 fields probably means CPOS-POS-FEAT
        # 2 fields probably means CPOS-POS
        my @fields = split(/\t/, $origtag);
        if(scalar(@fields)>=2)
        {
            $origtag = $fields[1];
            if(defined($fields[2]) && $fields[2] ne '_' && length($fields[2])<30)
            {
                $origtag .= '|'.$fields[2];
            }
        }
        # Now that we have a copy of the original tag, we can convert it.
        $self->decode_iset( $node );
        $self->set_upos_tag( $node );
        # For the case we later access the CoNLL attributes, reset them as well.
        # (We can still specify other source attributes in Write::CoNLLX and similar blocks.)
        my $tag = $node->tag(); # now the universal POS tag
        $node->set_conll_cpos($tag);
        $node->set_conll_pos($origtag);
        $node->set_conll_feat($node->iset()->as_string_conllx());
    }
}



#------------------------------------------------------------------------------
# Different source treebanks may use different attributes to store information
# needed by Interset drivers to decode the Interset feature values. By default,
# the CoNLL 2006 fields CPOS, POS and FEAT are concatenated and used as the
# input tag. If the morphosyntactic information is stored elsewhere (e.g. in
# the tag attribute), the Harmonize block of the respective treebank should
# redefine this method. Note that even CoNLL 2009 differs from CoNLL 2006.
#------------------------------------------------------------------------------
sub get_input_tag_for_interset
{
    my $self   = shift;
    my $node   = shift;
    return $node->tag();
}



my %conversion_table =
(
    'ROOT'      => 'root',
    'acomp'     => 'xcomp:adj', # "passageiro se sente prejudicado" acomp(sente, prejudicado) (doplněk)
    'adp'       => 'mark', # leaf adposition (e.g. "passar a acreditar": aux(acreditar, passar); adp(acreditar, a))
                           ###!!! Sometimes it is also attached to a nominal and it should be converted to 'case'.
                           ###!!! Example: "acarretou danos/dobj ao conjunto/iobj"
                           ###!!! Because the prepositional phrase is an object (not just modifier), they wanted the noun attached directly to the verb, and the preposition then had to go down.
    'adpcomp'   => 'scarg', # clausal argument of adposition (e.g. "para acreditar"); structural transformation needed
    'adpmod'    => 'nmod', # adpositional phrase acting as a non-core dependent
    'adpobj'    => 'adparg', # nominal argument of adposition; structural transformation needed
    'advcl'     => 'advcl',
    'advmod'    => 'advmod',
    'amod'      => 'amod',
    'appos'     => 'appos',
    'attr'      => 'pnom', # predicative attribute (nominal predicate); structural transformation needed
    'aux'       => 'aux',
    'auxpass'   => 'auxpass',
    'cc'        => 'cc',
    'ccomp'     => 'ccomp',
    'compmod'   => 'name', # Typically first name attached to last name (reversion needed). Can it be a compound noun too?
    'conj'      => 'conj',
    'csubj'     => 'csubj',
    'csubjpass' => 'csubjpass',
    'dep'       => 'dep',
    'det'       => 'det',
    'dobj'      => 'dobj',
    'infmod'    => 'acl:inf', # infinitival clause used as a non-core dependent; rare; e.g. modifying a noun in "um pedido..., a ser analisado pelo STF, ..."
    'iobj'      => 'iobj',
    'mark'      => 'mark',
    'mwe'       => 'mwe',
    'neg'       => 'neg',
    'nmod'      => 'nmod',
    'nsubj'     => 'nsubj',
    'nsubjpass' => 'nsubjpass',
    'num'       => 'nummod',
    'p'         => 'punct',
    'parataxis' => 'parataxis',
    'partmod'   => 'acl:part', # participle acting as an adjectival modifier
    'poss'      => 'det:poss', # possessive determiner (pronoun)
    'prt'       => 'expl', # the reflexive pronoun "se" when tagged as particle and used with an inherently reflexive verb ###!!! also compound:prt in Germanic languages?
    'rcmod'     => 'acl:relcl', # relative clause
    'xcomp'     => 'xcomp'
);



#------------------------------------------------------------------------------
# Convert dependency relation labels. The version 2 Universal Dependency
# Treebanks use a version of the Stanford dependencies, thus they are quite
# close but not identical to Universal Dependencies.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $parent = $node->parent();
        my $pos    = $node->iset()->pos();
        my $ppos   = $parent ? $parent->iset()->pos() : '';
        my $lemma  = $node->lemma();
        if(exists($conversion_table{$deprel}))
        {
            $deprel = $conversion_table{$deprel};
        }
        $node->set_deprel($deprel);
    }
}



1;

=over

=item Treex::Block::HamleDT::PT::GoogleToUdep

Converts Brazilian Portuguese trees from the Google Universal Dependency Treebanks
version 2 (2014, Universal Stanford Dependencies) to Universal Dependencies.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
