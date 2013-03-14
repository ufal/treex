package Treex::Block::T2T::EN2CS::TurnTextCorefToGramCoref;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;

    my $t_root = $zone->get_ttree();

    foreach my $perspron (
        grep {
            $_->t_lemma eq "#PersPron" and $_->formeme !~ /n:1/
        } $t_root->get_descendants
        )
    {

        my ($antec) = $perspron->get_coref_text_nodes();

        # !!! ruseni koreferencnich linku vedoucich na smazane uzly by chtelo zajistit nejak lip!
        if ( $antec ) {
            my $clause_head = _nearest_clause_head($perspron);

            if ($antec->formeme =~ /n:1/
                and defined $clause_head
                and $clause_head->t_lemma ne "být"
                and $antec->get_parent eq $clause_head
                )
            {

                # TODO: this should be definitely unified under the standard getters and setter for coreference
                $perspron->set_deref_attr( 'coref_gram.rf', [$antec] );
                $perspron->set_attr( 'coref_text.rf', undef );
            }
        }
    }
}

sub _nearest_clause_head {
    my ($tnode) = @_;
    my $parent = $tnode->get_parent;
    while ( not( $parent->is_root ) ) {    # climbing up to the nearest clause head
        if ( $parent->is_clause_head ) {
            return $parent;
        }
        $parent = $parent->get_parent
    }
    return undef;
}

1;

=over

=item Treex::Block::T2T::EN2CS::TurnTextCorefToGramCoref

Turn textual coreference to grammatical coreference
(related to reflexive pronouns).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
