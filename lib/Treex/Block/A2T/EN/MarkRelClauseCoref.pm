package SEnglishA_to_SEnglishT::Mark_relclause_coref;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    TNODE:
    foreach my $t_node ( $bundle->get_tree('SEnglishT')->get_descendants() ) {
        my $a_node = $t_node->get_lex_anode();

        # Process coreferring words with tags:
        # WP  (who, what, whom), WP$ (whose), WRB (how, where, why)
        # WDT (which, what ... before noun - as a determiner)
        next TNODE if !$a_node || $a_node->get_attr('m/tag') !~ /^W/;
        my $t_relclause_head = $t_node->get_clause_head();

        # Antecedent is the parent of relative clause head.
        # (In other words, the relative clause modifies the antecedent.)
        my $t_antec = $t_relclause_head->get_parent();
        next TNODE if !$t_antec || $t_antec->is_root();
        my $a_antec = $t_antec->get_lex_anode();
        if ( $a_antec->get_attr('m/tag') =~ /^(NN|PR|DT)/ ) {
            $t_node->set_deref_attr( 'coref_gram.rf', [$t_antec] );
        }
    }
    return;
}

1;

__END__

=over

=item SEnglishA_to_SEnglishT::Mark_relclause_coref

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in SEnglishT trees
and store into the C<coref_gram.rf> attribute.

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
