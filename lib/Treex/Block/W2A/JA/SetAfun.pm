package Treex::Block::W2A::JA::SetAfun;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    # Process heads of main clauses + the terminal punctuation (AuxK).
    # Then recursively process the whole tree.
    # (Rarely, there can be more terminal punctuations.!)
    # (There may be more heads and this is in case of coordinations.)
    foreach my $subroot ( $a_root->get_echildren() ) {
        $subroot->set_afun( get_afun_for_subroot($subroot) );
        process_subtree($subroot);
    }

    return 1;
}

sub get_afun_for_subroot {
    my ($subroot) = @_;

    my $afun = $subroot->afun;
    return $afun if $afun;

    my $lemma = $subroot->lemma;
    my $tag = $subroot->tag;

    return 'AuxK' if $subroot->form =~ /^[.?!]$/;
    
    # we set Pred Afun to Copulas and verbs
    return 'Pred' if ( $lemma eq "です" || $lemma eq "だ" || $tag =~ /^Dōshi/) ;
    return 'ExD';
}

sub process_subtree {
    my ($node) = @_;
    foreach my $subject ( find_subjects_of($node) ) {
        $subject->set_afun('Sb');
    }

    foreach my $child ( $node->get_echildren() ) {
        if ( !$child->afun ) {
            $child->set_afun( get_afun($child) );
        }
        process_subtree($child);
    }
    return;
}

# Marks auxiliary verbs (tagged Jodōshi, except for Copulas) with afun=AuxV
# and returns the subject of $node if any.
# In case of coordinated subjects, returns all such subjects.
sub find_subjects_of {
    my ($node) = @_;
    my $tag = $node->tag;
    my $lemma = $node->lemma;

    my @subjects;

    # Mark all auxiliary verbs
    my @children = $node->get_echildren( { ordered => 1 });
    foreach my $auxV ( grep { is_aux_verb( $_, $node ) } @children ) {
      $auxV->set_afun('AuxV');
    }

    # Only verbs and copulas can have Sb
    return if !( $lemma eq "です" || $lemma eq "だ" || $tag =~ /^Dōshi/);

    # find subject, which should be indicated by "が" particle
    # if there are more, we take the one with highest Ord
    my @sb_indicators = grep { $_->lemma eq "が"} @children ;
    if ( !@sb_indicators ) {
    	# other possibility is that the topic indicated by "は" is subject
    	@sb_indicators = grep { $_->lemma eq "は"} @children ; 
    }  
       
    if ( @sb_indicators ) {
      my $indicator = pop @sb_indicators;
      @subjects = $indicator->get_echildren();
    }

    return @subjects;
}

sub is_aux_verb {
    my ( $node, $eparent ) = @_;
    my $lemma = $node->lemma;
    my $tag = $node->tag;
    my $ep_tag = $eparent->tag;

    # We mark all Jodōshi except Copulas as auxiliary
    return 1 if ( $tag =~ /^Jodōshi/ && $lemma ne "です" && $lemma ne "だ" );

    return 0;
}

# Handle remaining afuns, i.e. all except Aux[CPV] and Sb.
sub get_afun {
    my ($node) = @_;
    my $tag = $node->tag;
    my $lemma = $node->lemma;
    my ($eparent) = $node->get_eparents();
    
    my $afun = $node->afun;
    return $afun if $afun;

    return 'Pnom' if ( $eparent->follows($node) && ( $eparent->lemma eq "です" || $eparent->lemma eq "だ" ) );

    # According to HamleDT JA training data it shloud be Obj
    return 'Obj' if $eparent->follows($node) && $eparent->lemma eq "する";

    return 'Adv' if $tag =~ /^Fukushi/;

    my $granpa = $eparent->get_parent();
    
    # Mark independent verbs of a compound predicate
    return 'Obj' if ( $tag =~ /^Dōshi/ && $eparent->tag =~ /Dōshi-HiJiritsu/);
    # "te"-<verb> form 
    return 'Obj' if ( $tag =~ /^Dōshi/ && $eparent->lemma eq "て" && $granpa->tag =~ /Dōshi-HiJiritsu/ );


    # Punctuation
    # AuxK = terminal punctuation of a sentence
    # AuxG = other graphic symbols
    # AuxX = comma (not serving as Coord)
    my $form = $node->form;
    return 'AuxK' if $form =~ /[?!]/;
    return 'AuxX' if $form =~ /[,、]/;

    # Honorifix prefixes ("o-", "go-") should probably be AuxO
    return '' if $tag =~ /^SettōShi/;

    # Any other punctuation
    # TODO: include every possible example
    return 'AuxG' if  $form =~ /[「」『』（）]/;

    # Negation 
    return 'Neg' if ($lemma eq 'ない' || $lemma eq 'ん');

    # Nouns/Verbs/Nominals/Adjectives/Numerals as Atr
    return 'Atr' if ( $tag =~ /^(Meishi|Dōshi|Keiyōshi|Keiyōdōshi)/ && $eparent->tag =~ /^Meishi/);

    # Nouns/Nominals/Adjectives/Verbs under postposition/subord.conjunction
    if ( $tag =~ /^(Meishi|Dōshi)/ && $eparent->afun =~ /Aux[PC]/ && $granpa) {
      my $granpa_tag   = $granpa->tag   || '_root';
      return 'Adv' if ( $tag =~ /^Dōshi/ && $granpa_tag =~ /^Dōshi/ );
      return 'Obj' if $granpa_tag =~ /^Dōshi/;
      return 'Atr' if $granpa_tag =~ /^Meishi/;
    }

    # TODO: Japanese "determiners" (kore, sore...)
    #    -  Do we need to detect them?

    ### TODO: How to handle Japanese topics? Perhaps as objects?

    # And the rest - we don't know
    # TODO: Is this really all we need?
    return 'NR';
}

1;

__END__


=pod

=encoding utf-8

=head1 NAME

 Treex::Block::W2A::JA::SetAfun - Fills in the rest of the analytical functions within the a-tree.

=head1 DESCRIPTION

Fill the afun attribute by several heuristic rules.
Before applying this block, afun values C<Coord> (coordinating conjunction) and C<AuxP> (preposition) must be already filled.

We are still not sure, if the Japanese Afuns are set correctly.

This block doesn't change already filled afun values, except for the C<Sb> afun.

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut


