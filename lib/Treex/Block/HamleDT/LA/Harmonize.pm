package Treex::Block::HamleDT::LA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePerseus';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'la::conll',
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
            # There is a tree with two sentences (sentence segmentation failed), analyzed wrongly.
            elsif($parent->is_root() && $rsibling && $rsibling->form() eq ',' && scalar(@children)==1 && $children[0]->form() eq '.')
            {
                # The only child of the lone Coord is the period, labeled AuxX. It should be AuxK (but it should also be the last token in the tree).
                my $period = $children[0];
                # The second sentence contains two coordinate clauses, joined by a comma.
                my $comma = $rsibling;
                my @children_of_comma = $comma->children();
                if(@children_of_comma)
                {
                    $children_of_comma[0]->set_parent($node);
                    $children_of_comma[0]->set_afun('Pred');
                    $children_of_comma[0]->set_is_member(1);
                    $period->set_parent($root);
                    $period->set_afun('AuxK');
                    $period->set_is_member(undef);
                }
            }
            # potione honoratus est et argentea corona
            # ORIG TREE: honoratus/Pred ( est/AuxV ( potione/Adv_Co , corona/Adv_Co ( argentea/Atr ) ) , et/Coord )
            # WANT TREE: honoratus/Pred ( est/AuxV ( et/Coord ( potione/Adv_Co , corona/Adv_Co ( argentea/Atr ) ) ) )
            elsif($node->form() eq 'et' && defined($parent->form()) && $parent->form() eq 'honoratus')
            {
                my $et = $node;
                my $honoratus = $parent;
                my $est = $et->get_left_neighbor();
                if($est && $est->form() eq 'est')
                {
                    foreach my $conjunct ($est->children())
                    {
                        $conjunct->set_parent($et);
                        $conjunct->set_is_member(1);
                    }
                    $et->set_parent($est);
                    $et->set_is_member(undef);
                }
            }
            # ecce mitto eam in lectum et qui moechantur cum ea in tribulationem maximam nisi paenitentiam egerint ab operibus eius
            elsif($node->form() eq 'et' && defined($parent->form()) && $parent->form() eq 'mitto')
            {
                my $et = $node;
                my $mitto = $parent;
                my $nisi = $et->get_right_neighbor();
                if($nisi)
                {
                    $et->set_parent($root);
                    $et->set_is_member(undef);
                    foreach my $conjunct ($root->children())
                    {
                        unless($conjunct == $et)
                        {
                            $conjunct->set_parent($et);
                            $conjunct->set_is_member(1);
                        }
                    }
                    $nisi->set_parent($et);
                    $nisi->set_is_member(undef);
                }
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

=item Treex::Block::HamleDT::LA::Harmonize

Converts Latin Dependency Treebank to the HamleDT (Prague) style.
Most of the deprel tags follow PDT conventions but they are very elaborated
so we have shortened them.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
