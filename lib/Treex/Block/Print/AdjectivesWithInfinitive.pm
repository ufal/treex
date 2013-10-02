package Treex::Block::Print::AdjectivesWithInfinitive;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_anode {
    my ( $self, $anode ) = @_;
    my $parent = $anode->parent;
    return if $parent->is_root;

    if ($anode->tag =~ /^A/ && #$anode->form =~ /[éona]$/ &&
        $parent->lemma =~ 'být' && $parent->form =~ /^je|být$/){
        my $inf = first {is_inf($_)} $parent->get_children();
        my $shape = 'sibl';
        if (!$inf) {
            $inf = first {is_inf($_)} $anode->get_children();
            $shape = 'child';
        }
        return if !$inf;
        print { $self->_file_handle } join("\t", $shape, $anode->lemma, $inf->lemma, $anode->get_zone->sentence, $parent->get_address()) . "\n";
    }
    return;
}

sub is_inf {
    my ($node) = @_;
    return 0 if $node->tag !~ /^Vf/;
    return 0 if any{$_->tag =~ /^V/} $node->get_children();
    return 1;
}

1;

=encoding utf-8

=head1 NAME 

Treex::Block::Print::AdjectivesWithInfinitive

=head1 DESCRIPTION

Find constructions like "Je snadné prodat", where the adjective with copula verb is modified by an infinitive.
Parsers sometimes hang the infinitive as a sibling of the asjective (which is the PDT style),
sometimes as a child of the adjective (which also seems quite reasonable).
Only some adjectives can be used in these constructions, so this block collects the statistics (with example sentences).
For prof. Panevová.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
