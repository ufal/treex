package Treex::Block::A2T::EN::FixEitherOr;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('SEnglishT');

    foreach my $or (
        grep { $_->t_lemma =~ /^n?or$/ }
        $t_root->get_descendants
        )
    {

        my ($either) = grep { $_->t_lemma =~ /^n?either$/ } $or->get_descendants
            or next;

        foreach my $child ( $either->get_children ) {    #there should be none, but who knows...
            $child->set_parent( $either->get_parent );
        }

        # tlemmas such as 'either_or' are created
        $or->set_attr( 't_lemma', $either->t_lemma . "_" . $or->t_lemma );
        $or->add_aux_anodes( $either->get_anodes );
        $or->set_functor('DISJ');
        $or->set_nodetype('coap');
        $either->disconnect;

        #        print $or->t_lemma."\t". $or->get_fposition."\n";
    }

    return;
}

1;

=over

=item Treex::Block::A2T::EN::FixEitherOr

Creates a single t-node from 'either' and 'or' pair (as well as from neither/or
and neither/nor).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
