package Treex::Block::A2A::RU::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Russian tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------

sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    $self->backup_zone($zone);
    my $a_root = $zone->get_atree();

    $self->convert_tags( $a_root, 'syntagrus' );
    $self->attach_final_punctuation_to_root($a_root);
    $self->fill_root_afun($a_root);
    $self->restructure_coordination($a_root);
    $self->deprel_to_afun($a_root);
    $self->check_afuns($a_root);
}


sub fill_root_afun {
    my $self = shift;
    my $a_root = shift;

    foreach my $ch ($a_root->get_descendants) {
        $ch->set_conll_deprel('Pred') if !$ch->conll_deprel;
    }
}


sub restructure_coordination {
    my $self = shift;
    my $a_root = shift;
    
    foreach my $a_node ( $a_root->get_descendants() ) {
        if ( $a_node->conll_deprel =~ /^(сент-соч|сочин|ком-сочин|соч-союзн)$/ ) {
            my $conjunction;
            my $parent = $a_node->get_parent->get_parent;
            my @members = ($a_node->get_parent);
#            $conjunction = $members[0] if $members[0]->tag =~ /^J\^/;
            my $current_node = $a_node;
            while ($current_node) {
                if ($current_node->tag =~ /^J\^/) {
                    $conjunction = $current_node;
                }
                else {
                    push @members, $current_node;
                }
                my @children = $current_node->get_children;
                last if !@children;
                $current_node = undef;
                foreach my $child (@children) {
                    if ($child->conll_deprel =~ /^(сент-соч|сочин|ком-сочин|соч-союзн)$/) {
                        $current_node = $child;
                        last;
                    }
                }
            }
            if ($conjunction) {
                $conjunction->set_conll_deprel('Coord');
                $conjunction->set_parent($parent);
            }
            foreach my $member (@members) {
                $member->set_parent($conjunction ? $conjunction : $parent);
                $member->set_conll_deprel($members[0]->conll_deprel);
                $member->set_is_member(1);
            }
        }
    }
}


my %deprel2afun = ( 'предик' => 'Sb',
                    'предл' => 'AuxP',
                    'опред' => 'Atr',
                    'оп-опред' => 'Atr',
                    'аппрокс-порядк' => 'Atr',
                    'релят' => 'Atr',
                    '1-компл' => 'Obj',
                    '2-компл' => 'Obj',
                    '3-компл' => 'Obj',
                    '4-компл' => 'Obj',
                    '5-компл' => 'Obj',
                    'адр-присв' => 'Obj',
                    'Coord' => 'Coord',
                    'Pred' => 'Pred',
                  );


sub deprel_to_afun {

    my $self   = shift;
    my $a_root = shift;

    # switch deprels for preposition phrases
    foreach my $node ($a_root->get_descendants) {
        if ($node->tag =~ /^RR/) {
            my $deprel = $node->conll_deprel;
            $node->set_conll_deprel('предл');
            foreach my $child ($node->get_children) {
                $child->set_conll_deprel($deprel) if $child->conll_deprel eq 'предл' && $deprel ne 'предл';
            }
        }
    }
    foreach my $node ($a_root->get_descendants) {
        if ($deprel2afun{$node->conll_deprel}) {
            $node->set_afun($deprel2afun{$node->conll_deprel});
        }
        elsif ($node->tag =~ /^D/) {
            $node->set_afun('Adv');
        }
        else {
            $node->set_afun('Atr');
        }
    }
}


1;

=over

=item Treex::Block::A2A::RU::CoNLL2PDTStyle

Converts Syntagrus (Russian Dependency Treebank) trees to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
