package Treex::Block::T2A::CS::MoveQuotes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# I am sorry for the messy code and no comments, I was in a hurry :-(.
# Anyway, it is a hack which checks the source-language a-trees.

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if $tnode->t_lemma ne '„';
    return if $tnode->get_siblings( { preceding_only => 1 } );
    my $en_t_quote = $tnode->src_tnode            or return;
    my $en_a_quote = $en_t_quote->get_lex_anode() or return;
    return if $en_a_quote->get_siblings( { preceding_only => 1 } );
    my $en_a_parent = $en_a_quote->get_parent();
    return if $en_a_parent->is_root;
    my ($en_a_gparent) = $en_a_parent->get_eparents( { or_topological => 1 } );
    return if $en_a_gparent->precedes($en_a_quote) && ( ( $en_a_gparent->afun || '' ) =~ /^Aux[CP]/ or $en_a_gparent->lemma eq 'click' );
    my $a_quote  = $tnode->get_lex_anode() or return;
    my $a_parent = $a_quote->get_parent();
    return if $a_parent->is_root();
    my ($a_gparent) = $a_parent->get_eparents( { or_topological => 1 } );
    my @lefties =
        sort { $a->ord <=> $b->ord }
        grep { ( $_->afun || '' ) =~ /^Aux/ && $_->precedes($a_quote) }
        ( $a_quote->get_siblings(), ( $a_gparent->afun || '' ) =~ /^Aux[CP]/ ? $a_gparent : () );

    if (@lefties) {
        $a_quote->shift_before_subtree( $lefties[0] );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::MoveQuotes - shift quotes before generated Aux* nodes

=head1 DESCRIPTION

Without this dirty-fix block, translation would be TST, but we want REF:

 SRC: It was "at stake".
 REF: Bylo to "v sázce".
 TST: Bylo to v "sázce".

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
