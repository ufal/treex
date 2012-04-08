package Treex::Block::A2A::NL::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll' );


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
    # "vc" = verbal complement
    'vc' => 'Obj',
    # "se" = obligatory reflexive object
    'se' => 'Obj',
#    'ROOT' => 'Pred',
);

sub deprel_to_afun {
    my ( $self, $root ) = @_;

    foreach my $node (grep {not $_->is_coap_root} $root->get_descendants)  {
        
        #If AuxK is set then skip this node.
        next if(defined $node->afun and $node->afun eq 'AuxK');


        my ($parent) = $node->get_eparents();

        my $deprel = ( $node->is_member ? $node->get_parent->conll_deprel : $node->conll_deprel() );

#        if (not defined $deprel) {
#            print $node->get_address."\n";
#
#            exit;
#        }

        my $cpos    = $node->get_attr('conll/pos');
        my $parent_cpos   = ($parent and not $parent->is_root) ? $parent->get_attr('conll/cpos') : '';

        my $afun = $deprel2afun{$deprel} || # from the most specific to the least specific
                $cpos2afun{$cpos} ||
                    $parentcpos2afun{$parent_cpos} ||
                        'NR'; # !!!!!!!!!!!!!!! temporary filler

        if ($deprel eq 'obj1' and $parent_cpos eq 'Prep') {
            $afun = 'Adv';
        }

        if ($parent->is_root and $cpos eq 'V') {
            $afun = 'Pred';
        }

	# Change deprel "body" to afun "Pred" if its parent is not "Pred" and is directly under the root.
	if ($deprel eq 'body' and defined $parent->get_parent and $parent->get_parent->is_root and $parent->afun ne 'Pred' and not $parent->tag =~ /J,.*/) {
		$afun = 'Pred';
		$node->set_parent($root);
		$parent->set_parent($node);
	}


        if ($node->get_parent->afun eq 'Coord' and not $node->is_member
                and ($node->get_iset('pos')||'') eq 'conj') {
            $afun = 'AuxY';
        }

        # AuxX should be used for commas, AuxG for other graphic symbols
        if($afun eq q(AuxX) && $node->form ne q(,)) {
            $afun = q(AuxG);
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
