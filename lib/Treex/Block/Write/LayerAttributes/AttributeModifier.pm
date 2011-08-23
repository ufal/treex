package Treex::Block::Write::LayerAttributes::AttributeModifier;

use Moose::Role;

requires 'modify';

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::AttributeModifier

=head1 DESCRIPTION

A base Moose role of text modifiers for blocks using L<Treex::Block::Write::LayerAttributes>. The role itself
is empty, but all actual modifier implementation must contain the C<modify()> method which takes the textual
value of an attribute and returns its modification.

If the given attribute value is undefined, the method should return an undefined value, too; if the given attribute
is an empty string, the result should also be an empty string.  

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

