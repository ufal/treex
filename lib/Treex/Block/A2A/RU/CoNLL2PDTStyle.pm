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
    my $a_root = $self->SUPER::process_zone( $zone, 'syntagrus' );

    $self->attach_final_punctuation_to_root($a_root);
    $self->restructure_coordination($a_root);
    $self->deprel_to_afun($a_root);
    $self->check_afuns($a_root);
}


sub restructure_coordination {
    my $self = shift;
    my $a_root = shift;
    
    foreach my $a_node ( $a_root->get_descendants() ) {
        if ( $a_node->conll_deprel && $a_node->conll_deprel =~ /^(сент-соч|сочин)$/ ) {
            my $coord_type = $1;
            my $fdr = $1;
            my $common_parent = $a_node->get_parent->get_parent;
            my $common_deprel = $a_node->get_parent->conll_deprel;
            my @members = ( $a_node->get_parent );
            my $conjunction;
            my $last_member = $a_node;
            while ( $last_member ) {
                if ( $last_member->tag =~ /^J\^/ ) {
                    $conjunction = $last_member;
                    $fdr = 'соч-союзн';
                }
                else {
                    push @members, $last_member;
                }
                my $found = 0;
                foreach my $child ($last_member->get_children) {
                    if ( $child->conll_deprel eq $fdr ) {
                        log_warn("More than one coordination member in the same level.") if ( $found );
                        $last_member = $child;
                        $found = 1;
                    }
                }
                $last_member = undef if not $found;
            }
            if ( $conjunction && $common_parent ) {
                $conjunction->set_conll_deprel('Coord');
                $conjunction->set_parent($common_parent);
                foreach my $member (@members) {
                    $member->set_conll_deprel($conjunction->conll_deprel);
                    $member->set_parent($conjunction);
                    $member->set_is_member(1);
                }
            }
            elsif (not $common_parent) {
                log_warn("Coordination members have no parent node.");
            }
            else {
                foreach my $member (@members) {
                    #$member->set_conll_deprel('???');
                    $member->set_parent($common_parent);
                }
            }
        }
    }
}


my %deprel2afun = ( 'предик' => 'Sb',
                    'предл' => 'AuxP',
                    'опред' => 'Atr',
                    '1-компл' => 'Obj',
                    '2-компл' => 'Obj',
                    '3-компл' => 'Obj',
                    'Coord' => 'Coord',
                  );


sub deprel_to_afun {

    my $self       = shift;
    my $a_root       = shift;

    # swich deprels for preposition phrases
    foreach my $node ($a_root->get_descendants()) {
        my $parent = $node->get_parent;
        if (defined $parent->conll_deprel && $parent->conll_deprel eq 'предл') {
            log_warn("Two prepositions.") if $node->conll_deprel eq 'предл';
            $parent->set_conll_deprel($node->conll_deprel);
            $node->set_conll_deprel('предл');
        }
    }

    foreach my $node ($a_root->get_descendants) {
        if ($node->conll_deprel && $deprel2afun{$node->conll_deprel}) {
            $node->set_afun($deprel2afun{$node->conll_deprel});
        }
        else {
            $node->set_afun('ExD');
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
