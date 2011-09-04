package Treex::Block::Test::A::SubjectBelowVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if (($anode->afun||'') eq 'Sb') {
        foreach my $parent ($anode->get_eparents) {
            if (defined $parent->get_attr('iset/pos')
                    and $parent->get_attr('iset/pos') ne 'verb' ) {

                if ($parent->afun() ne 'AuxC') { # modern greek 
                    $self->complain($anode);
                }
            }
        }
    }
    return;
}

1;

__END__

SEE ALSO more accurate implementation for Czech 
https://wiki.ufal.ms.mff.cuni.cz/internal:pdt25:a-rovina#rodice-uzlu-sb

Counter examples from PDT:
 * "Voda a teplo = peníze"
 * "V . Klaus : O Ježkovi jsme nejednali"
 * Úspěchy(afun=Sb,eparents=odráží,zprostředkovaně) se odráží v ohodnocení
   a zprostředkovaně(afun=ExD,pos=D) i v podmínkách. 
 * "které se ne a ne vyloupnout"
 * "nezbude nic(pos=P) jiného , než vymáhat(parent=než, eparent=nic) dlužnou částku"
 * "Ministerstvo(parent=ochotno) financí bude ochotno(pos=A) dát"
 * "netřeba(pos=A) připomínat"

Counter examples from RDT (Romanian Dependency Treebank)
 *     "Este foarte greu de(pos=P,afun=AuxP) crezut(afun=Sb,parent=de)"
       "It is very hard to believe"
  lit. "Believing-it is very hard"
 
 * "operatiunile(afun=Sb) vor fi mult ingreunate(pos=A)"
   "the operations will become worse" 
   similar to Czech "bude ochotno"


Counter examples from Modern Greek Dependency Treebank
======================================================

(i)

In the case of subordinating conjunctions, subordinate clause 
often takes the grammatical function such as Subject or Object,
which is attached to the sub conjunction (AuxC). The AuxC will
be attached to the main clause's predicate.  

The structure will look like this,

                    Pred
                  /  |  \
                /    |   \
                        AuxC
                            \
                             \
                             Sb   ("Sb" is not just the role of a 
                                    single word , but of the entire clause.
                                   So the corresponding word of the "Sb" may 
                                    even be a "VERB")
                         
(ii)

There may also structures like this,

                     
                    Pred
                  /  |  \
                /    |   \
                        AuxC
                            \
                             \
                             Sb   (if the word is a "VERB")
                               \
                                \
                                Sb 



=over

=item Treex::Block::Test::A::SubjectBelowVerb

Subjects (afun=Sb) are expected only below verbs.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

