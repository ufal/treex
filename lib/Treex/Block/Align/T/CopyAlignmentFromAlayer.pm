package Align_SxxT_SyyT::Copy_alignment_from_Alayer;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my $LANGUAGE1;
my $LANGUAGE2;

sub BUILD {
    my ($self) = @_;

    $LANGUAGE1 = $self->get_parameter('LANGUAGE1') or
        Report::fatal('Parameter LANGUAGE1 must be specified!');
    $LANGUAGE2 = $self->get_parameter('LANGUAGE2') or
        Report::fatal('Parameter LANGUAGE2 must be specified!');
    return;
}

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {

        my $troot1 = $bundle->get_generic_tree("S${LANGUAGE1}T");
        my $troot2 = $bundle->get_generic_tree("S${LANGUAGE2}T");

        # delete previously made links
        foreach my $tnode ( $troot1->get_descendants ) {
            $tnode->set_attr( 'align/links', [] );
        }

        my %a2t;
        foreach my $tnode2 ($troot2->get_descendants) {
            my $anode2 = $tnode2->get_lex_anode;
            next if not $anode2;
            $a2t{$anode2->get_attr('id')} = $tnode2->get_attr('id');
        }

        foreach my $tnode1 ($troot1->get_descendants) {
            my $anode1 = $tnode1->get_lex_anode;
            next if not $anode1;
            foreach my $link ( @{$anode1->get_attr('m/align/links')} ) {
                my $tnode2_id = $a2t{ $link->{'counterpart.rf'} };

                # add connection
                my $links_rf = $tnode1->get_attr('align/links');
                my %new_link = ( 'counterpart.rf' => $tnode2_id, 'type' => $link->{'type'} );
                push( @$links_rf, \%new_link );
                $tnode1->set_attr( 'align/links', $links_rf );
            }
        }
    }
}


1;

=over

=item Align_SxxT_SyyT::Copy_alignment_from_Alayer;

PARAMETERS:

- LANGUAGE1 - language in which the alignment attributes are included

- LANGUAGE2 - the other language

=back

=cut

# Copyright 2009 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
