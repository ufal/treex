package Treex::Block::T2A::CS::ReverseNumberNounDependency;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS;

# Main
sub process_ttree {
    my ( $self, $t_root ) = @_;

    # Start on the second level so every node to process has non-root parent
    foreach my $t_node ( $t_root->get_children() ) {
        _process_subtree($t_node);
    }
    return;
}

sub _process_subtree {
    my ($t_node) = @_;

    # process the current node
    if ( $t_node->is_coap_root ) {
        _process_coap_t_node($t_node);
    }
    else {
        _process_t_node($t_node);
    }

    # recurse deeper
    foreach my $child ( $t_node->get_children() ) {
        _process_subtree($child);
    }

    return;
}

# Process a non-coordination node (and trigger the change if it is a non-congrunet numeral)
sub _process_t_node {

    my ($t_node) = @_;

    # We want to process only some specific numeric lemmas that precede their parents
    my $t_lemma = $t_node->t_lemma;
    my $t_noun  = $t_node->get_parent();
    return if $t_noun->precedes($t_node) || !_should_be_governing($t_lemma);

    # The switch takes place only if
    # the case of the governing noun is nominative or accusative.
    my ( $noun_prep, $noun_case ) = _get_noun_prepcase($t_noun);
    return if !$noun_case;

    _switch_a_dependency( $t_node, $t_noun );

    # In some cases there can be prepositions in the formeme of $t_node
    # "more than four hundred guests" -> "four hundred(formeme=n:more_than+X) guests"
    # These prepositions must be saved and subsequently merged with the prepositions
    # of the noun "the rest went on more than four hundred guests(formeme=n:on+X)"
    _update_formemes( $t_node, $t_noun, $noun_prep, $noun_case );

    # Numbers with decimal point/comma require singular noun in Czech
    # "2,5 miliardy" (not "2,5 miliard")
    # TODO this belongs to the transfer phase
    if ( $t_lemma =~ /\d[\.,]\d/ ) {
        $t_noun->set_gram_number('sg');
    }

    return;
}

# Process a coordination head (and trigger the change if it coordinates non-congruent numerals)
sub _process_coap_t_node {

    my ($t_node) = @_;
    my @t_children = grep { $_->is_member } $t_node->get_children();
    return if ( !@t_children );

    # all member children must be numerals
    my $t_noun = $t_node->get_parent();
    return if $t_noun->precedes($t_node) || any { !_should_be_governing( $_->t_lemma ) } @t_children;

    my ( $noun_prep, $noun_case ) = _get_noun_prepcase($t_noun);
    return if !$noun_case;

    _switch_a_dependency( $t_node, $t_noun );

    # set formemes for all members
    map { _update_formemes( $_, $t_noun, $noun_prep, $noun_case ) } @t_children;

    # fix the noun number according to the last child
    if ( $t_children[-1]->t_lemma =~ /\d[\.,]\d/ ) {
        $t_noun->set_gram_number('sg');
    }

    return;
}

# Change the formeme of the noun to genitive and the formeme of the number
# to the noun case + noun preposition + number preposition
sub _update_formemes {

    my ( $t_number, $t_noun, $noun_prep, $noun_case ) = @_;

    my ($number_prep) = $t_number->formeme =~ /:(?:(.*)\+)?/;

    # Merge both the prepositions
    my $preps = ( $number_prep && $noun_prep )
        ? $noun_prep . '_' . $number_prep . '+'
        : $number_prep ? $number_prep . '+'
        : $noun_prep   ? $noun_prep . '+'
        :                '';

    # For info/debuging purposes let's update formeme_origin too
    $t_number->set_formeme_origin( 'rule-number_from_parent(' . $t_noun->formeme_origin . ':' . $t_noun->formeme . ')' );
    $t_noun->set_formeme_origin('rule-number_genitive');

    # Change formemes:
    # The number ($t_node) gets the formeme of the noun (with merged preps)
    # The noun gets formeme with genitive case.
    # NOTE: this change to t-trees makes a rerun of the generation different from the original results; in the re-run,
    # the ReverseNumberNounDependency block will not execute, which introduces grammar errors
    $t_number->set_formeme("n:$preps$noun_case");
    $t_noun->set_formeme('n:2');

    return;
}

# Return 1 if the given t_lemma is a non-congruent numeral which should govern its t-child on the a-layer
sub _should_be_governing {
    my ($t_lemma) = @_;

    # 3 000 -> 3000
    $t_lemma =~ s/ //g;
    return 1 if _is_bigger_than_four_or_fraction($t_lemma);
    return 1 if $t_lemma =~ /^\d+[,.]\d+$/;
    return 1 if $t_lemma =~ /^(mnoho|(ně)?kolik|méně|více|málo|hodně|většina|menšina)$/;
    return 0;
}

# Returns 1 for a number greater than four or a fraction
sub _is_bigger_than_four_or_fraction {
    my ($lemma) = @_;
    my $equivalent = Treex::Tool::Lexicon::CS::number_for($lemma) or return 0;
    return $equivalent > 4 || $equivalent < 1;
}

# Returns the preposition and case from the noun formeme
sub _get_noun_prepcase {
    my ($t_noun) = @_;
    my ( $noun_prep, $noun_case ) = $t_noun->formeme =~ /^n:(?:(.*)\+)?([14X])$/;
    
    return ( $noun_prep, $noun_case );
}

# Rehangs a dependency of the a-nodes corresponding to the given t-nodes
sub _switch_a_dependency {

    my ( $t_numeral, $t_noun ) = @_;

    # Switch $a_node with its parent ($a_noun)
    my $a_node = $t_numeral->get_lex_anode();
    my $a_noun = $a_node->get_parent();
    $a_node->set_parent( $a_noun->get_parent() );
    $a_noun->set_parent($a_node);

    # is_member and is_parenthesis attributes must stay with the governing node
    # TODO: there may be more such attributes
    #       node dependency reversing is done also elsewhere in Treex, so it might be handy to implement it just once
    if ( $a_noun->is_member ) {
        $a_noun->set_is_member(0);
        $a_node->set_is_member(1);
    }
    if ( $a_noun->wild->{is_parenthesis} ) {
        $a_noun->wild->{is_parenthesis} = 0;
        $a_node->wild->{is_parenthesis} = 1;
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::ReverseNumberNounDependency

=head1 DESCRIPTION

Reverse the dependency orientation between numeric expressions and counted nouns 
in the case that the former is bigger than four and the latter
should have been expressed in nominative or accusative.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
