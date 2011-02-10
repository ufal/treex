package Treex::Block::A2T::EN::RehangSharedAttr;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );

sub process_ttree {
    my ( $self, $t_root ) = @_;

    foreach my $attr (
        grep {
            $_->formeme =~ /attr|poss/
                and not $_->is_member
                and $_->t_lemma ne 'both'
        }
        reverse map { $_->get_descendants( { ordered => 1 } ) }
        reverse $t_root->get_children( { ordered => 1 } )
        )
    {

        my @coord_members = grep { $_->is_member and $_ ne $attr->get_parent }
            $attr->get_eff_parents;

        my ($nearest_member) = sort { $a->get_ordering_value <=> $b->get_ordering_value }
            grep { $_->precedes( $_->get_parent ) }
            grep { $attr->precedes($_) } @coord_members;

        # and there are no intermediate nodes
        if ($nearest_member
            and
            not grep { $_->precedes($nearest_member) and $attr->precedes($_) }
            $nearest_member->get_parent->get_children
            )
        {

            #            print $attr->get_fposition."\n";
            $attr->set_parent($nearest_member);
        }

    }
    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::RehangSharedAttr

Rehanging shared attr/poss modifiers below the nearest following
coordination member (usually there is a mess in the
coordination structure anyway).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
