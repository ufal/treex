package SEnglishT_to_TCzechT::Change_Cor_to_PersPron;

use 5.008;
use strict;
use warnings;
use List::MoreUtils qw( any all );
use List::Util qw( first );

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');
    my @all_nodes = $t_root->get_descendants( { ordered => 1 } );

    # When looking for antecedent we need all nouns (as candidates) in reversed order
    my @nouns = reverse grep { ( $_->get_attr('gram/sempos') || '' ) =~ /^n/ } @all_nodes;

    VFIN:
    foreach my $vfin_tnode ( grep { $_->get_attr('formeme') =~ /fin|rc/ } @all_nodes ) {

        if (my ($perspron) = grep {$_->get_attr('t_lemma') eq "#Cor"} $vfin_tnode->get_children) {

            my $antec;
            if (defined $perspron->get_attr('coref_gram.rf')) {
                my $antec_id  = @{ $perspron->get_attr('coref_gram.rf') }[0];
                $antec = $bundle->get_document->get_node_by_id($antec_id);
            }


            # Skip verbs with subject (i.e. child in nominative)
#            next VFIN
#                if any { $_ ne $perspron and $_->get_attr('formeme') =~ /1/ } $vfin_tnode->get_eff_children();

            # chained gram.coref. in the case of relative clauses
            if ($antec and $antec->get_attr('coref_gram.rf')) {
                my $antec_id  = @{ $antec->get_attr('coref_gram.rf') }[0];
                $antec = $bundle->get_document->get_node_by_id($antec_id);
            }

            # Find antecedent by heuristics: nearest noun left to the $vfin_tnode
            if (not $antec) {
                $antec = first { $_->precedes($vfin_tnode) } @nouns;
            }

            # Fill the attributes appropriate for #PersPron nodes
            if ($antec) {
#                print "Success6\n";
                $perspron->set_attr('t_lemma','#PersPron');
                $perspron->set_attr('nodetype','complex');
                $perspron->set_attr('formeme','n:1');
                $perspron->set_attr('gram/sempos','n.pron.def.pers');
                $perspron->set_attr('gram/person',$antec->get_attr('gram/person') || 3);

                foreach my $attr_name ( 'gram/gender', 'gram/number' ) {
                    $perspron->set_attr( $attr_name, $antec->get_attr($attr_name) );
                }

                if ($antec->get_attr('is_member')) {
                    $perspron->set_attr( 'gram/number', 'pl' );
                }

                $perspron->set_attr( 'coref_text.rf', $perspron->get_attr('coref_gram.rf') );
                $perspron->set_attr( 'coref_gram.rf', undef );

#                print "sentence:\t".$bundle->get_attr('english_source_sentence')."\n";
#                print "verb:\t".$vfin_tnode->get_attr('t_lemma')."\n";
#                print "antec:\t".$antec->get_attr('t_lemma')."\n";

            }
        }
    }
    return;
}

1;

=over

=item SEnglishT_to_TCzechT::Change_Cor_to_PersPron

If an English infinitive is translated by a Czech finite clause,
then #Cor node should be changed to #PersPron node. Gender and number
are then copied from the (originally grammatical) antecedent.
Grammatical coreference is changed to textual.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
