package Treex::Block::HamleDT::ES::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizeAnCora';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'es::conll2009',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



# If there are any language-specific phenomena to handle, uncomment process_zone() and put the code there.
# Make sure to call $self->SUPER::process_zone($zone) from there!
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Unlike in other
# treebanks, here it is called after correctly annotated coordinations are
# solved. The function is meant to collect bad cases but it could damage the
# good ones.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # Coordination without conjuncts.
        if($node->deprel() eq 'Coord')
        {
            my $parent = $node->parent();
            my @children = $node->children();
            if($node->is_leaf())
            {
                # Three times the conjunction "y" is attached to the previous conjunct and coordination is not properly labeled.
                my $lconjunct = $node->parent();
                my $rconjunct = $lconjunct->get_right_neighbor();
                # Because of previous transformations, in one case the right conjunct will be found one level higher.
                # The subordinator que has been raised above the left conjunct.
                if(!defined($rconjunct) && $lconjunct->form() eq 'sobrepasará')
                {
                    my $que = $lconjunct->parent();
                    if($que && $que->form() eq 'que')
                    {
                        $rconjunct = $que->get_right_neighbor();
                    }
                }
                if($lconjunct && $rconjunct)
                {
                    my $parent = $lconjunct->parent();
                    $node->set_parent($parent);
                    $node->set_is_member(undef);
                    $lconjunct->set_parent($node);
                    $lconjunct->set_is_member(1);
                    $rconjunct->set_parent($node);
                    $rconjunct->set_is_member(1);
                }
            }
            elsif(scalar(@children)==1 && scalar(grep {$_->is_member()} (@children))==0 && $parent->get_iset('pos') eq 'noun' && $children[0]->get_iset('pos') eq 'noun')
            {
                my $lconjunct = $parent;
                my $rconjunct = $children[0];
                my $parent = $lconjunct->parent();
                $node->set_parent($parent);
                $node->set_is_member(undef);
                $lconjunct->set_parent($node);
                $lconjunct->set_is_member(1);
                $rconjunct->set_parent($node);
                $rconjunct->set_is_member(1);
                $rconjunct->set_deprel($lconjunct->deprel());
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::ES::Harmonize

Converts Spanish trees from CoNLL 2009 to the HamleDT (Prague) style.
Relies on code that is common for both AnCora treebanks (Catalan and Spanish).

=back

=cut

# Copyright 2011-2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
