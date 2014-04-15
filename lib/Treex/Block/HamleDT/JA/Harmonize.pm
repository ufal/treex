package Treex::Block::HamleDT::JA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ja::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

use List::Util qw(first);

#------------------------------------------------------------------------------
# Reads the Japanese CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);

    my $debug = 1;

    $self->attach_final_punctuation_to_root($a_root);
    $self->restructure_coordination($a_root, $debug);
    $self->process_prep_sub_arg_cloud($a_root, $debug);
    $self->check_afuns($a_root);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# /net/data/conll/2006/ja/doc/report-240-00.ps
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun {
    my $self = shift;
    my $root = shift;
    for my $node ($root->get_descendants()) {
        my $deprel = $node->conll_deprel();
        my $form = $node->form();
        my $conll_cpos = $node->conll_cpos();
        my $conll_pos = $node->conll_pos();
        my $pos = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $parent = $node->get_parent();
        my $ppos = $parent->get_iset('pos');
        my $psubpos = $parent->get_iset('subpos');
        my @children = $node->get_children({ordered => 1});

        my $afun = '';

        # children of the technical root
        if ($deprel eq 'ROOT') {
            # "clean" predicate
            if ($pos eq 'verb') {
                $afun = 'Pred';
            }
            # postposition/particle as a head - but we do not want
            # to assign AuxP now; later we will pass the label to the child
            elsif ($subpos eq 'post' or $pos eq 'part') {
                $afun = 'Pred';
            }
            # coordinating conjunction/particle (Pconj)
            elsif ($subpos eq 'coor') {
                $afun = 'Pred';
                $node->wild()->{coordinator} = 1;
            }
            elsif ($subpos eq 'punc') {
                if ($node->get_iset('punctype') =~ m/^(peri|qest)$/) {
                    $afun = 'AuxK';
                }
            }
            else {
                $afun = 'ExD';
            }
        }

        # Punctuation
        elsif ($deprel eq 'PUNCT') {
            my $punctype = $node->get_iset('punctype');
            if ($punctype eq 'comm') {
                $afun = 'AuxX';
            }
            elsif ($punctype =~ m/^(peri|qest|excl)$/) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # Subject
        elsif ($deprel eq 'SBJ') {
            $afun = 'Sb';
            #if ($subpos eq 'coor') {
            #    $node->wild()->{coordinator} = 1;
            #}
        }

        # Complement
        # obligatory element with respect to the head incl. bound forms
        # ("nominal suffixes, postpositions, formal nouns, auxiliary verbs and
        # so on") and predicate-argument structures
        elsif ($deprel eq 'COMP') {
            if ($ppos eq 'prep') {
                $afun = 'PrepArg';
            }
            elsif ($ppos eq 'part') {
                $afun = 'SubArg';
            }
            #elsif ($psubpos eq 'coor') {
            #    $afun = 'CoordArg';
            #    $node->wild()->{conjunct} = 1;
            #}
            elsif ($ppos eq 'verb') {
                if ($psubpos eq 'cop') {
                    $afun = 'Pnom';
                }
                # just a heuristic
                elsif ($pos eq 'adv') {
                    $afun = 'Adv';
                }
                else {
                    $afun = 'Obj';
                }
            }
            else {
                $afun = 'Atr';
            }
        }
        # Adjunct
        # any left-hand constituent that is not a complement/subject
        elsif ($deprel eq 'ADJ') {
            if ($pos eq 'conj') {
                $afun = 'Coord';
                $node->wild()->{coordinator} = 1;
                $parent->wild()->{conjunct} = 1;
            }
            # if the parent is preposition, this node must be rehanged onto the preposition complement
            elsif ($parent->conll_pos =~ m/^(Nsf|P|PQ|Pacc|Pfoc|Pgen|Pnom)$/) {
                $afun = 'Atr';
                # find the complement among the siblings (preferring the ones to the right);
                my @siblings = ($node->get_siblings({following_only=>1}), $node->get_siblings({preceding_only=>1}));
                my $new_parent = ( first { $_->conll_deprel eq 'COMP' } @siblings ) || $parent;
                $node->set_parent($new_parent);
            }
            elsif ($ppos =~ m/^(noun|num)$/) {
                $afun = 'Atr';
            }
            # daitai kono youna = だいたい この ような
            # daitai = 大体 = substantially, approximately
            # kono = この = this
            # youna = ような = like, similar-to (adjectival postposition)
            elsif ($ppos =~ m/^(verb|adj|adv|prep)$/) {
                $afun = 'Adv';
            }
            # Topicalized adjuncts with the marker "wa" attached to the main clause.
            # Example: kyou kite itadaita no wa, ...
            elsif (scalar(@children) >= 1 && $children[-1]->form() eq 'wa') {
                ###!!! There is not a better label at the moment but we may want to create a special language-specific label for this in future.
                ###!!! We may also want to treat "wa" as postposition and reattach it to head the adjunct.
                $afun = 'Adv';
            }
            elsif ($node->get_iset('advtype') eq 'tim') {
                $afun = 'Adv';
            }
            elsif ($node->form() eq 'kedo' && $parent->form() eq 'kedo')
            {
                $afun = 'Adv';
            }
            elsif ($ppos eq 'part')
            {
                $afun = 'Adv';
            }
            else {
                $afun = 'NR';
                print STDERR ($node->get_address, "\t",
                              "Unrecognized $conll_pos ADJ under ", $parent->conll_pos, "\n");
            }
        }

        # Marker
        elsif ($deprel eq 'MRK') {
            # topicalizers and focalizers
            if ($conll_pos eq 'Pfoc') {
                $afun = 'AuxZ';
            }
            # particles for expressing attitude/empathy, or turning the phrase
            # into a question
            elsif ($conll_pos eq 'PSE') {
                $afun = 'AuxO';
            }
            # postpositions after adverbs with no syntactic, but instead
            # rhetorical function
            elsif ($conll_pos eq 'P' and $ppos eq 'adv') {
                $afun = 'AuxO';
            }
            # coordination marker
            elsif ($subpos eq 'coor' or $pos eq 'conj') {
                $afun = 'Coord';
                $node->wild()->{coordinator} = 1;
                $parent->wild()->{conjunct} = 1;
            }
            # two-word conjunction "narabi ni" = ならびに = 並びに = and (also); both ... and; as well as
            # shashiNka = しゃしんか = 写真家 = photographer
            # Example: doitsu no amerikajiN shashiNka narabi ni amerika no doitsujiN shashiNka
            elsif ($form eq 'ni' && scalar(@children)==1 && $children[0]->form() eq 'narabi') {
                ###!!! The current detection of coordination will probably fail at this.
                $afun = 'AuxY'; # this is intended to be later shifted one level down
                $node->wild()->{coordinator} = 1; # this is intended to survive here
                $parent->wild()->{conjunct} = 1;
            }
            # douka = どうか = please
            elsif ($form eq 'douka') {
                $afun = 'ExD';
            }
            # atari = あたり: around
            # juuninichi juusaNnichi atari de = around the twelfth, thirteenth
            elsif ($form eq 'atari') {
                $afun = 'AuxY';
            }
            elsif ($pos eq 'prep' || $node->form() =~ m/^(ato|no)$/) {
                $afun = 'AuxP';
            }
            else {
                $afun = 'NR';
                print STDERR ($node->get_address, "\t",
                              "Unrecognized $conll_pos MRK under ", $parent->conll_pos, "\n");
            }
        }

        # Co-head
        # "listing of items, coordinations, and compositional expressions"
        # compositional expressions: date & time, full name, from-to expressions
        elsif ($deprel eq 'HD') {
            # coordinations
            my @siblings = $node->get_siblings();
            if ( first {$_->get_iset('pos') eq 'conj'} @siblings ) {
                $afun = 'CoordArg';
                $node->wild()->{conjunct} = 1;
            }
            # names
            elsif ($subpos eq 'prop' and $psubpos eq 'prop') {
                $afun = 'Atr';
            }
            # date and time
            elsif ($node->get_iset('advtype') eq 'tim' and $parent->get_iset('advtype') eq 'tim') {
                $afun = 'Atr';
            }
            # others mostly also qualify for Atr, e.g.
            # 寒九十時で = kaNkuu juuji de = ninth-day-of-cold-season ten-o-clock at
            # 一日版 = ichinichi haN = first-day-of-month edition
            elsif ($ppos =~ m/^(noun|num)$/ || $parent->get_iset('advtype') eq 'tim') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'adv' && $ppos eq 'adv') {
                $afun = 'Adv';
            }
            # juuichiji = 十一時 = 11 hours (CDtime/HD)
            # yoNjuppuN = 四十分 = よんじゅっぷん = 40 minutes (CDtime/COMP)
            # hatsu (Nsf/HD) = 発? = departing ... značka Nsf znamená "noun suffix", takže není jasné, proč vlastně je z toho v Intersetu záložka. I když to asi může mít podobné chování.
            # In this case the "hatsu" was attached to another "hatsu", from "kaNsaikuukou hatsu" (location from which they departed).
            elsif ($pos eq 'prep' && $ppos eq 'prep') {
                $afun = 'Atr';
            }
            # nanika = なにか = 何か = something (NN/HD)
            # koukuugaisha de kimetai toka
            # toka = とか = among other things (Pcnj/COMP)
            elsif ($pos eq 'noun' && $ppos =~ m/^(prep|conj)$/) {
                $afun = 'Atr';
            }
            elsif ($ppos eq 'noun') {
                $afun = 'Atr';
            }
            # yoru shichiji goro = lit. night seven-o-clock around
            elsif ($node->get_iset('advtype') eq 'tim' && $ppos eq 'prep')
            {
                ###!!! We should reshape the structure so that only one of the time specifications depends directly on the postposition.
                $afun = 'Atr';
            }
            ###!!! Should this be coordination?
            # deNsha de iku ka hikouki de iku ka
            # naNji ni shuppatsu suru ka, chuuoueki ni naNji ni koreba ii ka
            elsif ($node->form() eq 'ka' && $parent->form() eq 'ka')
            {
                $afun = 'Atr';
            }
            elsif ($node->form() eq 'ka' && $ppos eq 'verb')
            {
                $afun = 'Adv';
            }
            # takaku mo nai hikuku mo nai
            elsif ($node->form() eq 'nai' && $parent->form() eq 'nai')
            {
                $afun = 'Atr';
            }
            # yasui takai
            elsif ($pos eq 'adj' && $ppos eq 'adj')
            {
                $afun = 'Atr';
            }
            # shoushou = しょうしょう = 少々 = just a minute
            elsif ($node->form() eq 'shoushou')
            {
                $afun = 'Adv';
            }
            # yoroshikereba = よろしければ = if you please, if you don't mind
            elsif ($node->form() eq 'yoroshikereba')
            {
                $afun = 'Adv';
            }
            elsif ($pos eq 'adv')
            {
                $afun = 'Adv';
            }
            elsif ($conll_cpos =~ m/^P/)
            {
                $afun = 'Adv';
            }
            # maireeji desu  toka oshokuji desu  toka nanika
            # NN       PVfin Pcnj VN       PVfin Pcnj NN
            # COMP     COMP  HD   COMP     COMP  HD   SBJ
            # まいれえじ です とか おしょくじ です とか なにか
            # マイレージ = mileage
            # お食事 = dining, restaurant
            # とか = among other things
            elsif ($ppos eq 'noun')
            {
                $afun = 'Atr';
            }
            elsif ($pos eq 'verb' && $parent->form() eq 'ka')
            {
                $afun = 'SubArg';
            }
            else {
                $afun = 'NR';
                print STDERR $node->get_address, "\t", "Unrecognized $conll_pos HD under ", $parent->conll_pos, "\n";
            }
        }

        # Unspecified
        # numericals, speech errors, interjections
        elsif ($deprel eq '-') {
            $afun = 'ExD';
        }

        # No other deprel is defined
        else {
            $afun = 'NR';
            print STDERR $node->get_address, "\t", "Unrecognized deprel $deprel", "\n";
        }
        $node->set_afun($afun);
    }
    # Fix known irregularities in the data.
    # Do so here, before the superordinate class operates on the data.
    $self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors and irregularities.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        ###!!! DZ: Well, this is not really an annotation error but I am failing at the moment to solve it at the right place.
        if ($node->form() eq 'nanika')
        {
            my @children = $node->children();
            if (scalar(@children)==2 && $children[0]->form() eq 'toka' && $children[1]->form() eq 'toka')
            {
                # There are two conjuncts, each headed by its own coordinating postposition "toka" ("among other things").
                my @gc0 = $children[0]->children();
                my @gc1 = $children[1]->children();
                if (scalar(@gc0)==1 && scalar(@gc1)==1)
                {
                    my $toka0 = $children[0];
                    my $toka1 = $children[1];
                    my $gc0 = $gc0[0];
                    my $gc1 = $gc1[0];
                    $toka1->set_afun('Coord');
                    $toka1->wild()->{conjunct} = undef;
                    $gc1->set_afun('Atr');
                    $gc1->set_is_member(1);
                    $toka0->set_parent($toka1);
                    $toka0->set_afun('AuxY');
                    $toka0->wild()->{conjunct} = undef;
                    $gc0->set_parent($toka1);
                    $gc0->set_afun('Atr');
                    $gc0->set_is_member(1);
                }
            }
            elsif (scalar(@children)==0 && !$node->parent()->is_root() && $node->parent()->form() eq 'nanika')
            {
                $node->set_afun('Atr');
                $node->wild()->{conjunct} = undef;
            }
        }
    }
}

# there are 2 types of coordination with delimiters (always non-punctuation (?))
# 1. coordinator is between the phrases in the constituency tree;
#    in depencency tree, it is a child of the second conjunct and
#    a right sister of the first conjunct (which has deprel HEAD)
# 2. the coordinator marks an individual conjuct;
#    each conjunct is marked separately and the coordinator is
#    a child of the conjunct
# however, there are some coordinations without delimiters - currently we ignore those # TODO
sub detect_coordination {
     my $self = shift;
     my $node = shift;
     my $coordination = shift;
     my $debug = shift;
     log_fatal("Missing node") unless (defined($node));
     return unless ($node->wild()->{conjunct});
     my @children = $node->get_children();
     return unless (first {$_->wild()->{coordinator}} @children);
     $coordination->add_conjunct($node, 0);
     $coordination->set_parent($node->parent());
     $coordination->set_afun($node->afun());
     for my $child (@children) {
         if ($child->wild()->{conjunct}) {
             my $orphan = 0;
             $coordination->add_conjunct($child, $orphan);
         }
         elsif ($child->wild()->{coordinator}) {
             my $symbol = ($child->get_iset('pos') eq 'punc');
             $coordination->add_delimiter($child, $symbol);
         }
         else {
             $coordination->add_shared_modifier($child);
         }
     }
     my @recurse = $coordination->get_conjuncts();
     push(@recurse, $coordination->get_shared_modifiers());
     return @recurse;
}

1;

=over

=item Treex::Block::HamleDT::JA::Harmonize

Converts Japanese CoNLL treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# Copyright 2014 Jan Mašek <masek@ufal.mff.cuni.cz>
# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
