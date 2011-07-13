package Treex::Block::A2T::CS::SetFormeme;
use Moose;
use Treex::Core::Common;
use Treex::Block::A2T::CS::SetFormeme::NodeInfo;

extends 'Treex::Core::Block';

has 'use_version' => ( is => 'ro', isa => enum( [ 1, 2 ] ), default => 1 );

has 'force_grammar' => ( is => 'ro', isa => 'Bool', default => 1 );

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # First, fill formeme of all t-layer nodes with a default value,
    # so tedious undef checking (||'') is no more needed.
    $t_node->set_formeme('???');

    # For complex type nodes (i.e. almost all except coordinations, rhematizers etc.)
    # fill in formemes
    if ( $t_node->nodetype eq 'complex' ) {
        if ( $self->use_version == 2 ) {
           
            my ($t_parent) = $t_node->get_eparents( { or_topological => 1 } );
                       
            my $parent = Treex::Block::A2T::CS::SetFormeme::NodeInfo->new( t => $t_parent );
            my $node = Treex::Block::A2T::CS::SetFormeme::NodeInfo->new( t => $t_node );            
            my $formeme = $self->detect_formeme2($node, $parent);
            
            if ($formeme){
                $t_node->set_formeme($formeme);
            }
        }
        else {
            detect_formeme($t_node);
        }
    }
    return;
}

sub detect_formeme2 {

    my ( $self, $node, $parent ) = @_;
    
    # start with the sempos
    my $formeme = $node->sempos;
    $formeme =~ s/\..*//;

    if ( !$node->a ) { # elided forms have a 'drop' formeme
        $formeme = 'drop';        
    }
    elsif ( $formeme eq 'n' ) {
        # possesive adjectives (compound prepositions also possible: 'v můj prospěch' etc.)
        if ( $node->tag =~ /^(AU|PS|P8)/ ) {
            $formeme = 'adj:' . ( $node->prep ? $node->prep . '+' : '' ) . 'poss';
        }
        # nominal congruent attribute
        elsif ( $self->_is_congruent_attrib( $node, $parent ) ) {
            $formeme = 'n:attr';
        }
        # prepositional or loose cases (numerals, too)
        elsif ( $node->case =~ /[1-7]/ ) {
            $formeme .= ':' . ($node->prep ? $node->prep . '+' : '') . $node->case;
        }
        # non-declined nouns, numerals etc. (infer case from preposition, if available)
        else {
            $formeme .= ($node->prep ? ':' . $node->prep . '+' . $node->prepcase : ':X');
        }
    }
    elsif ( $formeme eq 'adj' ) {

        # prepositional phrases with adjectives -- always work the same as substantives
        if ($node->prep) {
            $formeme = 'n:' . $node->prep . '+' . ( $node->case ? $node->case : $node->prepcase );
        }
        # adverbs derived from adjectives, weird form "rád"
        elsif ( $node->tag =~ /^(D|Cv|Co)/ or $node->t_lemma eq 'rád' ) {
            $formeme = 'adv';
        }
        # complement in nominative, directly dependent on a verb (-> adj:compl)
        elsif ( $parent->sempos eq 'v' and $node->case eq '1' ) {
            $formeme = 'adj:compl';
        }
        # other verbal complements work the same as substantives
        # TODO - problems: complements (COMPL, compl.rf), "mít co společného" (an error in Vallex, too - adj is not specified)
        # "hodně prodavaček je levých" (genitive!)
        elsif ( $parent->sempos eq 'v' ) {
            # short indeclinable adjectival forms "schopen", "připraven" etc.
            $formeme = 'n:1' if $node->tag =~ /^(AC|Vs)/;    
        }
        # attributive
        else {
            $formeme = 'adj:attr';
        }
    }
    elsif ( $formeme eq 'v' ) {
        my $finity = ( $node->tag =~ /^Vf/ and not grep { $_->tag =~ /^V[Bp]/ } @{ $node->aux } ) ? 'inf' : 'fin';
        $formeme .= $node->prep ? ':' . $node->prep . "+$finity" : ":$finity";
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
            and !$node->prep and $node->case =~ m/[1-7]/ and $node->case eq $parent->case ){

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
        if ( $node->case =~ m/[3-6]/ and ( $number_congruency or $parent->is_term_label ) ){
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


sub detect_formeme {
    my ($tnode) = @_;
    my $lex_a_node = $tnode->get_lex_anode() or return;
    my @aux_a_nodes = $tnode->get_aux_anodes( { ordered => 1 } );
    my $tag = $lex_a_node->tag;
    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
    my $sempos        = $tnode->gram_sempos   || '';
    my $parent_sempos = $tparent->gram_sempos || '';
    my $formeme;

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

Which version of Czech formemes should be used (1 or 2, defaults to 1).

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
