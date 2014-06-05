package Treex::Block::A2T::EN::SetFunctors2;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetFunctorsMLProcess';

has '+model' => ( default => 'data/models/functors/en/model-pack.dat.gz' );

has '+features_config' => ( default => 'data/models/functors/en/features.yml' );

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetFunctors2

=head1 DESCRIPTION

This is just a default configuration of L<Treex::Block::A2T::SetFunctorsMLProcess> for English, containing pre-set
paths to the trained models and configuration in the Treex shared directory. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
