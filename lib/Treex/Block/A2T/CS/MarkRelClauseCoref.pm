package SCzechA_to_SCzechT::Mark_relclause_coref;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');

        foreach my $t_node ( grep { $_->get_attr('a/lex.rf') } $t_root->get_descendants ) {
            my $lex_a_node = $document->get_node_by_id( $t_node->get_attr('a/lex.rf') );
            if ( $lex_a_node->get_attr('m/tag') =~ /^.[149EJK\?]/ ) {

                my $relclause = $t_node;
                while ( $relclause->get_parent and not $relclause->get_attr('is_clause_head') ) {
                    $relclause = $relclause->get_parent;
                }
                if ( $relclause->get_parent and not $relclause->get_parent->is_root ) {    # klauze se nasla a tudiz to nedobehlo az ke koreni
                    my $antec = $relclause->get_parent;
                    if ( defined $antec->get_attr('a/lex.rf') ) {
                        my $antec_lex_a_node = $document->get_node_by_id( $antec->get_attr('a/lex.rf') );
                        if ( $antec_lex_a_node->get_attr('m/tag') =~ /^(NN|PR|DT)/ ) {

                            #print "ANTEC:   ".$antec_lex_a_node->get_attr('m/tag')."\n";
                            $t_node->set_attr( 'coref_gram.rf', [ $antec->get_attr('id') ] );
                        }
                    }
                }
            }
        }
    }
}

1;

# prakticky identicke s anglickym protejskem, mozna by to chtelo predelat na genericky blok!!!

=over

=item SCzechA_to_SCzechT::Mark_relclause_coref

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in SCzechT trees
and store into the C<coref_gram.rf> attribute.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
