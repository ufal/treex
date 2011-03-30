package Treex::Block::T2A::CS::ReverseNumberNounDependency;
use utf8;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

use Lexicon::Czech;

sub process_ttree {
    my ( $self, $t_root ) = @_;

    # Start on the second level so every node to process has non-root parent
    foreach my $t_node ( $t_root->get_children() ) {
        process_subtree($t_node);
    }
    return;
}

sub process_subtree {
    my ($t_node) = @_;
    process_t_node($t_node);
    foreach my $child ( $t_node->get_children() ) {
        process_subtree($child)
    }
}

sub process_t_node {
    my ($t_node) = @_;

    # We want to process only some specific numeric lemmas that precede their parents
    my $t_lemma = $t_node->t_lemma;
    my $t_noun  = $t_node->get_parent();
    return if $t_noun->precedes($t_node) || !should_be_governing($t_lemma);

    # The switch takes place only if
    # the case of the governing noun is nominative or accusative.
    my $noun_formeme = $t_noun->formeme;
    my ( $noun_prep, $noun_case ) = $noun_formeme =~ /^n:(?:(.*)\+)?([14])$/;
    return if !$noun_case;

    # Switch $a_node with its parent ($a_noun)
    my $a_node = $t_node->get_lex_anode();
    my $a_noun = $a_node->get_parent();
    $a_node->set_parent( $a_noun->get_parent() );
    $a_noun->set_parent($a_node);

    # is_member attribute must stay with the governing node
    if ( $a_noun->is_member ) {
        $a_noun->set_is_member(0);
        $a_node->set_is_member(1);
    }

    # In some cases there can be prepositions in the formeme of $t_node
    # "more than four hundred guests" -> "four hundred(formeme=n:more_than+X) guests"
    # These prepositions must be saved and subsequently merged with the prepositions
    # of the noun "the rest went on more than four hundred guests(formeme=n:on+X)"
    my $number_formeme = $t_node->formeme;
    $number_formeme =~ /:(?:(.*)\+)?/;
    my $number_prep = $1;

    # Merge both the prepositions
    my $preps = ( $number_prep && $noun_prep )
        ? $noun_prep . '_' . $number_prep . '+'
        : $number_prep ? $number_prep . '+'
        : $noun_prep   ? $noun_prep . '+'
        :                '';

    # Change formemes:
    # The number ($t_node) gets the formeme of the noun (with merged preps)
    # The noun gets formeme with genitive case.
    $t_node->set_formeme("n:$preps$noun_case");
    $t_noun->set_formeme('n:2');

    # For info/debuging purposes let's update formeme_origin too
    my $noun_f_origin = $t_noun->formeme_origin;
    $t_node->set_attr( 'formeme_origin', "rule-number_from_parent($noun_f_origin:$noun_formeme)" );
    $t_noun->set_formeme_origin('rule-number_genitive');

    # Numbers with decimal point/comma require singular noun in Czech
    # "2,5 miliardy" (not "2,5 miliard")
    if ( $t_lemma =~ /\d[\.,]\d/ ) {
        $t_noun->set_attr( 'gram/number', 'sg' );
    }

    return;
}

sub should_be_governing {
    my ($t_lemma) = @_;

    # 3 000 -> 3000
    $t_lemma =~ s/ //g;
    return 1 if is_bigger_than_four_or_fraction($t_lemma);
    return 1 if $t_lemma =~ /^\d+[,.]\d+$/;
    return 1 if $t_lemma =~ /^(mnoho|několik|méně|více|málo|hodně|většina|menšina)$/;
    return 0;
}

sub is_bigger_than_four_or_fraction {
    my ($lemma) = @_;
    my $equivalent = Lexicon::Czech::number_for($lemma) or return 0;
    return $equivalent > 4 || $equivalent < 1;
}

1;

=over

=item Treex::Block::T2A::CS::ReverseNumberNounDependency

Reverse the dependency orientation between numeric expressions and counted nouns
in the case that the former is bigger than four and the latter
should have been expressed in nominative or accusative.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
