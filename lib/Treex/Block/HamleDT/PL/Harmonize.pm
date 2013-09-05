package Treex::Block::HamleDT::PL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Polish tree, converts morphosyntactic tags to the PDT tagset, 
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
}

### TODO ###
sub detect_coordination { 
    my $self         = shift;
    my $node         = shift;
    my $coordination = shift;
    my $debug        = shift;

    # return $coordination;
    return 'not implemented';
}



# http://zil.ipipan.waw.pl/FunkcjeZaleznosciowe
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
my %deprel2afun = (# "arguments"
		   comp         => '',         # "complement" - adjectival/adverbial/nominal/prepositional; -> Atv/Adv/Atr/from_preposition
		   comp_fin     => ''          # "clausal complement"; -> Atv?/Adv/Atr/Obj?/Subj?
		   comp_inf     => ''          # "infinitival complement"; -> Adv/Atr/Obj?/Subj?
		   obj          => 'Obj',      # "object"
		   obj_th       => 'Obj',      # "dative object"
		   pd           => '',         # "predicative complement"; -> 'Pnom' if the parent is the verb "to be", otherwise 'Obj'
		   subj         => 'Sb',       # "subject"
		   # "non-arguments"
		   adjunct      => '',         # any modifier; -> Adv/Atr/...
		   app          => 'Apos'      # "apposition" ### second part depends on the first part (unlike in PDT, but same as in HamleDT (?))
		   complm       => 'AuxC'      # "complementizer" - introduces a complement clause (but is a child of its predicate, not a parent as in PDT)
		   mwe          => 'AuxY'      # "multi-word expression"
		   pred         => 'Pred'      # "predicate"
		   punct        => ''          # "punctuation marker"; -> AuxX/AuxG/AuxK
		   abbrev_punct => 'AuxG'      # "abbreviation mareker"
		   # "non-arguments (morphologicaly motivated)"
		   aglt         => 'AuxV'      # "mobile inflection" - verbal enclitic marked for number, person and gender
		   aux          => 'AuxV'      # "auxiliary"
		   cond         => 'AuxV'      # "conditional clitic"
		   imp          => 'AuxV'      # "imperative marker"
		   neg          => 'AuxZ'      # "negation marker"; ### AuxV
		   refl         => ''          # "reflexive marker"; -> AuxR/AuxT
		   # "coordination"
		   conjunct     => ''          # "coordinated conjunct"; is_member = 1, afun from the conjunction
		   coord        => 'Coord'     # "coordinating conjunction"
		   coord_punct  => ''          # "punctuation conjunction"; ->AuxX/AuxG
		   pre_coord    => 'AuxY'      # "pre-conjunction" - first, dependent part of a two-part correlative conjunction
		   # other
		   ne           => ''          # named entity
    )

sub deprel_to_afun {
    my $self   = shift;
    my $root   = shift;
    my @nodes  = $root->get_descendants();

    foreach my $node (@nodes) {
	my $deprel = $node->conll_deprel;
	my ($parent) = $node->get_eparents;

        # http://zil.ipipan.waw.pl/FunkcjeZaleznosciowe
        # The corpus contains the following dependency relation tags:

        #   23580 adjunct
        #   13495 comp
        #   12384 punct
        #    7613 pred
        #    5938 subj
        #    5010 conjunct
        #    4067 obj
        #    1708 refl
        #    1149 neg
        #    1108 comp_inf
        #    1067 comp_fin
        #     965 pd
        #     796 ne           # named entity
        #     665 obj_th
        #     657 complm
        #     645 aglt
        #     555 aux
        #     553 mwe
        #     514 coord_punct
        #     425 app
        #     280 coord
        #     190 abbrev_punct
        #     167 cond
        #      19 imp
        #      18 pre_coord
        #       2 interp       # lines 3312 and 5568; should be 'punct'
        #       1 ne_          # line 13573; should be 'ne'



	### TODO
	$node->afun = $deprel;
    }
}


### NOT FINISHED - WORK IN PROGRESS ###


1;
