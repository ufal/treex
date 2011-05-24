package Treex::Block::A2T::CS::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


has use_version => ( is => 'ro', isa => enum([1, 2]), default => 1 );

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # First, fill formeme of all t-layer nodes with a default value,
    # so tedious undef checking (||'') is no more needed.
    $t_node->set_formeme('???');

    # For complex type nodes (i.e. almost all except coordinations, rhematizers etc.)
    # fill in formemes
    if ( $t_node->nodetype eq 'complex' ) {
        if ( $self->use_version == 2 ){
            detect_formeme2($t_node);
        }
        else {
            detect_formeme($t_node);
        }
    }
    return;
}

sub detect_formeme2 {

    my ($t_node) = @_;
    my $sempos = $t_node->gram_sempos || '';
    my $lex_a_node = $t_node->get_lex_anode();
    my $tag = $lex_a_node ? $lex_a_node->tag : '';
    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    
    my ($t_parent) = $t_node->get_eparents( { or_topological => 1 } );
    my $parent_sempos = $t_parent ? $t_parent->gram_sempos : '';
    $parent_sempos = '' if !$parent_sempos;
    my $parent_lex_a_node = $t_parent->get_lex_anode();

    # start with the sempos
    my $formeme = $sempos;
    $formeme =~ s/\..*//;

    my ($prep, $prep_case) = _detect_prep($t_node, $lex_a_node, \@aux_a_nodes);
    
    if ( $tag eq '' ) {    # elided forms have a 'drop' formeme
        $formeme = 'drop';
    }
    elsif ( $formeme eq 'n' ) {
        # possesive adjectives
        if ( $tag =~ /^(AU|PS|P8)/ ) {     
            $formeme = 'adj:poss';
        }
        # prepended nominal congruent attribute
        elsif ( $lex_a_node and $parent_lex_a_node and $lex_a_node->parent->id eq $parent_lex_a_node->id
                and $parent_sempos =~ /^n/ and $lex_a_node->ord < $parent_lex_a_node->ord ){ 
            $formeme = 'n:attr';                
        }
        # prepositional cases (numerals, too)
        elsif ( $tag =~ /^[NAPC]...(\d)/ ) {    
            my $case = $1;
            $formeme .= $prep ? ":$prep+$case" : ":$case";
        }
        # non-declined nouns, numerals etc. (infer case from preposition, if available)        
        else {
            $prep_case = 'X' if !$prep_case;                                             
            $formeme .= $prep ? ":$prep+$prep_case" : ':X';
        }
    }
    elsif ( $formeme eq 'adj' ) {

        if ($prep) {
            $formeme .= ":$prep+X";
        }
        # adverbs derived from adjectives        
        elsif ( $tag =~ /^R/ ) { 
            $formeme = 'adv';
        }
        # predicative
        elsif ( $t_parent->t_lemma =~ /^(#EmpVerb|být)$/ and $t_node->functor eq 'PAT' ) {
            $formeme = 'adj:pred';
        }
        # attributive
        else {                                                                               
            $formeme = 'adj:attr';
        }
    }
    elsif ( $formeme eq 'v' ) {                                                              
        my $finity = ( $tag =~ /^Vf/ and not grep { $_->tag =~ /^V[Bp]/ } @aux_a_nodes ) ? 'inf' : 'fin';
        $formeme .= $prep ? ":$prep+$finity" : ":$finity";
    }
    # adverbs: just one formeme 'adv', since prepositions in their aux.rf occur only in case of some weird coordination 

    if ($formeme) {
        $t_node->set_formeme($formeme);
    }
    return;
}


# Detects preposition + governed case / subjunction
sub _detect_prep {

    my $t_node = shift;
    my $lex_a_node = shift; 
    my @aux_a_nodes = @{ shift() }; 

    # filter out auxiliary / modal verbs and everything what's already contained in the lemma
    my @prep_nodes = grep {
        my $lemma = $_->lemma;
        $lemma =~ s/(-|`|_;|_:|_;|_,|_\^).*$//;
        $lemma = $_->form if $lemma eq 'se'; # way to filter out reflexives 
        $_->tag !~ /^V/ and $t_node->t_lemma !~ /(^|_)$lemma(_|$)/
    } @aux_a_nodes;

    if (@prep_nodes) {

        # find out the governed case; default for nominal and adverb constructions: genitive 
        my $gov_prep = -1;
        while ( $gov_prep < @prep_nodes-1 and (!$lex_a_node or $prep_nodes[$gov_prep+1]->ord < $lex_a_node->ord) ){
            $gov_prep++;
        }
        my $gov_case = $prep_nodes[$gov_prep]->tag =~ m/^R...(\d)/ ? $1 : '';
        $gov_case = (!$gov_case and $prep_nodes[$gov_prep]->tag =~ m/^[ND]/) ? 2 : $gov_case; 

        # gather the preposition lemmas 
        my @prep_lemmas = map { my $lemma = $_->lemma; $lemma =~ s/(-|`|_;|_:|_;|_,|_\^).*$//; $lemma } @prep_nodes;

        return ( join( '_', @prep_lemmas ), $gov_case);
    }
    return ( '', '' );
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


=TODO

Test, unify versions.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
