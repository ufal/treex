package Treex::Block::MLFix::CS::Oracle;

use Moose;
use utf8;

use Treex::Tool::MLFix::CS::FormGenerator;

extends 'Treex::Block::MLFix::Oracle';

sub _build_form_generator {
	my ($self) = @_;

	return Treex::Tool::MLFix::CS::FormGenerator->new();
}

1;

=head1 NAME

MLFix::CS::Oracle

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
