package Treex::Block::A2T::CS::SetFormeme;
use Moose;
use Treex::Core::Common;
use Treex::Block::A2T::CS::SetFormeme::NodeInfo;
use Treex::Tool::Lexicon::CS::AdjectivalComplements;

extends 'Treex::Core::Block';

# 1 = original version, 1a = original with syntpos instead of sempos, 2 = modified
has 'use_version' => ( is => 'ro', isa => enum( [ '1', '1a', '2' ] ), default => '1' );

has 'fix_prep' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'fix_numer' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'detect_diathesis' => ( is => 'ro', isa => 'Bool', default => 0 );

# Caching of NodeInfos for better speed (they might get called more times)
has '_node_info_cache' => ( is => 'rw', isa => 'HashRef' );

sub process_ttree {

    my ( $self, $t_root ) = @_;

    # Clear NodeInfo cache for each tree
    if ( $self->use_version eq '2' ) {
        $self->_set_node_info_cache( {} );
    }
    foreach my $t_node ( $t_root->get_descendants() ) {
        $self->process_tnode($t_node);
    }
    return;
}

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # First, fill formeme of all t-layer nodes with a default value,
    # so tedious undef checking (||'') is no more needed.
    $t_node->set_formeme('???');

    # For complex type nodes (i.e. almost all except coordinations, rhematizers etc.)
    # fill in formemes
    if ( $self->use_version eq '2' ) {

        if ( $t_node->nodetype eq 'complex' || $t_node->t_lemma =~ /^(%|°|#(Percnt|Deg))/ ) {
            
            my ($t_parent) = $t_node->get_eparents( { or_topological => 1 } );
    
            my $parent = $self->_get_node_info( $t_parent );
            my $node =  $self->_get_node_info( $t_node );
            my $formeme = $self->_detect_formeme2($node, $parent);
    
            if ($formeme){
                $t_node->set_formeme($formeme);
            }
        }
        else {
            $t_node->set_formeme('x');
        }
    }
    elsif ( $t_node->nodetype eq 'complex' ){
        detect_formeme($t_node, $self->use_version eq '1');
    }
    return;
}

# Caching of NodeInfos for better speed -- retrieves from cache if available
sub _get_node_info {

    my ( $self, $t_node ) = @_;

    if ( !$self->_node_info_cache->{$t_node->id} ){

        $self->_node_info_cache->{$t_node->id} = Treex::Block::A2T::CS::SetFormeme::NodeInfo->new( {
            t => $t_node,
            fix_numer => $self->fix_numer,
            fix_prep => $self->fix_prep,
            } );
    }
    return $self->_node_info_cache->{ $t_node->id };
}

sub _detect_formeme2 {

    my ( $self, $node, $parent ) = @_;

    # start with the sempos
    my $formeme = $node->syntpos;
    $formeme =~ s/\..*//;
    
    if ( !$node->a ) { # elided forms have a 'drop' formeme
        $formeme = 'drop';
    }
    elsif ( $formeme eq 'n' ) {

        # nominal congruent attribute
        if ( $self->_is_congruent_attrib( $node, $parent ) ) {
            $formeme = 'n:attr';
        }

        # prepositional or loose cases (numerals, too)
        else {
            $formeme .= ':' . ( $node->prep ? $node->prep . '+' : '' ) . $node->case;
        }
    }
    elsif ( $formeme eq 'adj' ) {
        # possesive adjectives (compound prepositions also possible: 'v můj prospěch' etc.)
        if ( $node->tag =~ /^(AU|PS|P8)/ ) {
            $formeme = 'adj:' . ( $node->prep ? $node->prep . '+' : '' ) . 'poss';
        }        
        # prepositional phrases with adjectives -- always work the same as substantives
        elsif ($node->prep) {
            $formeme = 'n:' . $node->prep . '+' . $node->case;
        }
        # adverbs derived from adjectives # TODO -- this shouldn't be needed if we're dealing with syntpos only
        elsif ( $node->tag =~ /^(D|Cv|Co)/ ) {
            $formeme = 'adv';
        }
        # adjectives hanging directly under the root -- nominal usage
        elsif ( $parent->t->is_root ){
            $formeme = 'n:' . $node->case;
        }
        # distinguish verbal complements (selected verbs which require adjectives only) and adjectives in substantival position 
        # TODO -- fix "hodně prodavaček je levých" (genitive!)
        elsif ( $parent->syntpos eq 'v' ) {
            # verbal complements (required by valency) -- exclude subjects, demonstrative and relative pronouns
            if ( $node->tag !~ /^P[D4]/ and $node->afun ne 'Sb' 
                    and Treex::Tool::Lexicon::CS::AdjectivalComplements::requires( $parent->t_lemma, $node->case ) ){
                $formeme = 'adj:' . $node->case;
            }
            # complement (verbal attribute) -- only adjectives can be there
            elsif ( $node->afun =~ /^Atv/ || $node->tag =~ /^(AC|AO|Vs)/ ){
                # most complements are not declinable -> pretend them to be nominative (they mostly refer to the subject)
                $formeme = 'adj:' . ( $node->case || 1 );
            }
            # normal case: nominal
            else {
                $formeme = 'n:' . ( $node->case || 'X' );
            }
        }
        # numerals in a non-attributive position (the ones hanging under verbs have been treated as verbal complements)
        # TODO test if giving 'n:1' to non-declinable numerals is any good
        elsif ( $self->_is_nonattributive_numeral( $node, $parent ) ){                    
            $formeme = 'n:' . $node->case;
            $formeme = 'n:1' if ( ( not $node->case ) or ( $node->case eq 'X' ) ); # non-declinable numerals
        }

        # attributive
        else {
            $formeme = 'adj:attr';
        }
    }
    elsif ( $formeme eq 'v' ) {
        $formeme .=  ':' . ( $node->prep ? $node->prep . '+' : '' ) . $node->verbform;
    }

    # adverbs: just one formeme 'adv', since prepositions in their aux.rf occur only in case of some weird coordination,
    # or for adverbial numerals 'u více než 20 lidí' etc. (which gets 'n:u+2')

    return $formeme;
}

# Detects if the given noun is a congruent attribute
sub _is_congruent_attrib {

    my ( $self, $node, $parent ) = @_;

    # Both must be normal nouns + congruent in case (and declinable, i.e. no abbreviations), 
    # there mustn't be a preposition between them 
    if ( $node->sempos =~ m/^n\.denot/ and $parent->sempos =~ m/^n\.denot/
            and not $node->prep and $node->case =~ m/[1-7]/ and $node->case eq $parent->case ){

        # two names are usually congruent - "Frýdku Místku" etc.
        if ( $parent->is_name_lemma and $node->is_name_lemma ){

            # nominative: congruency ("Josef Čapek"), or nominative ID ("Sparta Praha") ? 
            if ( $node->case eq '1' ){

                my $term_types = $node->term_types . '+' . $parent->term_types;

                # R+R: "Opel Astra", G+G: "Frýdek Místek", "Praha Motol", Y+E: "Jan Slovák", E+S: "Američan Smith"
                # E+Y: "Američan John", Y+S: "Josef Čapek", Y+Y: "Ježíš Kristus", S+S: "Garrigue Masaryk"
                # (+ actually errors): Y+G: "Jozef Bednárik", S+K: "John Bovett", K+S: "Tina Turner"
                return $term_types =~ m/^(.*R.*\+.*R.*|.*G.*\+.*G.*|.*E.*\+.*[YS].*|.*S.*\+.*[SK].*|.*Y.*\+.*[GEYS].*|.*K.*\+.*S.*)$/;
            }

            # other cases are clear
            return 1;
        }

        my $gender_congruency = ( substr( $node->tag, 2, 1 ) eq substr( $parent->tag, 2, 1 ) );
        my $number_congruency = ( substr( $node->tag, 3, 1 ) eq substr( $parent->tag, 3, 1 ) );

        # check for congruency in number for dative, accusative, vocative and locative (except the labels)
        if ( $node->case =~ m/[3-6]/ and ( $number_congruency or $parent->is_term_label ) ) {
            return 1;
        }

        # for genitive and instrumental, check for congruency in number and gender (except the labels)
        # + at least one of the two must be a name
        elsif ( $node->{case} =~ m/[27]/ and ( $node->is_name_lemma or $parent->is_name_lemma)
                and ( ( $gender_congruency and $number_congruency ) or ( $parent->is_term_label ) ) ){
            return 1;
        }
        return 0;
    }
    return 0;
}

sub _is_nonattributive_numeral {
    
    my ( $self, $node, $parent ) = @_;
    
    # this is not a number that may be non-attributive -- return immediately    
    return 0 if ( $node->tag !~ m/^C[\}=clny]/ );
    # 'jeden' can behave as an ordinal numeral -- rule it out even in post-position if it's case-congruent with the parent
    return 0 if ( ( $node->lemma eq 'jeden' and $parent->case eq $node->case ) );     
    # "článek 3", "3)" - alone-standing numbers
    return 1 if ( ( $parent->a and $node->a->ord > $parent->a->ord ) or ( $parent->syntpos eq '' ) );    
    # 412 01 Litoměřice
    return 1 if ( $parent->case eq '1' and $parent->is_name_lemma );
    # default    
    return 0;
}


sub detect_formeme {
    my ($tnode, $use_syntpos) = @_;
    my $lex_a_node = $tnode->get_lex_anode() or return;
    my @aux_a_nodes = $tnode->get_aux_anodes( { ordered => 1 } );
    my $tag = $lex_a_node->tag;
    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
    my $parent_lex_a_node = $tparent->get_lex_anode();
    my ($sempos, $parent_sempos);
    my $formeme;
    
    # modification (v 1a) - using syntpos instead of sempos
    if ($use_syntpos){
        $sempos = detect_syntpos( $tnode, $tag, $lex_a_node->lemma );
        $parent_sempos = detect_syntpos( $tparent, $parent_lex_a_node ? $parent_lex_a_node->tag : '', 
                $parent_lex_a_node ? $parent_lex_a_node->lemma : '' );
    }
    # original formemes - using sempos
    else {
        $sempos        = $tnode->gram_sempos   || '';
        $parent_sempos = $tparent->gram_sempos || '';        
    }

    # semantic nouns
    if ( $sempos =~ /^n/ ) {
        if ( $tag =~ /^(AU|PS|P8)/ ) {
            $formeme = 'n:poss';
        }
        elsif ( $tag =~ /^[NAP]...(\d)/ ) {
            my $case = $1;
            my $prep = join '_',
                map { my $preplemma = $_->lemma; $preplemma =~ s/\-.+//; $preplemma }
                grep { $_->tag =~ /^R/ or $_->afun =~ /^Aux[PC]/ or $_->lemma eq 'jako' } @aux_a_nodes;
            if ( $prep ne '' ) {
                $formeme = "n:$prep+$case";
            }
            elsif ( $parent_sempos =~ /^n/ and $tparent->ord > $tnode->ord ) {
                $formeme = 'n:attr';
            }
            else {
                $formeme = "n:$case";
            }
        }
        else {
            $formeme = 'n:???';
        }
    }

    # semantic adjectives
    elsif ( $sempos =~ /^adj/ ) {
        my $prep = join '_',
            map { my $preplemma = $_->lemma; $preplemma =~ s/\-.+//; $preplemma }
            grep { $_->tag =~ /^R/ or $_->afun =~ /^AuxP/ } @aux_a_nodes;
        if ( $prep ne '' ) {
            $formeme = "adj:$prep+X";
        }
        elsif ( $parent_sempos =~ /v/ ) {
            $formeme = 'adj:compl';
        }
        else {
            $formeme = 'adj:attr';
        }
    }

    # semantic adverbs
    elsif ( $sempos =~ /^adv/ ) {
        $formeme = 'adv:';
    }

    # semantic verbs
    elsif ( $sempos =~ /^v/ ) {
        if ( $tag =~ /^Vf/ and not grep { $_->tag =~ /^V[Bp]/ } @aux_a_nodes ) {
            $formeme = 'v:inf';
        }
        else {
            my $subconj = join '_',
                map { my $subconjlemma = $_->lemma; $subconjlemma =~ s/\-.+//; $subconjlemma }
                grep { $_->tag =~ /^J,/ or $_->form eq "li" } @aux_a_nodes;

            if ( $tnode->is_relclause_head ) {
                $formeme = 'v:rc';
            }
            elsif ( $subconj ne '' ) {
                $formeme = "v:$subconj+fin";
            }
            else {
                $formeme = 'v:fin';
            }
        }
    }

    if ($formeme) {
        $tnode->set_formeme($formeme);
    }
    return;
}


# Copied from NodeInfo.pm and edited to resemble the old formeme system a little bit more
# (possesives moved to nouns)
sub detect_syntpos {
    my ($tnode, $tag, $lemma) = @_;

    # skip technical root, conjunctions, prepositions, punctuation etc.
    return '' if ( $tnode->is_root or $tag =~ m/^.[%#^,FRVXc:]/ );

    # adjectives, adjectival numerals and pronouns
    return 'adj' if ( $tag =~ m/^.[\}=\?4ACDGLOadhklnrwyz]/ );

    # indefinite and negative pronous cannot be disambiguated simply based on POS (some of them are nouns)
    return 'adj' if ( $tag =~ m/^.[WZ]/ and $lemma =~ m/(žádný|čí|aký|který|[íý]koli|[ýí]si|ýs)$/ );

    # adverbs, adverbial numerals ("dvakrát" etc.),
    # including interjections and particles (they behave the same if they're full nodes on t-layer)
    return 'adv' if ( $tag =~ m/^.[\*bgouvTI]/ );

    # verbs
    return 'v' if ( $tag =~ m/^V/ );

    # everything else are nouns: POS -- 56789EHPNJQYj@SXU, no POS (possibly -- generated nodes)
    return 'n';
}



1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::SetFormeme

=head1 DESCRIPTION

The attribute C<formeme> of Czech t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:pro+X> (prepositional group), or C<n:1> are used.

=head1 PARAMETERS

=over

=item C<use_version>

Which version of Czech formemes should be used (1, 1a or 2, defaults to 1).

Version 1 is the original formemes using sempos, version 1a is a slight modification of the original using 
syntpos instead of sempos, version 2 is a more or less completely rewritten variant with a different behavior.

=back

=TODO

Test, unify versions.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
