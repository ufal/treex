package Treex::Tool::Coreference::NodeFilter;
use Moose::Role;

requires 'is_candidate';

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::NodeFilter

=head1 DESCRIPTION

The purpose of classes consuming this role is simple. To filter out
nodes on a given condition.

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item is_candidate

Returns true/false depending on whether the input node fulfils the given condition.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
