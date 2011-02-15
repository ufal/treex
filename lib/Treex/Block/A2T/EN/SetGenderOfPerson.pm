package Treex::Block::A2T::EN::SetGenderOfPerson;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    return 1 if $t_node->get_attr('gram/gender');
    if ( my $gender = gender_of_tnode_person($t_node) ) {
        $t_node->set_attr( 'gram/gender', $gender );
    }
    return 1;
}

sub gender_of_tnode_person {
    my ($t_node) = @_;
    my $n_node = $t_node->get_n_node() or return;
    while (1) {
        my $type = $n_node->get_attr('ne_type');
        return 'fem'  if $type eq 'PF';
        return 'anim' if $type eq 'PM';
        return if $type !~ /^p/;
        $n_node = $n_node->get_parent();
        return if $n_node->is_root();
    }
}

1;

=over

=item Treex::Block::A2T::EN::SetGenderOfPerson

The C<gram/gender> attribute is filled according to the named entity tree.
NE nodes with female names have C<ne_type> = C<PF>, male ones have C<PM>.

=back

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
