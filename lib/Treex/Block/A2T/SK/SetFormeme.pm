package Treex::Block::A2T::SK::SetFormeme;
use Moose;
use Treex::Core::Common;
use Treex::Block::A2T::CS::SetFormeme::NodeInfo;
use Treex::Tool::Lexicon::CS::AdjectivalComplements;

extends 'Treex::Core::Block';

has 'fix_prep' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'fix_numer' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'detect_diathesis' => ( is => 'ro', isa => 'Bool', default => 0 );

# Caching of NodeInfos for better speed (they might get called more times)
has '_node_info_cache' => ( is => 'rw', isa => 'HashRef' );

sub process_ttree {

    my ( $self, $t_root ) = @_;

    # Clear NodeInfo cache for each tree
    $self->_set_node_info_cache( {} );

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

    # Percnt, Deg are qcomplex but should get a formeme, too
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

    return;
}

# Caching of NodeInfos for better speed -- retrieves from cache if available
sub _get_node_info {

    my ( $self, $t_node ) = @_;

    if ( !$self->_node_info_cache->{$t_node->id} ){
        
        my ($anode) = $t_node->get_lex_anode();
        my ($tag, $lemma, $snk_tag) = ($anode ? $anode->tag : '', $anode ? $anode->lemma : '', $anode ? $anode->wild->{snk_tag} : '');

        $self->_node_info_cache->{$t_node->id} = Treex::Block::A2T::CS::SetFormeme::NodeInfo->new( {
            t => $t_node,
            fix_numer => $self->fix_numer,
            fix_prep => $self->fix_prep,
            syntpos => $self->detect_syntpos($t_node, $tag, $lemma, $snk_tag ), # overriding Czech-specific syntpos
            } );
    }
    return $self->_node_info_cache->{ $t_node->id };
}

sub _detect_formeme2 {

    my ( $self, $node, $parent ) = @_;

    # start with syntpos
    my $formeme = $node->syntpos;
    
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
        if ( $node->tag =~ /^(AU|P[S18])/
                or $node->a->wild->{snk_tag} =~ /^AF/ 
                or $node->lemma =~ /^(môj|tvôj|jeho|svoj|jej|náš|váš|ich)$/ ) {
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
            $formeme = 'n:' . ( $node->case || 'X' );
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
    if ( $node->syntpos eq 'n' and $parent->syntpos eq 'n'
            and not $node->prep and $node->case =~ m/[1-7]/ and $node->case eq $parent->case ){

        # two names are usually congruent - "Frýdku Místku" etc.
        if ( $parent->ne_type and $node->ne_type ){

            # nominative: congruency ("Josef Čapek"), or nominative ID ("Sparta Praha") ? 
            if ( $node->case eq '1' ){

                return 0 if ( $node->lemma eq $parent->lemma ); # Firma XY Ostrava a.s., Pivovarská 1, 729 38 Ostrava 1
                
                my $term_types = $node->ne_type . '-' . $parent->ne_type;

                # op+op: "Opel Astra", g_+g_: "Frýdek Místek", "Praha Motol", pc+p[fs]: "Američan Smith", "Američan John"
                # i.+i.: "Renault-Wiliams" 
                # pf+anything: "Jan Slovák", "Pavel Anděl", "Josef Čapek", "Garrigue Masaryk", "Ježíš Kristus" 
                # (+ actually errors): "Jozef Bednárik", ps+i_ "John Bovett", i_+ps_ "Tina Turner", ps+pf "Naděžda Blažíčková"
                return $term_types =~ m/^(op-op|g.-g.|pc-p[fms]|ps-(p[fs]|i.)|pf-.*|[pi].-p[s_]|i.-i.)$/;
            }

            # other cases are clear
            return 1;
        }
        # otherwise, check for morphological congruency or named entity types
        return $self->_check_congruency( $node, $parent );
    }
    return 0;
}

# Checking congruency of a parent and child node -- more strict for nominative, genitive and instrumental 
# (gender congruency and >= 1 named entity required),
# allows for number incongurencies in coordinations and gender incongruencies in masc. animate names 
sub _check_congruency {

    my ( $self, $node, $parent ) = @_;

    return 0 if ( $parent->is_term_label eq 'incon' );
    return 1 if ( $parent->is_term_label eq 'congr' || $node->is_term_label eq 'congr' );

    # require that one of the two be a name in nominative, genitive and instrumental    
    return 0 if ( $node->case =~ m/[127]/ && !$node->ne_type && !$parent->ne_type );
    # rule out geography
    return 0 if ( $node->case =~ m/[127]/ && $node->ne_type =~ /^g/ && !$parent->is_geo_congr_label );   

    my $gender_congruency = ( substr( $node->tag, 2, 1 ) eq substr( $parent->tag, 2, 1 ) );
    my $number_congruency = ( substr( $node->tag, 3, 1 ) eq substr( $parent->tag, 3, 1 ) );
    
    # allow number incongruency for coordinations
    $number_congruency |= ( substr( $parent->tag, 3, 1 ) eq 'P' ) if ( $node->a->is_member );
    $number_congruency |= ( substr( $node->tag, 3, 1 ) eq 'P' ) if ( $parent->a->is_member );
    
    # allow gender incongruency for masculine animate + names, e. g. 'ředitel Sádlo', 'ministr Hora'
    $gender_congruency |= ( substr( $parent->tag, 2, 1  ) eq 'M' ) if ( $node->ne_type =~ /^p/ );
    $gender_congruency |= ( substr( $node->tag, 2, 1  ) eq 'M' ) if ( $parent->ne_type =~ /^p/ ); 

    # relax gender congruency in dative, accusative, vocative and locative
    $gender_congruency |= ( $node->case =~ m/[3-6]/ );       

    return ( $number_congruency && $gender_congruency ); 
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
    return 1 if ( $parent->case eq '1' and $parent->ne_type );
    # default    
    return 0;
}




# Copied from NodeInfo.pm and edited to resemble the old formeme system a little bit more
# (possesives moved to nouns)
sub detect_syntpos {
    my ($self, $tnode, $tag, $lemma, $snk_tag) = @_;

    # skip technical root, conjunctions, prepositions, punctuation etc.
    return '' if ( $tnode->is_root or $tag =~ m/^.[%#^,FRVXc:]/ );

    # adjectives, adjectival numerals and pronouns
    return 'adj' if ( $tag =~ m/^.[\}=\?4ACDGLOadhklnrwyz]/ );
    return 'adj' if ( ( $snk_tag // '' ) =~ /^AF/ );
    return 'adj' if ( $lemma =~ m/(môj|tvôj|jeho|svoj|jej|náš|váš|ich)$/ );

    # indefinite and negative pronous cannot be disambiguated simply based on POS (some of them are nouns)
    return 'adj' if ( $tag =~ m/^.[WZ]/ and $lemma =~ m/(žiadny|čí|aký|ktorý|koľvek)$/ );

    # adverbs, adverbial numerals ("dvakrát" etc.),
    # including interjections and particles (they behave the same if they're full nodes on t-layer)
    return 'adv' if ( $tag =~ m/^.[\*bgouvTI]/ );

    # verbs
    return 'v' if ( $tag =~ m/^V/ );

    # everything else are nouns: POS -- 56789EHPNJQYj@SXU, no POS (possibly -- generated nodes)
    return 'n';
}



1;
