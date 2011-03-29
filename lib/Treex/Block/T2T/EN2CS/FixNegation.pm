package Treex::Block::T2T::EN2CS::FixNegation;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( $tnode->formeme =~ /fin|rc/ ) {

        # double negation
        my @descendants_in_same_clause = $tnode->get_clause_descendants();
        if ( any { $_->t_lemma =~ /^(nikdo|nic|žádný|ničí|nikdy|nikde)$/ } @descendants_in_same_clause ) {
            $tnode->set_attr( 'gram/negation', 'neg1' );
        }

        # until
        my $en_tnode = $tnode->src_tnode;
        if ( defined $en_tnode and $en_tnode->formeme =~ /(until|unless)/ ) {
            $tnode->set_attr( 'gram/negation', 'neg1' );
        }

        # "Ani neprisel, ani nezavolal.", "Nepotkal Pepu ani Frantu."
        if (grep { _is_ani_neither_nor($_) }
            $tnode->get_children
            or ($tnode->is_member
                and _is_ani_neither_nor( $tnode->get_parent )
            )
            )
        {
            $tnode->set_attr( 'gram/negation', 'neg1' );
        }
    }

    if ( $tnode->t_lemma =~ /^(už|již)$/ and not $tnode->get_children ) {    # 'no longer'
        my $parent = $tnode->get_parent;
        if ( $parent->t_lemma =~ /^(už|již)$/ ) {
            my $grandpa = $parent->get_parent;
            if ( $grandpa->get_attr('gram/sempos') eq 'v' ) {
                $grandpa->set_attr( 'gram/negation', 'neg1' );
                $tnode->remove;
            }
        }
    }
    return;
}

sub _is_ani_neither_nor {
    my $tnode = shift;
    if ( $tnode->t_lemma eq "ani" ) {
        my $en_tnode = $tnode->src_tnode;
        if ( $en_tnode and $en_tnode->t_lemma =~ /(neither|nor)/ ) {
            return 1;
        }
    }
    return 0;
}

1;

=over

=item Treex::Block::T2T::EN2CS::FixNegation

Special treatment of negation, e.g. because of
double negation in Czech (He never came -> Nikdy *NEprisel),
'until' conjunction (--> dokud ne), and 'ani'.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
