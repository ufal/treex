package Treex::Block::A2A::CA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );
#    $self->deprel_to_afun($a_root)
    $self->attach_final_punctuation_to_root($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->restructure_coordination($a_root);
    $self->rehang_coordconj($a_root);
    $self->check_afuns($a_root);
    $self->rehang_subconj($a_root);
}


my %pos2afun = (
    q(prep) => 'AuxP',
    q(adj) => 'Atr',
    q(adv) => 'Adv',
);

my %subpos2afun = (
    q(det) => 'AuxA',
    q(sub) => 'AuxC',
);

my %parentpos2afun = (
    q(prep) => 'Adv',
    q(noun) => 'Atr',
);


# deprels extracted from the conll2009 data, documentation in /net/data/CoNLL/2009/es/doc/tagsets.pdf
my %deprel2afun = (
#    'coord' => 'uspech',
    q(a) => q(Atr),
    q(ao) => q(),
    q(atr) => q(),
    q(c) => q(Adv), # ?
    q(cag) => q(),
#    q(cc) => q(AuxC),
    q(cd) => q(Obj),
    q(ci) => q(Obj),
    q(conj) => q(AuxC),
    q(coord) => q(Coord),
    q(cpred) => q(Compl),
    q(creg) => q(AuxP),
    q(d) => q(AuxA),
    q(et) => q(),
    q(f) => q(AuxX),
    q(gerundi) => q(), # ?
    q(grup.a) => q(),
    q(grup.adv) => q(),
    q(grup.nom) => q(),
    q(grup.verb) => q(),
    q(i) => q(),
    q(impers) => q(),
    q(inc) => q(),
    q(infinitiu) => q(),
    q(interjeccio) => q(),
    q(mod) => q(Adv),
    q(morfema.pronominal) => q(AuxR),
    q(morfema.verbal) => q(AuxR),
    q(n) => q(), # noun?
    q(neg) => q(), # negation
    q(p) => q(), # pronoun?
    q(participi) => q(),
    q(pass) => q(AuxR),
    q(prep) => q(AuxP),
    q(r) => q(Adv),
    q(relatiu) => q(), # relative pronoun
    q(s) => q(AuxP),
    q(S) => q(Pred),
    q(sa) => q(Compl),
    q(s.a) => q(Atr),
    q(sadv) => q(Adv),
    q(sentence) => q(Pred),
    q(sn) => q(),
    q(sp) => q(AuxP),
    q(spec) => q(),
    q(suj) => q(Sb),
    q(v) => q(AuxV),
    q(voc) => q(),
    q(w) => q(),
    q(z) => q(), # number
);



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# /net/data/CoNLL/2009/es/doc/tagsets.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my ( $self, $root ) = @_;
    foreach my $node ($root->get_descendants)
    {
        my $deprel = $node->conll_deprel();
        my ($parent) = $node->get_eparents();
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $ppos   = $parent ? $parent->get_iset('pos') : '';
        my $afun = 'NR';
        # Adjective in leaf node. Could be headed by article! Example:
        # aquests primers tres mesos
        # these first three months
        # TREE: mesos ( aquests/spec ( primers/a , tres/d ) )
        if($deprel eq 'a')
        {
            $afun = 'Atr';
        }
        # Orational adjunct. Example:
        # segons el Tribunal Suprem
        # according to the Supreme Court
        # NOTE: "segons" is by far the most frequent lemma with the "ao" tag.
        elsif($deprel eq 'ao')
        {
            $afun = 'Adv';
        }
        # Attribute. The meaning is different from attribute in PDT.
        # els accidents van ser reals
        # the accidents were real
        # ser ( accidents/suj ( els/spec ) , van/v , reals/atr )
        elsif($deprel eq 'atr')
        {
            $afun = 'Pnom';
        }
        # Conjunction in leaf node. Very rare (errors?) In the examples, coordinating conjunctions are more frequent than subordinating ones.
        # See also "conj" and "coord".
        elsif($deprel eq 'c')
        {
            ###!!!
        }
        # Agent complement.
        # In a passive clause where subject is not the agent, this is the tag for the agent. Most frequently with the preposition "per". Example:
        # jutjat per un tribunal popular
        # tried by a kangaroo court
        elsif($deprel eq 'cag')
        {
            $afun = 'Obj';
        }
        # Adjunct. Example:
        # gràcies al fet
        # thanks to
        elsif($deprel eq 'cc')
        {
            $afun = 'Adv';
        }
        # Direct object. Example:
        # Llorens ha criticat la Generalitat/cd
        # Llorens has criticized the Government
        elsif($deprel eq 'cd')
        {
            $afun = 'Obj';
        }
        # Indirect object. Example:
        # La norma/suj permetrà a/ci les autonomies habilitar/cd altres sales de/cc forma extraordinària.
        # The rule will allow the autonomies to enable other rooms dramatically.
        elsif($deprel eq 'ci')
        {
            $afun = 'Obj';
        }
        # Subordinating conjunction (que, perquè, si, quan, ...)
        # The conjunction is attached to the head of the subordinate clause, which is attached to the superordinate predicate.
        elsif($deprel eq 'conj')
        {
            ###!!! We will later want to reattach it. Now it is a leaf.
            $afun = 'AuxC';
        }
        # Coordinating conjunction (i, o, però, ni, ...)
        # The conjunction is attached to the first conjunct.
        elsif($deprel eq 'coord')
        {
            $afun = 'Coord';
        }
        # Prepositional object. Example:
        # entrar en crisi
        # enter crisis
        elsif($deprel eq 'creg')
        {
            $afun = 'Obj';
        }
        # Determiner leaf. Example:
        # tots els usuaris
        # all the users
        # TREE: usuaris ( els/spec ( tots/d ) )
        elsif($deprel eq 'd')
        {
            $afun = 'Atr';
        }
        # Textual element, e.g. introducing expression at the beginning of the sentence. Example:
        # En aquest sentit, ...
        # In this sense, ...
        elsif($deprel eq 'et')
        {
            $afun = 'Adv';
        }
        # Punctuation mark.
        elsif($deprel eq 'f')
        {
            if($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }
        # Gerund. Example:
        # perdre el temps intentant debatre amb el grup
        # waste time trying to discuss with the group
        # TREE: debatre ( perdre/infinitiu , temps/cd ( el/spec ) , intentant/gerundi , amb/cc ( grup/sn ( el/spec ) ) )
        elsif($deprel eq 'gerundi')
        {
            ###!!! The structure in the above example is strange.
            ###!!! We would make "debatre" object of "intentant".
            $afun = 'AuxV';
        }
        # Adjective conjunct, member of adjective group.
        # Adverbial conjunct, member of adverb group.
        # Nominal conjunct, member of noun group.
        elsif($deprel =~ m/^grup\.(a|adv|nom)$/)
        {
            $afun = 'CoordArg';
        }
        # grup.verb is probably an error. There is just one occurrence and it is the first part of a compound coordinating conjunction either-or.
        elsif($deprel eq 'grup.verb')
        {
            $afun = 'AuxY';
        }
        # Interjection leaf, single occurrence.
        elsif($deprel eq 'i')
        {
            $afun = 'ExD';
        }
        # Impersonality mark (reflexive pronoun, passive construction).
        elsif($deprel eq 'impers')
        {
            $afun = 'AuxR';
        }
        # Inserted element (parenthesis). Example:
        # , ha afegit,
        # , he added,
        elsif($deprel eq 'inc')
        {
            # Annotation in PDT (http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s06.html):
            # If it is a particle that would normally get AuxY, it gets AuxY-Pa.
            # If it is a constituent that matches the sentence, just is delimited by commas or brackets: its normal afun + -Pa.
            # If it is a sentence with predicate and it does not fit in the structure of the surrounding sentence, Pred-Pa.
            # Otherwise, ExD-Pa.
            ###!!! We did not capture parenthesis in HamleDT so far.
            if($pos eq 'verb')
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }
        # Infinitive. Example:
        # destacar que toca un violí
        # to emphasize that he plays a violin
        # TREE: toca ( destacar/infinitiu , que/conj , violí/cd ( un/spec ) )
        elsif($deprel eq 'infinitiu')
        {
            ###!!! The structure in the above example is strange.
            ###!!! We would make "que toca" object of "destacar".
            $afun = 'AuxV';
        }
        # Interjection.
        elsif($deprel eq 'interjeccio')
        {
            $afun = 'ExD';
        }
        # Non-argumental verb modifier.
        # no, també, només, ja, tampoc
        # not, also, only, already, either
        elsif($deprel eq 'mod')
        {
            $afun = 'Adv';
        }
        # Reflexive pronoun.
        # es, s', hi, -se, se
        elsif($deprel eq 'morfema.pronominal')
        {
            $afun = 'Obj';
        }
        # Reflexive pronoun. See also "impers" and "morfema.pronominal".
        # es, s', -se, se
        # on es podrà participar en tertúlies
        # where one can participate in discussions
        # en els quals es continuarà el seguiment i el control de consums
        # in which one continues to monitor and control consumption
        # al complir-se un segle del naixement de l'artista
        # on completion of a century of the birth of the artist
        elsif($deprel eq 'morfema.verbal')
        {
            $afun = 'AuxR';
        }
        # Noun leaf. Often within quantification expressions; most frequent word is "resta". Example:
        # un centenar de representants
        # one hundred representatives
        # TREE: representants ( un/spec ( centenar/n , de/s ) )
        elsif($deprel eq 'n')
        {
            ###!!! We will want to restructure this.
            $afun = 'DetArg';
        }
        # Negation. Adverbial particle that may modify nouns, adjectives and verbs. Example:
        # persona no grata
        # undesirable person
        elsif($deprel eq 'neg')
        {
            $afun = 'Adv';
        }
        # Pronoun leaf. Example:
        # el mateix Borrell
        # the same Borrell
        # TREE: Borrell ( el/spec ( mateix/p ) )
        elsif($deprel eq 'p')
        {
            ###!!! We will want to restructure this.
            $afun = 'DetArg';
        }
        # Participle leaf. Example:
        # distribuïda atenent a criteris
        # distributed according to criteria
        # TREE: atenent ( distribuïda/participi , a/creg ( criteris/sn ) )
        elsif($deprel eq 'participi')
        {
            ###!!! We will want to restructure this.
            $afun = 'AdjArg';
        }
        # Reflexive pronoun used to form reflexive passive. Example:
        # See also morfema.pronominal, morfema.verbal and impers.
        # on es va explicar
        # where it was explained
        elsif($deprel eq 'pass')
        {
            $afun = 'AuxR';
        }
        # Preposition leaf attached to a verb. Example: de, com, a, segons, a_punt_de
        # per mirar de conèixer les circumstàncies
        # to try to meet the circumstances
        elsif($deprel eq 'prep')
        {
            ###!!! We will want to restructure this.
            $afun = 'AuxP';
        }
        # Adverb leaf. Example:
        # ara fa tan sols un any
        # just a year ago
        # LIT.: now does so only one year
        # TREE: any ( ara/r , fa/v , tan_sols/r , un/d )
        elsif($deprel eq 'r')
        {
            $afun = 'Adv';
        }
        # Relative pronoun (què, qual, quals, qui, que, on). Example:
        # en el qual
        # in which
        # TREE: en ( qual/relatiu ( el/d ) )
        # But also:
        # ser el que va registrar
        # to be the one that registered
        # TREE: ser ( registrar/atr ( el/spec , que/relatiu , va/v ) )
        ###!!! We would like to restructure this latter example.
        elsif($deprel eq 'relatiu')
        {
            $afun = 'PrepArg';
        }
        # Head of subordinate clause. Example:
        # litres que han arribat al riu
        # liters that have reached the river
        # TREE: litres ( arribat/S ( que/suj , han/v , al/cc ( riu/sn ) ) )
        elsif($deprel eq 'S')
        {
            if($ppos eq 'noun')
            {
                $afun = 'Atr';
            }
            else
            {
                ###!!! We should look at children to distinguish adverbial clauses. (E.g., is "where" or "when" among the children?)
                ###!!! On the other hand, looking at parent (verba dicendi) could reveal that it is complement clause.
                $afun = 'Adv'; ###!!! or 'Obj'
            }
        }
        # Preposition leaf. See also "prep". Example:
        # les respostes que s'ha de donar
        # the answers to be given
        # LIT.: the answers that are of giving
        # TREE: respostes ( les/spec , donar/S ( que/suj , s'/pass , ha/v , de/s ) )
        elsif($deprel eq 's')
        {
            ###!!! We will want to restructure this.
            $afun = 'AuxP';
        }
        # Adjective phrase that does not depend on a verb. Mostly a modifier of noun. Example:
        # una selva petita
        # a small forest
        # TREE: selva ( una/spec , petita/s.a )
        elsif($deprel eq 's.a')
        {
            $afun = 'Atr';
        }
        # Adjective phrase that depends on a verb.
        # (But in reality, many occurrences I saw do not depend on a verb. Are they annotation errors?)
        # Maybe it is just because of the automatic conversion from phrase trees.
        # 16 examples in PML-TQ depend on prepositions.
        # 11 examples in PML-TQ depend on verbs. But they are neither arguments, nor verbal attributes or nominal predicates.
        # Example:
        # Quan abans comencem, millor.
        # The earlier we start the better.
        # TREE: comencem/sentence ( Quan/conj , abans/cc , ,/f , millor/sa , ./f )
        elsif($deprel eq 'sa')
        {
            if($ppos eq 'prep')
            {
                $afun = 'PrepArg';
            }
            else
            {
                $afun = 'Atr';
            }
        }
        # Adverb phrase.
        elsif($deprel eq 'sadv')
        {
            $afun = 'Adv';
        }
        # Main predicate or other main head if there is no predicate.
        elsif($deprel eq 'sentence')
        {
            if($pos eq 'verb')
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }
        # Noun phrase that is not tagged specifically as subject or object.
        # Most of these cases (83%) are attached to a preposition.
        # Some of the cases where it depends on a noun resemble apposition.
        elsif($deprel eq 'sn')
        {
            if($ppos =~ m/^(prep|conj)$/)
            {
                $afun = 'PrepArg';
            }
            elsif($ppos =~ m/^(verb|adj)$/)
            {
                $afun = 'Obj';
            }
            elsif($ppos eq 'adv')
            {
                $afun = 'Adv';
            }
            else
            {
                $afun = 'Apposition';
            }
        }
        # Prepositional phrase.
        elsif($deprel eq 'sp')
        {
            $afun = 'AuxP';
        }
        # Specifier, i.e. article, numeral or other determiner.
        elsif($deprel eq 'spec')
        {
            $afun = 'Atr';
        }
        # Subject, including inserted empty nodes (Catalan is pro-drop language) and relative pronouns in subordinate clauses.
        elsif($deprel eq 'suj')
        {
            $afun = 'Sb';
        }
        # Auxiliary or semi-auxiliary verb. Example:
        # La moció ha estat aprovada.
        # The motion has been approved.
        elsif($deprel eq 'v')
        {
            $afun = 'AuxV';
        }
        # Vocative. Example:
        # Senyora, escriure una cançó així és molt difícil.
        # Madam, it is very difficult to write a song here.
        elsif($deprel eq 'voc')
        {
            # In PDT, vocatives are annotated as "ExD_Pa" (parenthesis).
            $afun = "ExD"; ###!!! a co ta parenteze?
        }
        # Date/time. Example:
        # les 22.30 hores
        # 22:30
        # TREE: hores ( les/spec ( 22.30/w ) )
        # This tag is very rare (possible annotation error?) Majority of time expressions is annotated otherwise, e.g.:
        # 1.15 hores
        # TREE: hores ( 1.15/spec )
        elsif($deprel eq 'w')
        {
            $afun = 'DetArg';
        }
        # Number (expressed in digits) leaf, usually attached to a determiner.
        elsif($deprel eq 'z')
        {
            $afun = 'DetArg';
        }
        $node->set_afun($afun);
    }
}



use Treex::Tool::ATreeTransformer::DepReverser;
my $subconj_reverser =
    Treex::Tool::ATreeTransformer::DepReverser->new(
            {
                subscription     => '',
                nodes_to_reverse => sub {
                    my ( $child, $parent ) = @_;
                    return ( $child->afun eq 'AuxC' );
                },
                move_with_parent => sub {1;},
                move_with_child => sub {1;},
            }
        );


sub rehang_subconj {
    my ( $self, $root ) = @_;
    $subconj_reverser->apply_on_tree($root);

}

sub rehang_coordconj {
    my ( $self, $root ) = @_;

    foreach my $coord (grep {$_->conll_deprel eq 'coord'}
                           map {$_->get_descendants} $root->get_children) {
        my $first_member = $coord->get_parent;
        $first_member->set_is_member(1);
        $coord->set_parent($first_member->get_parent);
        $first_member->set_parent($coord);

        my $second_member = 1;
        foreach my $node (grep {$_->ord > $coord->ord} $first_member->get_children({ordered=>1})) {
            $node->set_parent($coord);
            if ($second_member) {
                $node->set_is_member(1);
                $second_member = 0;
            }
        }
    }
}




1;

=over

=item Treex::Block::A2A::CA::Harmonize

Converts Catalan trees from CoNLL to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011-2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
