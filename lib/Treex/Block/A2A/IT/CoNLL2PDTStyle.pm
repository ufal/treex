package Treex::Block::A2A::IT::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;

    my $a_root = $self->SUPER::process_zone($zone);

    # attach terminal punctuations (., ?, ! etc) to root of the tree
    attach_final_punctuation_to_root($a_root);

    $self->make_pdt_coordination($a_root);

    # swap the afun of preposition and its nominal head
    $self->afun_swap_prep_and_its_nhead($a_root);
}

sub make_pdt_coordination {
    my ($self, $root) = @_;
    my @nodes = $root->get_descendants;
    for my $node (@nodes) {
        my @children = $node->get_children({ ordered => 1 });
        if (my @coords = grep $_->afun =~ /^(?:con|dis)$/, @children) {
            my @members = ($node, grep $_->afun =~ /^(?:con|dis)g$/, @children);
            if (not @coords) {
                log_warn('No coordination nodes at ' . $node->get_address);
            }
            my $coord = pop @coords;
            $coord->set_parent($node->get_parent);
            $coord->set_afun('Coord');
            for my $member (@members) {
                $member->set_parent($coord);
                $member->set_afun($node->afun);
                $member->set_is_member(1);
            }
            for my $aux (@coords) {
                $aux->set_parent($coord);
                my $afun;
                if (',' eq $aux->form) {
                    $afun = 'AuxX';
                } else {
                    $afun = 'AuxY';
                }
                $aux->set_afun($afun);
            }
        }
    }
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
        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $pos    = $node->conll_pos();

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = $deprel;

        # trivial conversion to PDT style afun
        $afun = 'Atv'   if ( $deprel eq 'arg' );        # arg       -> Atv
        $afun = 'AuxV'  if ( $deprel eq 'aux' );        # aux       -> AuxV
        $afun = 'Atr'   if ( $deprel eq 'clit' );       # clit      -> Atr
        $afun = 'Atv'   if ( $deprel eq 'comp' );       # comp      -> Atv
        #$afun = 'Coord' if ( $deprel eq 'con' );        # con       -> Coord
        $afun = 'Atr'   if ( $deprel eq 'concat' );     # concat    -> Atr
        $afun = 'AuxC'  if ( $deprel eq 'cong_sub');    # cong_sub  -> AuxC
        $afun = 'AuxA'  if ( $deprel eq 'det' );        # det       -> AuxA
        #$afun = 'Coord' if ( $deprel eq 'dis' );        # dis       -> Coord
        $afun = 'Atr'   if ( $deprel eq 'mod' );        # mod       -> Atr
        $afun = 'Atr'   if ( $deprel eq 'mod_rel' );    # mod_rel   -> Atr
        $afun = 'AuxV'  if ( $deprel eq 'modal' );      # modal     -> AuxV
        $afun = 'Atv'   if ( $deprel eq 'obl' );        # obl       -> Atv
        $afun = 'Obj'   if ( $deprel eq 'ogg_d' );      # ogg_d     -> Obj
        $afun = 'Obj'   if ( $deprel eq 'ogg_i' );      # ogg_i     -> Obj
        $afun = 'Pred'  if ( $deprel eq 'pred' );       # pred      -> Pred
        $afun = 'AuxP'  if ( $deprel eq 'prep' );       # prep      -> AuxP
        $afun = 'Sb'    if ( $deprel eq 'sogg' );       # sogg      -> Sb

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

sub attach_final_punctuation_to_root {
    my $root       = shift;
    my @nodes      = $root->get_descendants({ ordered => 1 });
    my $fnode      = $nodes[-1];
    my $fnode_afun = $fnode->afun();
    if ( $fnode_afun eq 'AuxK' ) {
        $fnode->set_parent($root);
    }
}

# This function will swap the afun of preposition and its nominal head.
# It was because, in the original treebank preposition was given
# 'mod(Atr)' label and its nominal head was given 'prep(AuxP)'.
sub afun_swap_prep_and_its_nhead {
    my ( $self, $root ) = @_;
    my @nodes = $root->get_descendants();

    foreach my $node (@nodes) {
        if ( ( $node->afun() eq 'AuxP' ) && ( $node->conll_pos() =~ /^S/ ) ) {
            my $parent = $node->get_parent();
            if ( ( $parent->afun() eq 'Atr' ) && ( $parent->conll_pos() eq 'E' ) ) {
                $parent->set_afun('AuxP');
                $node->set_afun('Atr');
            }
        }
    }
}

1;

=over

=item Treex::Block::A2A::IT::CoNLL2PDTStyle

Converts ISST Italian treebank into PDT style treebank.

1. Morphological conversion             -> No

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes

        a) Coordination                 -> Yes

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
