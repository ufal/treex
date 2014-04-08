package Treex::Block::HamleDT::IT::Harmonize;
use feature state;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'it::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);



#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    $self->relabel_conjunctless_commas($root);
    # Shifting afuns at prepositions and subordinating conjunctions must be done after coordinations are solved
    # and with special care at places where prepositions and coordinations interact.
    $self->process_prep_sub_arg_cloud($root);
    $self->mark_deficient_clausal_coordination($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel;
        my $form   = $node->form;
        my $pos    = $node->conll_pos;
        my $parent = $node->parent();
        my $ppos   = $parent->get_iset('pos');

        # default assignment
        my $afun = 'NR';

        # trivial conversion to PDT style afun
        $afun = 'Atv'   if ( $deprel eq 'arg' );        # arg       -> Atv
        $afun = 'AuxV'  if ( $deprel eq 'aux' );        # aux       -> AuxV
        $afun = 'AuxT'  if ( $deprel eq 'clit' );       # clit      -> AuxT
        $afun = 'Obj'   if ( $deprel eq 'comp' );       # comp      -> Obj
        $afun = 'Atr'   if ( $deprel eq 'concat' );     # concat    -> Atr
        $afun = 'SubArg' if ( $deprel eq 'cong_sub');    # cong_sub  -> AuxC
        $afun = 'Atr'  if ( $deprel eq 'det' );          # det       -> Atr (in future maybe AuxA)
        $afun = 'AuxV'  if ( $deprel eq 'modal' );      # modal     -> AuxV
        $afun = 'Adv'   if ( $deprel eq 'obl' );        # obl       -> Adv
        $afun = 'Obj'   if ( $deprel eq 'ogg_d' );      # ogg_d     -> Obj
        $afun = 'Obj'   if ( $deprel eq 'ogg_i' );      # ogg_i     -> Obj
        $afun = 'Pnom'  if ( $deprel eq 'pred' );       # pred      -> Pnom
        $afun = 'PrepArg' if ( $deprel eq 'prep' );       # prep      -> AuxP
        $afun = 'Sb'    if ( $deprel eq 'sogg' );       # sogg      -> Sb

        # $afun = 'Atr'   if ( $deprel eq 'mod' );        # mod       -> Atr
        # $afun = 'Atr'   if ( $deprel eq 'mod_rel' );    # mod_rel   -> Atr
        # Coordinating conjunctions.
        if ($deprel =~ m/^(con|dis)$/)
        {
            $afun = 'Coord';
            $node->wild()->{coordinator} = 1;
        }
        # Conjunct (not the first one in a coordination).
        elsif ($deprel =~ m/^(con|dis)g$/)
        {
            $afun = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        if ($deprel =~ /^mod(?:_rel)?$/) {
            if ($ppos =~ /^n(?:oun|um)$/) {
                $afun = 'Atr';
            } else {
                $afun = 'Adv';
            }
        }

        # punctuations
        if ( $deprel eq 'punc' ) {
            if ( $form eq ',' ) {
                $afun = 'AuxX';
            }
            elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # deprelation ROOT can be 'Pred'            # pred      -> Pred
        if ( ($deprel eq 'ROOT') && ($node->get_iset('pos') eq 'verb')) {
            $afun = 'Pred';
        }
        elsif ( ($deprel eq 'ROOT') && !($node->get_iset('pos') eq 'verb')){
            $afun = 'ExD';
        }
        $node->set_afun($afun);
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Italian
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_stanford($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return non-head conjuncts, private modifiers of the head conjunct and all shared modifiers for the Stanford family of styles.
    # (Do not return delimiters, i.e. do not return all original children of the node. One of the delimiters will become the new head and then recursion would fall into an endless loop.)
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = grep {$_ != $node} ($coordination->get_conjuncts());
    push(@recurse, $coordination->get_shared_modifiers());
    push(@recurse, $coordination->get_private_modifiers($node));
    return @recurse;
}



#------------------------------------------------------------------------------
# Commas had the same label as coordinating conjunctions, regardless whether
# their function was coordinating or not. As a result, we now have a number of
# commas with the afun Coord, which are leaves and do not have any conjuncts.
#------------------------------------------------------------------------------
sub relabel_conjunctless_commas
{
    my $self = shift;
    my $root = shift;
    foreach my $node ($root->get_descendants())
    {
        if($node->form() eq ',' && $node->afun() eq 'Coord' && $node->is_leaf())
        {
            $node->set_afun('AuxX');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::IT::Harmonize

Converts the ISST Italian treebank (as prepared for the CoNLL 2007 shared task)
to the HamleDT (Prague) annotation style.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
