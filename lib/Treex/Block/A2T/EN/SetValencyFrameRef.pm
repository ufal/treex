package Treex::Block::A2T::EN::SetValencyFrameRef;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetValencyFrameRef';

has '+model' => ( default => 'data/models/wsd/en/model-pack.dat.gz' );

has '+features_config' => ( default => 'data/models/wsd/en/features.yml' );

has '+valency_dict_name' => ( default => 'engvallex.xml' );

has '+memory' => ( default => '4g' );

has '+sempos_filter' => ( default => 'v' );

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetValencyFrameRef

=head1 DESCRIPTION

This is just a default configuration of L<Treex::Block::A2T::SetValencyFrameRef> for English, containing pre-set
paths to the trained models and configuration in the Treex shared directory. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
