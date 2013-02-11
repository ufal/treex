package Treex::Block::T2A::CS::MoveCliticsToWackernagel;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $aroot ) = @_;

    # Divide nodes into clauses
    my @clauses;
    foreach my $anode ( $aroot->get_descendants( { ordered => 1 } ) ) {
        my $clause_number = $anode->clause_number or next;
        if ( !$clauses[$clause_number] ) { $clauses[$clause_number] = [$anode]; }
        else                             { push @{ $clauses[$clause_number] }, $anode; }
    }

    # Process each clause
    foreach my $number ( 1 .. $#clauses ) {
        if ( $clauses[$number] ) {
            process_clause( @{ $clauses[$number] } )
        }
    }
    return;
}

sub process_clause {
    my @nodes = @_;

    # 1) Find and sort clitics in the clause
    my @clitics = sort { _order($b) <=> _order($a) } grep { _is_clitic($_) } @nodes;
    return if !@clitics;

    # 2) Handle special cases when clitics should not be moved. E.g.:
    # "Vláda je může snížit."        Word "je"" is a clitics and it is moved.
    # *"Vláda je je ochotna snížit." Two adjacent "je" (clitic & verb to be) are incorrect.
    # "Vláda je ochotna je snížit."  This is the correct Czech word order.
    my $clause_root = $nodes[0]->get_clause_root();
    if ( _is_verb_je($clause_root) ) {
        @clitics = grep { !_is_pronoun_je($_) || _move_je($_) } @clitics;
    }

    @clitics = grep { _verb_group_root($_) eq $clause_root } @clitics;

    #    foreach my $clitic (@clitics) {
    #	if (_verb_group_root($clitic) ne $clause_root) {
    #	    print "QQQ Not moving '".$clitic->form
    #		."' from below '".$clitic->get_parent->form
    #		." (real clause root '".$clause_root->form
    #		." but returned'". _verb_group_root($clitic)->form."')\t"
    #		.$clitic->get_bundle->get_attr('czech_target_sentence')."\n";
    #	}
    #    }

    # 3) Find the word (called $first) before Wackernagel's position, beware of coordinated/ing conjunction taking the 1st pos
    my $coord = _is_coord_taking_1st_pos( $clause_root );
    my $first;

    if ( !$coord ){
        $first = _find_eo1st_pos( $clause_root, $nodes[0] );    
    }
    
    # 4) Shift all clitics
    # 4a) at the beginning of the clause if the coordinated subjunction/coordinating conjunction fills the 1st position
    if ( $coord ){
        foreach my $clitic (@clitics) { $clitic->shift_before_subtree( $clause_root, { without_children => 1 } ); }
    }
    # 4b) after the word $first if it is the clause root
    elsif ( $first == $clause_root ) {
        foreach my $clitic (@clitics) { $clitic->shift_after_node( $first, { without_children => 1 } ); }
    }
    # 4c) after the subtree of $first
    else {
        foreach my $clitic (@clitics) { $clitic->shift_after_subtree( $first, { without_children => 1 } ); }
    }
    return;
}


# Return 1 if the given clause root is coordinated and the coordinating conjunction / shared subordinating
# conjunction is taking up the 1st position.

# E.g., in "Běžel, aby se zahřál a dostal se dřív domů.", the word "zahřál" gets 1, since "aby" fills 
# the 1st position, "dostal" gets 0, since "a" does not take up the 1st pos.
# In "Stačí, když to přinesete na úřad nebo to tam pošlete doporučeně", both "přinesete" and "pošlete"
# will get 1, since "když" and "nebo" both take up the 1st pos.  
sub _is_coord_taking_1st_pos {
    
    my ( $clause_root ) = @_;
    
    my ($coap) = $clause_root->get_parent;
    return 0 if ( !$coap || !$coap->is_coap_root );
    
    my ($eparent) = $clause_root->get_eparents;    
    return 0 if ( !$eparent || ( $eparent->afun || '' ) ne 'AuxC' );

    my (@coord_members) = grep { $_->is_member } $coap->get_children( { ordered=>1 } );
    return 0 if ( !@coord_members );

    # only fire for the first coordination member and the last one with selected coord. conjunctions 
    # ('a' and 'ale' do not fill the 1st position)
    return ( $clause_root == $coord_members[0] )
        || ( $clause_root == $coord_members[-1] && $coap->lemma !~ /^(a|ale)$/ );     
}


# Find the last word at the "1st" position, just before Wackernagel position.
sub _find_eo1st_pos {
    my ( $clause_root, $clause_first ) = @_;
    my $first;
    
    # 3a) Clause root is the leftmost node = $first (typical for subordinating conjunctions)
    if ($clause_root == $clause_first
        and not first { ( $_->afun || "" ) eq "AuxC" } $clause_root->get_children
        )
    {    # but not a multiword one
        $first = $clause_root;
    }
    # 3b) otherwise $first is one of the clause root's children
    else {   
        my $n = $clause_root->clause_number;
        $first = first { !_ignore( $_, $n ) } $clause_root->get_children( { ordered => 1, add_self => 1 } );
        if ( !$first ) { $first = $clause_root; }
    }
    return $first;
}

# climbing up as long as there are only verbs (or the governing AuxC) along the path
sub _verb_group_root {
    my $clitic    = shift;
    my $verb_root = $clitic;
    while (1) {
        my $p = $verb_root->get_parent;
        last if $p->is_root;
        last if $verb_root->clause_number ne $p->clause_number;

        # two exceptions found in PDT2.0 t-trees
        last if $p->get_attr('morphcat/pos') ne 'V' && $p->lemma !~ /^(vědomý|jistý)$/;
        $verb_root = $verb_root->get_parent();
    }

    if ( ( $verb_root->get_parent->afun || '' ) eq 'AuxC' ) {
        $verb_root = $verb_root->get_parent;
    }

    return $verb_root;

    #if $verb_root ne $clitic;
    #return;
}

sub _is_clitic {
    my $anode = shift;
    my ( $subpos, $case, $afun, $form ) =
        $anode->get_attrs( qw(morphcat/subpos morphcat/case afun form), { undefs => '' } );
    $form = lc $form;

    # 7 = reflexive pronouns = se, si, ses, sis
    # H = personal pronouns in short (clitical) form = mě, mi, tě, ti, ho, mu
    # c = conditional = bych, bys, by, bychom, byste (+ bysem, bysme)
    return 1 if $subpos =~ /[7Hc]/;

    # direct object personal pronouns (except coordinated)
    # in dative     = mně tobě jemu jí nám vám jim
    # in accusative = mě  tě   ho   ji nás vás je
    my $under_verb = ( $anode->get_parent->get_attr('morphcat/pos') || '' ) eq 'V';
    return 1 if $subpos eq 'P' && $case =~ /[34]/ && !$anode->is_member && $under_verb;

    # forms of the auxiliary verb "být" (for compound past tense):
    return 1 if $afun eq 'AuxV' && $form =~ /^(jste|jsme|jsem|jsi)$/;

    if ( $form eq 'to' && $under_verb ) {

        # demonstrative pronoun "to" in accusative as a verbal object ("Já to znám.")
        return 1 if $case eq '4';

        # copula constructions with "to" ("Je to pravda.")
        # I am not sure whether this is a clitic, but in most cases it looks better.
        return 1 if $case eq '1' && $anode->get_parent->lemma eq 'být';
    }

    # Word "tam" is not a real clitic, but it is very often context-bound.
    return 1 if $form eq 'tam' or $form eq 'sem';

    return 0;
}

# ordering if there are more than one clitic in a sequence,
# rules from http://cs.wikipedia.org/wiki/%C4%8Cesk%C3%BD_slovosled
sub _order {
    my ($anode) = shift;
    my $form = lc( $anode->form );
    return 1 if $form =~ /^(jsem|jsi|jsme|jste|by|bych|bys|bychom|byste)$/;
    return 2 if $form =~ /^(se|si)$/;
    return 3 if $form =~ /^(mi|ti|mu|jí|nám|vám|jim)$/;
    return 4 if $form =~ /^(mě|tě|ho|ji|nás|vás|je|to)$/;
    return 6 if $form =~ /^(tam|sem)$/;                                       # according to Krivan, 2006

    # All other clitics have rank 5:
    # tag=.[7Hc] ses sis bysme
    # tag=PP..3  mně tobě jemu
    return 5;
}

# Wackernagel's position is "the second", but some words are ignored.
sub _ignore {
    my ( $anode, $clause_number ) = @_;
    return 1 if _is_clitic($anode);

    # punctuation
    return 1 if $anode->get_attr('morphcat/pos') eq 'Z';

    # subordinating clause heads
    return 1 if $anode->clause_number != $clause_number;

    # functor = 'PREC'
    return 1 if $anode->lemma =~ /^(a|ale)$/ && $anode->get_children == 0;

    # multiword subordinating conjunctions such as 'i kdyz'
    return 1 if ( $anode->afun || "" ) eq "AuxC"
        and ( $anode->get_next_node->afun || "" ) eq "AuxC";

    return 0;
}

sub _is_pronoun_je {
    my ($anode) = @_;
    return $anode->form eq 'je' && $anode->get_attr('morphcat/subpos') eq 'P';
}

sub _is_verb_je {
    my ($anode) = @_;
    return $anode->form eq 'je' && $anode->lemma eq 'být';
}

sub _move_je {
    my ($je) = @_;
    $je->shift_before_subtree( $je->get_parent() );
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::MoveCliticsToWackernagel

=head1 DESCRIPTION

In each clause, a-nodes which represent clitics are moved
to the so called second position in the clause
(according to Wackernagel's law). If there are more clitics in
one clause, they are sorted according to simple grammatical rules.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
