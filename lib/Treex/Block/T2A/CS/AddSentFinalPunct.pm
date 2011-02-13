package TCzechT_to_TCzechA::Add_sent_final_punct;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $troot = $bundle->get_tree('TCzechT');
    my $aroot = $bundle->get_tree('TCzechA');

    my ($first_troot) = $troot->get_children();
    if ( !$first_troot ) {
        Report::warn('No nodes in t-tree.');
        return;
    }

    # Don't put period after colon, semicolon, or three dots
    my $last_token = $troot->get_descendants( { last_only => 1 } );
    return if $last_token->get_attr('t_lemma') =~ /^[:;.]/;

    my $punct_mark = ( ( $first_troot->get_attr('sentmod') || '' ) eq 'inter' ) ? '?' : '.';

    #!!! dirty traversing of the pyramid at the lowest level
    # in order to distinguish full sentences from titles
    return if $punct_mark eq "."
        and defined $bundle->get_attr('english_source_sentence')
            and $bundle->get_attr('english_source_sentence') !~ /\./;

    my $punct = $aroot->create_child(
        {   attributes => {
                'm/form'        => $punct_mark,
                'm/lemma'       => $punct_mark,
                'afun'          => 'AuxK',
                'morphcat/pos'  => 'Z',
                'clause_number' => 0,
                }
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

=item TCzechT_to_TCzechA::Add_sent_final_punct

Add a-nodes corresponding to sentence-final punctuation mark.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
