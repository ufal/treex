package Treex::Block::W2A::EN::FixIsMember;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    fix_node($anode);
    return 1;
}

sub fix_node {
    my ($node) = @_;
    my @children = $node->get_children();
    my @members = grep { $_->is_member } @children;

    #my $is_coord = is_coord($node);
    #if ( @members == 0 ) {
    #    return if !$is_coord;
    #}
    if ( @members == 1 ) {
        $members[0]->set_is_member(0);
    }
    return;
}

sub is_coord {
    my ($node) = @_;
    my $lemma = $node->form;
    return any { $_ eq $lemma } qw(and or nor but);
}

1;

=over

=item Treex::Block::W2A::EN::FixIsMember

The attribute C<is_member> is set to 0 if no sibling-node is member. 

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
