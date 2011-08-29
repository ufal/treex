package Treex::Block::Write::LayerAttributes::AttributeModifier;

use Moose::Role;

requires 'modify';

has 'return_values_names' => ( isa => 'ArrayRef', is => 'ro', required => 1 );

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::AttributeModifier

=head1 DESCRIPTION

A base Moose role of text modifiers for blocks using L<Treex::Block::Write::LayerAttributes>. The role itself
is empty, but all actual modifier implementation musts contain the following methods/attributes:

=item modify()

A method which takes the textual value of attribute(s) and returns its/their modification(s).

If the given attribute value(s) is/are undefined, the method should return an undefined value, too; if 
the given attribute(s) is/are empty string(s), the result should also be empty string(s).

=item return_value_names

This attribute must be an array reference containing the names of all the different values returned by
the modifier.    

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

