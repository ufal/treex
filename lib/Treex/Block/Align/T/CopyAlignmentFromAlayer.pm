package Treex::Block::Align::T::CopyAlignmentFromAlayer;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has to_language => ( isa => 'Str', is => 'ro', required => 1);
has to_selector => ( isa => 'Str', is => 'ro', default  => '');


sub process_ttree {
    my ( $self, $troot ) = @_;

    my $to_troot = $troot->get_bundle->get_tree($self->to_language, 't', $self->to_selector);

    # delete previously made links
    foreach my $tnode ( $troot->get_descendants ) {
        $tnode->set_attr( 'alignment', [] );
    }

    my %a2t;
    foreach my $to_tnode ($to_troot->get_descendants) {
        my $to_anode = $to_tnode->get_lex_anode;
        next if not $to_anode;
        $a2t{$to_anode->id} = $to_tnode->id;
    }

    foreach my $tnode ($troot->get_descendants) {
        my $anode = $tnode->get_lex_anode;
        next if not $anode;
        foreach my $link ( @{$anode->get_attr('alignment')} ) {
            my $to_tnode_id = $a2t{ $link->{'counterpart.rf'} } || next;;

            # add connection
            my $links_rf = $tnode->get_attr('alignment');
            my %new_link = ( 'counterpart.rf' => $to_tnode_id, 'type' => $link->{'type'} );
            push( @$links_rf, \%new_link );
            $tnode->set_attr( 'alignment', $links_rf );
        }
    }
}


1;

=over

=item Treex::Block::Align::T::CopyAlignmentFromAlayer;

PARAMETERS:

- language - language in which the alignment attributes are included

- to_language - the other language

=back

=cut

# Copyright 2009-2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
