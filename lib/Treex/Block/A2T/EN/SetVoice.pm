package Treex::Block::A2T::EN::SetVoice;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';



sub process_ttree {
    my ( $self, $t_root ) = @_;
        foreach my $t_node ( grep { $_->nodetype eq "complex" } $t_root->get_descendants ) {
            my $formeme = $t_node->formeme || "";
            if ( $formeme =~ /^v:/ ) {
                if ( $t_node->is_passive ) {
                    $t_node->set_voice( 'passive' );
                }
                else {
                    $t_node->set_voice( 'active' );
                }
            }
        }
    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::SetVoice

The attribute C<voice> is filled so that it distinguishes
distinguishes English active and passive voice (in verb t-nodes only).
(!!!zatim se v podstate jen kopiruje is_passive, ale mozna to bude slozitejsi,
pro cestinu urcite, anebo se is_passive a Mark_passives postupne nahradi uplne).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
