package Treex::Block::T2A::CS::DistinguishHomonymousMlemmas;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($tnode->t_lemma =~ /^stát(_se)?$/
        and $tnode->get_attr('mlayer_pos') eq "V"
        )
    {

        my $anode     = $tnode->get_lex_anode;
        my $src_tnode = $tnode->src_tnode;

        my $index;
        my $source_tlemma = $src_tnode->t_lemma;

        if ( $source_tlemma =~ /^(happen|become|get|grow|be)$/ ) {
            $index = 2;
        }
        elsif ( $source_tlemma =~ /^(stand|move|stop|go|insist)$/ ) {
            $index = 3;
        }
        else {    # nejcastejsi: cost
            $index = 4;
        }

        $anode->set_lemma( $anode->lemma . "-$index" );

    }
    return;
}

1;

=over

=item Treex::Block::T2A::CS::DistinguishHomonymousMlemmas

Adding numerical suffices to morphological lemmas, in order
to distinguish homonyms with different infleciton (such as stát-1).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
