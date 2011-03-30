package Treex::Block::T2A::CS::FixPossessiveAdjs;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

use Lexicon::Czech;

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if (( $t_node->formeme || "" ) eq 'n:poss'
        and ( $t_node->get_attr('mlayer_pos') || "" ) ne 'P'
        and ( $t_node->t_lemma || "" ) ne '#PersPron'
        )
    {

        my $a_node     = $t_node->get_lex_anode();    # or return;
        my $noun_lemma = $a_node->lemma;

        #            print "noun: $noun_lemma\n";

        my $adj_lemma = Lexicon::Czech::get_poss_adj($noun_lemma);
        $a_node->set_lemma($adj_lemma);
        $a_node->set_attr( 'morphcat/subpos', '.' );
        $a_node->set_attr( 'morphcat/pos',    'A' );

        # with adjectives, the following categories should come from agreement
        foreach my $cat (qw(gender number)) {
            $a_node->set_attr( "morphcat/$cat", '.' );
        }

        #            print "$noun_lemma ==> $adj_lemma\n";
    }

    return;
}

1;

__END__

=over

=item Treex::Block::T2A::CS::FixPossessiveAdjs

Nouns with the 'n:poss' formeme are turned to possessive adjectives
on the a-layer.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
