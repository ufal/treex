package Treex::Block::Eval::AtreeHighlightEdges;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $ref_zone = $bundle->get_zone( $self->language, $self->selector );
	my @compared_zones = grep { $_ ne $ref_zone && $_->language eq $self->language } $bundle->get_all_zones();    	

   	my @ref_parents = map { $_->get_parent->ord } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
   	my @ref_deprels = map { $_->conll_deprel || '' } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
	    
    foreach my $compared_zone (@compared_zones) {
        foreach my $anode ($compared_zone->get_atree->get_descendants( { ordered => 1 } ) ) {
            my $index = $anode->ord - 1;
            if ($anode->get_parent->ord != $ref_parents[$anode->ord - 1]) {
                $anode->wild->{edgecolor} = '#ff0000';
            }
            elsif ($anode->conll_deprel ne $ref_deprels[$anode->ord - 1]) {
                $anode->wild->{edgecolor} = '#dddd00';
            }
        }
    }
}

1;

=over

=item Treex::Block::Eval::AtreeHighlightEdges

Measure similarity (in terms of unlabeled attachment score) of a-trees in all zones
(of a given language) with respect to the reference zone specified by selector.

=back

=cut

# Copyright 2017 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
