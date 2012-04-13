package Treex::Tool::Coreference::NodeFilter;
use Moose::Role;

requires 'is_candidate';

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::NodeFilter

=head1 DESCRIPTION

A role for node filtering. The only method that must be implemented
in a subclass is C<is_candidate>, which returns a boolean value
saying whether the node is accepted as a candidate or not.

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item is_candidate

Must return a boolean value saying whether the node is accepted as a candidate 
or not.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
