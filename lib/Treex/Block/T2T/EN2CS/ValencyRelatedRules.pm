package Treex::Block::T2T::EN2CS::ValencyRelatedRules;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_bundleOLD {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $t_root->get_descendants() ) {

        if ($cs_tnode->t_lemma
            =~ /^((po)?dařit|líbit)/
            and $cs_tnode->formeme =~ /fin/
            and grep { $_->formeme eq "v:inf" } $cs_tnode->get_eff_children
            )
        {

            foreach my $subj ( grep { $_->formeme =~ /n:1/ } $cs_tnode->get_eff_children ) {

                $subj->set_formeme('n:3');
            }
        }

    }
    return;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $cs_node ( $bundle->get_tree('TCzechT')->get_descendants() ) {
        $self->process_node($cs_node);
    }
    return;
}

sub process_node {
    my ( $self,     $cs_node )    = @_;
    my ( $cs_lemma, $cs_formeme ) = $cs_node->get_attrs(qw(t_lemma formeme));
    my @cs_echildren = $cs_node->get_eff_children();

    # "He managed to..." -> "Podařilo se mu..."
    if ($cs_lemma      =~ /^((po)?dařit|líbit)/
        && $cs_formeme =~ /fin/
        && grep { $_->formeme eq 'v:inf' } @cs_echildren
        )
    {
        foreach my $subj ( grep { $_->formeme =~ /n:1/ } @cs_echildren ) {
            $subj->set_formeme('n:3');
        }
    }
    
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::ValencyRelatedRules

Rules for specific shifts in valency frames.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
