package TCzechT_to_TCzechA::Delete_superfluous_prepos;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my %DISTANCE_LIMIT = (
    'v'    => 5,
    'mezi' => 50,
    'pro'  => 8,
);
my $BASE_DISTANCE_LIMIT = 8;

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $a_root = $bundle->get_tree('TCzechA');

    COORD:
    foreach my $coord_anode ( grep { ( $_->get_attr('afun') || '' ) eq 'Coord' } $a_root->get_descendants() ) {

        # !!! potreba testovat is is_member, ten je ale zatim v datech blbe
        my @auxp_anodes = grep { ( $_->get_attr('afun') || '' ) eq 'AuxP' } $coord_anode->get_children();

        next COORD if !@auxp_anodes;

        my $first_auxp_anode = shift @auxp_anodes;
        my $prev_ord         = $first_auxp_anode->get_attr('ord');

        my $limit = $DISTANCE_LIMIT{ $first_auxp_anode->get_attr('m/lemma') };
        $limit = $BASE_DISTANCE_LIMIT if !defined $limit;

        foreach my $anode (@auxp_anodes) {
            my $ord = $anode->get_attr('ord');
            next COORD if $prev_ord + $limit < $ord
                    || $anode->get_attr('m/lemma') ne $first_auxp_anode->get_attr('m/lemma');
            $prev_ord = $ord;
        }

        foreach my $anode (@auxp_anodes) {
            foreach my $child ( $anode->get_children ) {
                if ( ( $child->get_attr('afun') || '' ) eq 'AuxP' ) {
                    $child->disconnect();
                }
                else {
                    $child->set_parent( $anode->get_parent );
                    $child->set_attr( 'is_member', $anode->get_attr('is_member') );
                }
            }
            $anode->disconnect();
        }
    }
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Delete_superfluous_prepos

In constructions such as 'for X and Y', the second
preposition created on the target side ('pro X a pro Y')
is removed.

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
