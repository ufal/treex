package Treex::Block::W2A::EN::FixDicendiVerbs;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::EN;

sub process_atree {
    my ( $self, $a_root ) = @_;

    # Gather all tokens except commas.
    # We don't care whether there is:
    # "I know," said Jim.
    # "I know", said Jim.
    # or "I know" said Jim.
    my @a_nodes = grep { $_->lemma ne ',' } $a_root->get_descendants( { ordered => 1 } );

    # Iterate through indices of all dicendi verbs
    DICENDI:
    foreach my $i_dicendi (
        grep { Treex::Tool::Lexicon::EN::is_dicendi_verb( $a_nodes[$_]->lemma ) } ( 2 .. $#a_nodes )
        )
    {
        my $dicendi = $a_nodes[$i_dicendi];

        # Skip words which are not verbs (e.g "claim") in this context
        next DICENDI if $dicendi->tag !~ /^V/;

        # Skip dicendi verbs that are not preceded by a quote
        # TODO: This is too restrictive ("I know," Jim said.)
        next DICENDI if $a_nodes[ $i_dicendi - 1 ]->lemma !~ /^(["'»]|'')$/;

        # Find the root of direct speech, i.e. the highest node between the quotes
        my $dsp_root = $a_nodes[ $i_dicendi - 2 ];
        foreach my $node ( @a_nodes[ 0 .. $i_dicendi - 3 ] ) {
            if ( $node->lemma =~ /['`]/ ) {
                $dsp_root = $a_nodes[ $i_dicendi - 2 ];
            }
            elsif ( $node->get_depth() < $dsp_root->get_depth() ) {
                $dsp_root = $node;
            }
        }

        # Skip cases that are parsed correctly,
        # i.e. $dsp_root depends on the dicendi verb
        next DICENDI if $dsp_root->is_descendant_of($dicendi);

        # Rehang wrongly parsed cases
        $dicendi->set_parent( $dsp_root->get_parent() );
        $dsp_root->set_parent($dicendi);
    }
    return 1;
}

1;

=over

=item Treex::Block::W2A::EN::FixDicendiVerbs

In sentences like I<"It was good," said Mr. Brown.>,
the dicendi verb (I<said>) should govern the direct speech subtree
(i.e. its root I<was>).

=back

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
