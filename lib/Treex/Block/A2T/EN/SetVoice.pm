package SEnglishA_to_SEnglishT::Detect_voice;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;
    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SEnglishT');
        foreach my $t_node ( grep { $_->get_attr('nodetype') eq "complex" } $t_root->get_descendants ) {
            my $formeme = $t_node->get_attr('formeme') || "";
            if ( $formeme =~ /^v:/ ) {
                if ( $t_node->get_attr('is_passive') ) {
                    $t_node->set_attr( 'voice', 'passive' );
                }
                else {
                    $t_node->set_attr( 'voice', 'active' );
                }
            }
        }
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Detect_voice

The attribute C<voice> is filled so that it distinguishes
distinguishes English active and passive voice (in verb t-nodes only).
(!!!zatim se v podstate jen kopiruje is_passive, ale mozna to bude slozitejsi,
pro cestinu urcite, anebo se is_passive a Mark_passives postupne nahradi uplne).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
