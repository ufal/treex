package Treex::Block::A2A::SV::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Swedish tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);

    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
    #$self->lift_noun_phrases($a_root);
    $self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
    #$self->check_afuns($a_root);
    $self->deprel_to_afun($a_root); # must follow coord. restructuring, probably executed twice now
}


my %pos2afun = (
    prep => 'AuxP',
);


#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://stp.ling.uu.se/~nivre/research/Talbanken05.html
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();
    my $sp_counter = 0;
    foreach my $node (@nodes)
    {

        # The corpus contains the following 64 dependency relation tags:
        # ++ +A +F AA AG AN AT BS C+ CA CC CJ DB DT EF EO ES ET FO FS FV HD I?
        # IC IG IK IM IO IP IQ IR IS IT IU IV JC JG JR JT KA MA MD MS NA OA OO
        # PA PL PT RA ROOT  SP SS ST TA UK VA VG VO VS XA XF XT XX
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
        my $ppos   = $parent->get_iset('pos');
        my $afun;

        # Dependency of the main verb on the artificial root node.
        if ( $deprel eq 'ROOT' )
        {
            if ( $pos eq 'verb' )
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }

        # Coordinating conjunction
        elsif ( $deprel eq '++' )
        {
            $afun = 'Coord';
        }

        # Conjunctional adverbial
        elsif ( $deprel eq '+A' )
        {
            $afun = 'Adv';
        }

        # Coordination at main clause level
        elsif ( $deprel eq '+F' )
        {
        }

        # Other adverbial
        elsif ( $deprel eq 'AA' )
        {
            $afun = 'Adv';
        }

        # Agent
        elsif ( $deprel eq 'AG' )
        {
        }

        # Apposition
        elsif ( $deprel eq 'AN' )
        {
        }

        # Nominal (adjectival) pre-modifier
        elsif ( $deprel eq 'AT' )
        {
            $afun = 'Atr';
        }

        # Contrastive adverbial
        elsif ( $deprel eq 'CA' )
        {
            $afun = 'Adv';
        }

        # Doubled function
        elsif ( $deprel eq 'DB' )
        {
        }

        # Determiner
        elsif ( $deprel eq 'DT' )
        {
            $afun = 'AuxA';
        }

        # Relative clause in cleft
        elsif ( $deprel eq 'EF' )
        {
        }

        # Logical object
        elsif ( $deprel eq 'EO' )
        {
        }

        # Logical subject
        elsif ( $deprel eq 'ES' )
        {
        }

        # Other nominal post-modifier
        elsif ( $deprel eq 'ET' )
        {
            $afun = 'Atr';
        }

        # Dummy object
        elsif ( $deprel eq 'FO' )
        {
        }

        # Dummy subject
        elsif ( $deprel eq 'FS' )
        {
            $afun = 'Sb';
        }

        # Finite predicate verb
        elsif ( $deprel eq 'FV' )
        {
        }

        # Question mark
        elsif ( $deprel eq 'I?' )
        {
        }

        # Quotation mark
        elsif ( $deprel eq 'IC' )
        {
        }

        # Part of idiom (multi-word unit)
        elsif ( $deprel eq 'ID' )
        {
        }

        # Other punctuation mark
        elsif ( $deprel eq 'IG' )
        {
        }

        # Comma
        elsif ( $deprel eq 'IK' )
        {
            $afun = 'AuxX';
        }

        # Infinitive marker
        elsif ( $deprel eq 'IM' )
        {
            $afun = 'AuxV';
        }

        # Indirect object
        elsif ( $deprel eq 'IO' )
        {
            $afun = 'Obj';
        }

        # Period
        elsif ( $deprel eq 'IP' )
        {
            $afun = 'AuxK'; # approx.
        }

        # Colon
        elsif ( $deprel eq 'IQ' )
        {
        }

        # Parenthesis
        elsif ( $deprel eq 'IR' )
        {
        }

        # Semicolon
        elsif ( $deprel eq 'IS' )
        {
        }

        # Dash
        elsif ( $deprel eq 'IT' )
        {
        }

        # Exclamation mark
        elsif ( $deprel eq 'IU' )
        {
            $afun = 'AuxK';
        }

        # Nonfinite verb
        elsif ( $deprel eq 'IV' )
        {
        }

        # Second quotation mark
        elsif ( $deprel eq 'JC' )
        {
        }

        # Second (other) punctuation mark
        elsif ( $deprel eq 'JG' )
        {
        }

        # Second parenthesis
        elsif ( $deprel eq 'JR' )
        {
        }

        # Second dash
        elsif ( $deprel eq 'JT' )
        {
        }

        # Comparative adverbial
        elsif ( $deprel eq 'KA' )
        {
            $afun = 'Adv';
        }

        # Attitude adverbial
        elsif ( $deprel eq 'MA' )
        {
            $afun = 'Adv';
        }

        # Macrosyntagm
        elsif ( $deprel eq 'MS' )
        {
        }

        # Negation adverbial
        elsif ( $deprel eq 'NA' )
        {
            $afun = 'Adv';
        }

        # Object adverbial
        elsif ( $deprel eq 'OA' )
        {
        }

        # Other object
        elsif ( $deprel eq 'OO' )
        {
            $afun = 'Obj';
        }

        # Verb particle
        elsif ( $deprel eq 'PL' )
        {
            $afun = 'AuxV';
        }

        # Preposition
        elsif ( $deprel eq 'PR' )
        {
            $afun = 'AuxP';
        }

        # Predicative attribute
        elsif ( $deprel eq 'PT' )
        {
        }

        # Place adverbial
        elsif ( $deprel eq 'RA' )
        {
            $afun = 'Adv';
        }

        # Subjective predicative complement
        elsif ( $deprel eq 'SP' )
        {
            $afun = 'Atv';
        }

        # Other subject
        elsif ( $deprel eq 'SS' )
        {
            $afun = 'Sb';
        }

        # Paragraph
        elsif ( $deprel eq 'ST' )
        {
        }

        # Time adverbial
        elsif ( $deprel eq 'TA' )
        {
            $afun = 'Adv';
        }

        # Subordinating conjunction
        elsif ( $deprel eq 'UK' )
        {
            $afun = 'AuxC';
        }

        # Varslande adverbial
        elsif ( $deprel eq 'VA' )
        {
            $afun = 'Adv';
        }

        # Infinitive object complement
        elsif ( $deprel eq 'VO' )
        {
        }

        # Infinitive subject complement
        elsif ( $deprel eq 'VS' )
        {
        }

        # Expressions like "så att säga" (so to speak)
        elsif ( $deprel eq 'XA' )
        {
        }

        # Fundament phrase
        elsif ( $deprel eq 'XF' )
        {
        }

        # Expressions like "så kallad" (so called)
        elsif ( $deprel eq 'XT' )
        {
        }

        # Unclassifiable grammatical function
        elsif ( $deprel eq 'XX' )
        {
        }

        # Interjection phrase
        elsif ( $deprel eq 'YY' )
        {
        }

        # Conjunct
        # First conjunct in binary branching analysis of coordination
        elsif ( $deprel eq 'CJ' )
        {
        }

        # Other head
        elsif ( $deprel eq 'HD' )
        {
        }

        # Subordinate clause minus subordinating conjunction
        elsif ( $deprel eq 'BS' )
        {
            $afun = 'Adv';
        }

        # Second conjunct (sister of conjunction) in binary branching analysis
        elsif ( $deprel eq 'C+' )
        {
        }

        # Sister of first conjunct in binary branching analysis of coordination
        elsif ( $deprel eq 'CC' )
        {
        }

        # Infinitive phrase minus infinitive marker
        elsif ( $deprel eq 'IF' )
        {
        }

        # Complement of preposition
        elsif ( $deprel eq 'PA' )
        {
            $afun = 'Adv';
        }

        # Verb group
        elsif ( $deprel eq 'VG' )
        {
            $afun = 'Atv';
        }

        $afun = $afun || $pos2afun{$pos} || 'NR';
        $node->set_afun($afun);
    }
}


sub restructure_coordination {
    my ($self, $root) = @_;

    foreach my $last_member (grep {$_->conll_deprel =~ /^(CC|\+F)/ and
                                       not grep {$_->conll_deprel =~ /^(CC|\+F)/} $_->get_children}
                                 map {$_->get_descendants} $root->get_children) {

        my ($coord_root) = (grep {$_->conll_deprel eq '++'} $last_member->get_children,
                            grep {$_->conll_deprel eq 'IK'} $last_member->get_children);

        if ($coord_root) {

            # climbing up to collect coordination members
            my @members = ( $last_member );
            my $node = $last_member;
            while ( $node->conll_deprel =~ /^(CC|\+F)/ ) {
                $node = $node->get_parent;
                push @members, $node;
            }

            # TODO: rehanging commas in multiple coordinations

            $coord_root->set_parent($members[-1]->get_parent);
            $coord_root->set_afun('Coord');

            foreach my $member (@members) {
                $member->set_parent($coord_root);
                $member->set_is_member(1);
                $member->set_conll_deprel($members[-1]->conll_deprel);
            }
        }
    }
}


1;

=over

=item Treex::Block::A2A::SV::CoNLL2PDTStyle

Converts trees coming from the Swedish Mamba Treebank via the CoNLL-X format to the style of
the Prague Dependency Treebank. Converts tags and restructures the tree.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
