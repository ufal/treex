package Treex::Block::A2A::NL::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );
#    $self->deprel_to_afun($a_root)
    $self->attach_final_punctuation_to_root($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->restructure_coordination($a_root);
    $self->resolve_coordinations($a_root);
#    $self->check_afuns($a_root);
    $self->deprel_to_afun($a_root);
}


my %cpos2afun = (
    'Art' => 'AuxA',
    'Prep' => 'AuxP',
    'Adv' => 'Adv',
    'Punc' => 'AuxX',
    'Conj' => 'AuxC', # also Coord, but it is already filled when filling is_member of its children
);


my %parentcpos2afun = (
    'Prep' => 'Adv',
    'N' => 'Atr',
);


my %deprel2afun = (
    'su' => 'Sb',
    'obj1' => 'Obj',
#    'ROOT' => 'Pred',
);


sub deprel_to_afun {
    my ( $self, $root ) = @_;

    foreach my $node (grep {not $_->is_coap_root} $root->get_descendants)  {



        my ($parent) = $node->get_eparents();

        my $deprel = ( $node->is_member ? $node->get_parent->conll_deprel : $node->conll_deprel() );

        if (not defined $deprel) {
            print $node->get_address."\n";

            exit;
        }

        my $cpos    = $node->get_attr('conll/pos');
        my $parent_cpos   = ($parent and not $parent->is_root) ? $parent->get_attr('conll/cpos') : '';

        my $afun = $deprel2afun{$deprel} || # from the most specific to the least specific
                $cpos2afun{$cpos} ||
                    $parentcpos2afun{$parent_cpos} ||
                        undef; # !!!!!!!!!!!!!!! temporary filler

        if ($deprel eq 'obj1' and $parent_cpos eq 'Prep') {
            $afun = 'Adv';
        }

        if ($parent->is_root and $cpos eq 'V') {
            $afun = 'Pred';
        }

        $node->set_afun($afun);
    }
}


sub resolve_coordinations {
    my ( $self, $root ) = @_;

    foreach my $conjunct (grep {$_->conll_deprel eq 'cnj'} $root->get_descendants) {
        $conjunct->set_is_member(1);
        $conjunct->get_parent->set_afun('Coord');
    }
}




1;

=over

=item Treex::Block::A2A::NL::CoNLL2PDTStyle

Converts Dutch trees from CoNLL 2006 to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
