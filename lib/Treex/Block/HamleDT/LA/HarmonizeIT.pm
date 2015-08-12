package Treex::Block::HamleDT::LA::HarmonizeIT;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePerseus';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'la::itconll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the Latin CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->check_afuns($root);
    foreach my $node ($root->get_descendants){
        $self->fix_iset($node);
    }
    return;
}

sub fix_iset {
    my ($self, $node) = @_;
    my $lemma = $node->lemma;
    if ($lemma eq 'qui'){
        $node->iset->set_prontype('rel');
    }
    if ($node->is_verb && $lemma =~ /^(possum|debeo|volo|nolo|malo|soleo|intendo)$/){
        $node->iset->set_verbtype('mod');
    }
    return;
}

#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Should be called
# from deprel_to_afun() so that it precedes any tree operations that the
# superordinate class may want to do.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my @children = $node->children();
        # Coord is leaf or its children are not conjuncts.
        if($node->afun() eq 'Coord' && scalar(grep {$_->is_member()} (@children))==0)
        {
            my $rsibling = $node->get_right_neighbor();
            # Is this an additional delimiter in another coordination?
            if($parent->afun() eq 'Coord' && scalar(@children)==1 && $children[0]->afun() eq 'AuxX')
            {
                $children[0]->set_parent($parent);
                $children[0]->set_is_member(undef);
                $node->set_afun('AuxY');
                $node->set_is_member(undef);
            }
            # Default will apply to one case.
            else
            {
                $node->set_afun('AuxY');
                $node->set_is_member(undef);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::LA::HarmonizeIT

Converts the Index Thomisticus Treebank (Latin) to the HamleDT (Prague) style.
Most of the deprel tags follow PDT conventions, the only addition being OComp.
The is_member attribute is not set properly, the afuns of the conjuncts have the '_Co' suffix instead.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
