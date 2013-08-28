package Treex::Block::HamleDT::SetSharedModifier;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $node ) = @_;
    if (( $node->get_parent->afun || '' ) eq 'Coord'){
        if ($node->is_member || ( $node->afun || '' ) =~ /Aux[XYG]/ || $node->form =~ /^["'()“”„«»‘’]$/){
            $node->set_is_shared_modifier(0);
        } else {
            $node->set_is_shared_modifier(1);
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::SetSharedModifier - fill C<is_shared_modifier> attribute in PDT-style annotation

=head1 DESCRIPTION

In the PDT style, shared modifiers of coordinations can be distinguished
just based on the fact they are hanged on the conjunction (coord. head with I<Coord> afun), and
they are not conjuncts (is_member!=1) nor auxiliary tokens (commas or other separators).
In other styles (e.g. Stanford) this attribute might be useful. 

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
