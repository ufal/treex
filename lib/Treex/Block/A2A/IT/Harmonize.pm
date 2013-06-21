package Treex::Block::A2A::IT::Harmonize;
use feature state;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------

sub deprel_to_afun {}

sub process_zone
{
    my $self   = shift;
    my $zone   = shift;

    my $a_root = $self->SUPER::process_zone($zone);

    $self->make_pdt_coordination($a_root);

    $self->make_pdt_auxcp($a_root);

    $self->set_afuns($a_root);

    # attach terminal punctuations (., ?, ! etc) to root of the tree
    attach_final_punctuation_to_root($a_root);

    $self->remove_invalid_afuns($a_root);

}


sub make_pdt_coordination {
    my ($self, $root) = @_;
    my @nodes = $root->get_descendants;
    for my $node (@nodes) {
        my @children = $node->get_children({ ordered => 1 });
        if (my @coords = grep $_->conll_deprel =~ /^(?:con|dis)$/, @children) {
            next if $node->afun and 'Coord' eq $node->afun;
            my @members = ($node,
                           grep $_->conll_deprel =~ /^(?:con|dis)g$/,
                               @children);
            if (not @coords) {
                log_warn('No coordination nodes at ' . $node->get_address);
                next;
            }
            my $coord = pop @coords;
            $coord->set_parent($node->get_parent);
            $coord->set_afun('Coord');
            for my $member (@members) {
                $member->set_parent($coord);
                if ('prep' eq $node->conll_deprel) {
                    $member->set_conll_deprel($coord->get_parent->conll_deprel);
                    $coord->get_parent->set_afun('AuxP');
                } else {
                    $member->set_conll_deprel($node->conll_deprel);
                }
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

sub make_pdt_auxcp {
    my ($self, $aroot) = @_;
    state $translate_to
        = { prep     => 'AuxP',
            cong_sub => 'AuxC',
          };

    for my $node ($aroot->get_descendants) {
        my $deprel = $node->conll_deprel;
        if (grep $_ eq $deprel, keys %$translate_to) {
            my $aux = $node->get_parent;
            $aux = $aux->get_parent while $aux->afun
                and 'Coord' eq $aux->afun;
            $node->set_conll_deprel($aux->conll_deprel);
            if ($aux == $aroot) {
                log_warn('A-Root as candidate for AuxC '
                         . $node->get_address);
                # HACK, error in the input data
                $node->set_afun('Pred');
                $node->set_is_member(1);
            } else {
                $aux->set_afun($translate_to->{$deprel});
            }
        }
    }
} # make_pdt_auxcp

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub set_afuns
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        next if $node->afun;

        my $deprel   = $node->conll_deprel;
        my $form     = $node->form;
        my $pos      = $node->conll_pos;
        my ($parent) = $node->get_eparents({ dive => 'AuxCP' });
        my $p_iset  = $parent->get_iset('pos');

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = $deprel;

        # trivial conversion to PDT style afun
        $afun = 'Atv'   if ( $deprel eq 'arg' );        # arg       -> Atv
        $afun = 'AuxV'  if ( $deprel eq 'aux' );        # aux       -> AuxV
        $afun = 'AuxT'  if ( $deprel eq 'clit' );       # clit      -> AuxT
        $afun = 'Obj'   if ( $deprel eq 'comp' );       # comp      -> Obj
        $afun = 'Atr'   if ( $deprel eq 'concat' );     # concat    -> Atr
        $afun = 'AuxC'  if ( $deprel eq 'cong_sub');    # cong_sub  -> AuxC
        $afun = 'AuxA'  if ( $deprel eq 'det' );        # det       -> AuxA
        $afun = 'AuxV'  if ( $deprel eq 'modal' );      # modal     -> AuxV
        $afun = 'Adv'   if ( $deprel eq 'obl' );        # obl       -> Adv
        $afun = 'Obj'   if ( $deprel eq 'ogg_d' );      # ogg_d     -> Obj
        $afun = 'Obj'   if ( $deprel eq 'ogg_i' );      # ogg_i     -> Obj
        $afun = 'Pnom'  if ( $deprel eq 'pred' );       # pred      -> Pnom
        $afun = 'AuxP'  if ( $deprel eq 'prep' );       # prep      -> AuxP
        $afun = 'Sb'    if ( $deprel eq 'sogg' );       # sogg      -> Sb

        # $afun = 'Atr'   if ( $deprel eq 'mod' );        # mod       -> Atr
        # $afun = 'Atr'   if ( $deprel eq 'mod_rel' );    # mod_rel   -> Atr
        # $afun = 'Coord' if ( $deprel eq 'con' );        # con       -> Coord
        # $afun = 'Coord' if ( $deprel eq 'dis' );        # dis       -> Coord

        if ($deprel =~ /^mod(?:_rel)?$/) {
            if ($p_iset =~ /^n(?:oun|um)$/) {
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

sub attach_final_punctuation_to_root {
    my $root       = shift;
    my @nodes      = $root->get_descendants({ ordered => 1 });
    my $fnode      = $nodes[-1];
    my $fnode_afun = $fnode->afun() // '';
    if ( $fnode_afun eq 'AuxK' ) {
        $fnode->set_parent($root);
    }
}

# Coordination without Coord - just make the other nodes ExD
sub remove_invalid_afuns {
    my ($self, $aroot) = @_;
    for my $node ($aroot->get_descendants) {
        if (!$node->afun or $node->afun =~ /^[[:lower:]]/) {
            $node->set_afun('NR');
            log_info('No afun for ' . $node->get_address);
        }
    }
} # remove_invalid_afuns


# prevent setting the afuns before coordination
sub deprel_to_afun {}

1;

=over

=item Treex::Block::A2A::IT::Harmonize

Converts ISST Italian treebank into PDT style treebank.

1. Morphological conversion             -> No

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes

        a) Coordination                 -> Yes

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
