package Treex::Block::HamleDT::PT::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($a_root);
    $self->rehang_coordconj($a_root);
    $self->rehang_subconj($a_root);
    return;
}

my %deprel2afun = (
    ACC  => 'Obj',      # direct (accusative) object
    ADVL => 'Adv',
    APP  => 'Atr',      # Apposition, but mostly hanged on a wrong parent TODO: handle it correctly
    CJT  => 0,          # conjunct = coord. member - solved in rehang_coordconj
    CMD  => 'Pred',     # phrase function for commad
    CO   => 'Coord',    # coordinator = conjunction (hanged on the first member)
    EXC  => 'Pred',     # phrase function for exclamation
    FOC  => 'AuxZ',     # focus marker ("é" and "que" forming so-called focus brackets)
    MV   => 'Obj',      # main verb as a child of a modal or auxiliary verb TODO: auxiliary should be reversed under main verbs
    PUNC => 'AuxX',     # punctuation
    STA  => 'Pred',     # phrase function for statements
    SUBJ => 'Sb',       # subject, including impersonal 'se'-subjects
    QUE  => 'Pred',     # phrase function for questions
);

my %pos2afun = (
    q(prep) => 'AuxP',
    q(adj)  => 'Atr',
    q(adv)  => 'Adv',
);

my %subpos2afun = (
    q(det) => 'AuxA',
    q(sub) => 'AuxC',
);

my %parentpos2afun = (
    q(prep) => 'Adv',
    q(noun) => 'Atr',
);

sub deprel_to_afun {
    my ( $self, $root ) = @_;

    foreach my $node ( $root->get_descendants ) {

        my $deprel   = $node->conll_deprel();
        my ($parent) = $node->get_eparents();
        my $pos      = $node->get_iset('pos');
        my $subpos   = $node->get_iset('subpos');
        my $ppos     = $parent ? $parent->get_iset('pos') : '';

        # from the most specific to the least specific
        my $afun = $deprel2afun{$deprel} ||
            $subpos2afun{$subpos} ||
            $pos2afun{$pos} ||
            $parentpos2afun{$ppos} ||
            'NR';

        # AuxX should be used for commas, AuxG for other graphic symbols
        if($deprel eq q(PUNC) && $node->form ne q(,)) {
            $afun = q(AuxG);
        }

        $node->set_afun($afun);
    }
    return;
}

use Treex::Tool::ATreeTransformer::DepReverser;
my $subconj_reverser =
    Treex::Tool::ATreeTransformer::DepReverser->new(
    {
        subscription     => '',
        nodes_to_reverse => sub {
            my ( $child, $parent ) = @_;
            return ( $child->afun =~ /Aux[CP]/ && !$child->get_children );
        },
        move_with_parent => sub { 1; },
        move_with_child  => sub { 1; },
    }
    );

sub rehang_subconj {
    my ( $self, $root ) = @_;
    $subconj_reverser->apply_on_tree($root);

}

sub rehang_coordconj {
    my ( $self, $root ) = @_;

    foreach my $coord (
        grep { $_->afun eq 'Coord' }
        map { $_->get_descendants } $root->get_children
        )
    {
        my $first_member = $coord->get_parent;
        $first_member->set_is_member(1);
        $coord->set_parent( $first_member->get_parent );
        $first_member->set_parent($coord);

        my $second_member = 1;
        foreach my $node ( grep { $coord->precedes($_) } $first_member->get_children( { ordered => 1 } ) ) {
            $node->set_parent($coord);

            my $pos      = $node->get_iset('pos');
            my $subpos   = $node->get_iset('subpos');

            #TODO this should solve test.treex#4 but it does not work as intended
            if ( $node->conll_deprel =~ /CJT&(.*)/ && ( my $afun = $deprel2afun{$1} ) ) {
                $node->set_afun($afun);
                $node->set_is_member(1);
            }

            elsif ( $node->conll_deprel eq 'CJT' ) {
                $afun = $subpos2afun{$subpos} ||
                    $pos2afun{$pos} ||
                        $first_member->afun;
                $node->set_afun( $afun );
                $node->set_is_member(1);
            }

            elsif ($second_member) {
                $node->set_is_member(1);
            }
            $second_member = 0;
        }
    }
    return;
}

1;

=over

=item Treex::Block::HamleDT::PT::Harmonize

Converts Portuguese trees from CoNLL-X to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Martin Popel <popel@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
