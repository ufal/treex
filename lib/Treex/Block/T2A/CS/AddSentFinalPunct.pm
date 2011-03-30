package Treex::Block::T2A::CS::AddSentFinalPunct;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $troot = $zone->get_ttree();
    my $aroot = $zone->get_atree();

    my ($first_troot) = $troot->get_children();
    if ( !$first_troot ) {
        log_warn('No nodes in t-tree.');
        return;
    }

    # Don't put period after colon, semicolon, or three dots
    my $last_token = $troot->get_descendants( { last_only => 1 } );
    return if $last_token->t_lemma =~ /^[:;.]/;

    my $punct_mark = ( ( $first_troot->sentmod || '' ) eq 'inter' ) ? '?' : '.';

    #!!! dirty traversing of the pyramid at the lowest level
    # in order to distinguish full sentences from titles
    # TODO: source language dependent code in synthesis!!!
    my $en_zone = $zone->get_bundle()->get_zone( 'en', 'src' );
    return if $en_zone && $en_zone->sentence && $en_zone->sentence !~ /\./ && $punct_mark eq '.';

    my $punct = $aroot->create_child(
        {   'form'          => $punct_mark,
            'lemma'         => $punct_mark,
            'afun'          => 'AuxK',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
    $punct->shift_after_subtree($aroot);

    # TODO jednou by se mely pridat i koreny primych reci!!!
    return;
}

1;

__END__

# !!! pozor: koncovat interpunkce v primych recich neni zatim resena

=over

=item Treex::Block::T2A::CS::AddSentFinalPunct

Add a-nodes corresponding to sentence-final punctuation mark.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
