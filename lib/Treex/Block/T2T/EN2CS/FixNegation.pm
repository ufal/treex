package SEnglishT_to_TCzechT::Fix_negation;

use 5.008;
use utf8;
use strict;
use warnings;
use List::MoreUtils qw( any all );

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $clause_head ( grep { $_->get_attr('formeme') =~ /fin|rc/ } $t_root->get_descendants() ) {

        # double negation
        my @descendants_in_same_clause = $clause_head->get_clause_descendants();
        if ( any { $_->get_attr('t_lemma') =~ /^(nikdo|nic|žádný|ničí|nikdy|nikde)$/ } @descendants_in_same_clause ) {
            $clause_head->set_attr( 'gram/negation', 'neg1' );
        }

        # until
        my $en_tnode = $clause_head->get_source_tnode();
        if ( defined $en_tnode and $en_tnode->get_attr('formeme') =~ /(until|unless)/ ) {
            $clause_head->set_attr( 'gram/negation', 'neg1' );
        }

        # "Ani neprisel, ani nezavolal.", "Nepotkal Pepu ani Frantu."
        if (grep {_is_ani_neither_nor($_)} $clause_head->get_children
                or ($clause_head->get_attr('is_member')
                        and _is_ani_neither_nor($clause_head->get_parent))) {
            $clause_head->set_attr( 'gram/negation', 'neg1' );
        }
    }
    return;
}

sub _is_ani_neither_nor {
    my $tnode = shift;
    if ($tnode->get_attr('t_lemma') eq "ani") {
        my $en_tnode = $tnode->get_source_tnode;
        if ($en_tnode and $en_tnode->get_attr('t_lemma') =~ /(neither|nor)/) {
            return 1;
        }
    }
    return 0;
}

1;

=over

=item SEnglishT_to_TCzechT::Fix_negation

Special treatment of negation, e.g. because of
double negation in Czech (He never came -> Nikdy *NEprisel),
'until' conjunction (--> dokud ne), and 'ani'.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
