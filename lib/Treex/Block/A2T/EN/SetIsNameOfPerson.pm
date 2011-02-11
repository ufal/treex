package Treex::Block::A2T::EN::SetIsNameOfPerson;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );

sub process_ttree {
    my ( $self, $t_root ) = @_;
    my @tnodes = $t_root->get_descendants;

    # Get all t-nodes recognized by named entity recognizer as personal names
    my @personal_tnodes = grep {
        my $n = $_->get_n_node();
        defined $n && $n->get_attr('ne_type') =~ /^p/
    } @tnodes;

    # Mark all the nodes except Mr., Mrs., and Ms.
    foreach my $tnode (@personal_tnodes) {
        if ( $tnode->t_lemma !~ /^(M(r|s|rs)|Judge)\.?$/ ) {
            $tnode->set_is_name_of_person(1);
        }
    }
    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::SetIsNameOfPerson

Attribute C<is_name_of_person> is filled according to named enities stored in n-tree.

=back

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
