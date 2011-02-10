package SEnglishA_to_SEnglishT::Add_cor_act;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

# verbs with object control type, copied from page 286
# in Pollard & Sag's Head-driven phrase structure grammar

# ??? premistit do english lexicon???
sub _object_control {
    my $t_lemma = shift;
    return $t_lemma =~ /^(order|persuade|bid|charge|command|direct|enjoin
|instruct|advise|authorize|mandate|convince|impel|induce|influence|inspire
|motivate|move|pressure|prompt|sway|stir|compel|press|propel|push|spur
|encourage|exhort|goad|incite|urge|bring|lead|signal|ask|empower|appeal
|dare|defy|beg|prevent|forbid|allow|permit|enable|cause|force|consider)$/sxm;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $t_root = $bundle->get_tree('SEnglishT');

    foreach my $infin_verb (
        grep { ( $_->formeme || "" ) =~ /inf/ }
        $t_root->get_descendants
        )
    {
        my $cor = $infin_verb->create_child;
        $cor->shift_before_node($infin_verb);
        $cor->set_attr( 't_lemma',  '#Cor' );
        $cor->set_attr( 'functor',  'ACT' );
        $cor->set_attr( 'formeme',  'n:elided' );
        $cor->set_attr( 'nodetype', 'qcomplex' );

        if ( not $infin_verb->get_parent->is_root and my ($grandpa) = $infin_verb->get_eff_parents ) {

            #            print $grandpa->t_lemma."  xxx\n";
            my $antec;
            my $type_of_control;

            if ( _object_control( ( $grandpa->t_lemma || '_root' ) ) ) {
                $type_of_control = "OBJ";
                ($antec) = grep { $_->formeme eq "n:obj" } $grandpa->get_eff_children;
            }
            else {
                ($antec) = grep { $_->formeme eq "n:subj" } $grandpa->get_eff_children;
                $type_of_control = "SUBJ";
            }

            #            print "sentence:\t".$bundle->get_attr('english_source_sentence')."\n";
            #            print "grandpa:\t".$grandpa->t_lemma."\n";
            #            print "infin:\t".$infin_verb->t_lemma."\n";
            if ($antec) {

                #                print "antec:\t".$antec->t_lemma."\n";
                $cor->set_deref_attr( 'coref_gram.rf', [$antec] );

                #                print $cor->get_fposition."\n";
            }
            else {

                #                print "antec:\tNOT FOUND\n";
            }

            #            print "\n";

        }

    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Add_cor_act

New SEnglishT nodes with t_lemma #Cor corresponding to unexpressed actors of infinitive
verbs are created. Grammatical coreference links are established to heuristically found
antecedents.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
