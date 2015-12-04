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
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
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
    $self->fix_negation($root);
    $self->check_deprels($root);
}

#------------------------------------------------------------------------------
# Tries to separate negation from all the AuxZ modifiers.
#------------------------------------------------------------------------------
sub fix_negation
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'AuxZ')
        {
            # I believe that the following function as negative particles in Latin.
            if($node->form() =~ m/^(non|ne)$/i)
            {
                $node->set_deprel('Neg');
            }
        }
    }
}

#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Should be called
# from convert_deprels() so that it precedes any tree operations that the
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
        if($node->deprel() eq 'Coord' && scalar(grep {$_->is_member()} (@children))==0)
        {
            my $rsibling = $node->get_right_neighbor();
            # Is this an additional delimiter in another coordination?
            if($parent->deprel() eq 'Coord' && scalar(@children)==1 && $children[0]->deprel() eq 'AuxX')
            {
                $children[0]->set_parent($parent);
                $children[0]->set_is_member(undef);
                $node->set_deprel('AuxY');
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
                    $children_of_comma[0]->set_deprel('Pred');
                    $children_of_comma[0]->set_is_member(1);
                    $period->set_parent($root);
                    $period->set_deprel('AuxK');
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
                $node->set_deprel('AuxY');
                $node->set_is_member(undef);
            }
        }
        # nisi si me iudicas curare
        # unless you care to judge me
        # "nisi si" = "unless"; "except if"
        elsif(defined($node->form()) && $node->form() =~ m/^si$/i && && defined($node->parent()->form()) && $node->parent()->form() =~ m/^nisi$/i && $node->deprel() eq 'AuxY' && scalar($node->children())==1)
        {
            $node->set_deprel('AuxC');
        }
        # Sed narra mihi, Gai, rogo, Fortunata quare non recumbit
        # But do tell me, Gaius, I ask, why is Fortunata not at dinner
        # "sed" ("but") is attached as a leaf/AuxC to the root.
        elsif($node->form() =~ m/^sed$/i && $node->parent()->is_root() && $node->deprel() eq 'AuxC' && $node->is_leaf())
        {
            my $rsibling = $node->get_right_neighbor();
            if($rsibling->deprel() eq 'Coord')
            {
                $node->set_parent($rsibling);
                $node->set_deprel('AuxY');
                $node->set_is_member(0);
            }
        }
        # in pace vero quod beneficiis magis quam metu imperium agitabant et ...
        # were discussing the government of the truth that is in peace, kindness rather than by fear, and ...
        # "quod" = "because" (the most frequent translation)
        elsif($node->form() =~ m/^quod$/i && $node->parent()->is_root() && $node->deprel() eq 'AuxC' && $node->is_leaf())
        {
            my $rsibling = $node->get_right_neighbor();
            if($rsibling->deprel() eq 'Coord')
            {
                $rsibling->set_parent($node);
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

# Copyright 2011, 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
