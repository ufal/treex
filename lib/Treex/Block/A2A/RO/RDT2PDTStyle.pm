package Treex::Block::A2A::RO::RDT2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

my %RDT_DEPREL_TO_AFUN = (
    'atribut adj.'               => 'Atr',
    'atribut adv.'               => 0,
    'atribut num.'               => 0,
    'atribut pron.'              => 0,
    'atribut subst.'             => 0,
    'atribut subst. apozitional' => 0,
    'atribut verb.'              => 0,
    'complement agent'           => 0,
    'complement circumst.'       => 0,        # AuxP
    'complement dir.'            => 'Obj',
    'complement indir.'          => 0,        #'AuxP',
    'nume pred.'                 => 'Pnom',
    'predicat'                   => 'Pred',
    'rel. aux.'                  => 'AuxV',
    'rel. comp.'                 => 0,
    'rel. conj.'                 => 0,
    'rel. dem.'                  => 0,
    'rel. hot.'                  => 0,
    'rel. infinit.'              => 0,
    'rel. negat.'                => 0,
    'rel. nehot.'                => 0,
    'rel. poses.'                => 0,
    'rel. prepoz.'               => 0,
    'rel. reflex.'               => 0,
    'subiect'                    => 'Sb',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root = $self->SUPER::process_zone( $zone, 'rdt' );
    return;
}

sub deprel_to_afun {
    my ( $self, $a_root ) = @_;
    foreach my $node ( $a_root->get_descendants ) {
        $node->set_afun( $self->rdt_to_afun($node) );
    }
    return;
}

sub rdt_to_afun {
    my ( $self, $node ) = @_;
    my $deprel = $node->conll_deprel();
    my $afun   = $RDT_DEPREL_TO_AFUN{$deprel};
    return $afun if $afun;

    # Coordination members
    my $parent = $node->get_parent();
    if ( $deprel eq 'rel. conj.' ) {
        $node->set_is_member(1);
        $parent = $parent->get_parent();
    }
    my $pdeprel = $parent->conll_deprel;
    my $pos     = $node->get_iset('pos');
    my $ppos    = $parent->get_iset('pos');

    return 'Coord' if $node->conll_pos eq 'conj. coord' && any { $_->conll_deprel eq 'rel. conj.' } $node->get_children();
    return 'AuxP' if $pos eq 'prep';
    return 'Obj' if $deprel eq 'rel. prepoz.' && $pdeprel eq 'complement indir.';
    return 'Obj' if $deprel eq 'rel. prepoz.' && $pdeprel eq 'atribut subst.';
    return 'NR';    # not recognized
}

1;

=over

=item Treex::Block::A2A::RO::RDT2PDTStyle

Converts RDT (Romanian Dependency Treebank) trees to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags of PDT.

=back

=cut

# Copyright 2011 Martin Popel <popel@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
