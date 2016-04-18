package Treex::Block::A2T::EN::SetValencyFrameRefVW;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetValencyFrameRefVW';

has '+model_file' => ( default => 'data/models/valframes/VF-EN.201.csoaa_ldf_mc-passes_4-loss_function_hinge.model' );

has '+features_file' => ( default => 'data/models/valframes/features-valrf_en.vw.yml' );

has '+valency_dict_name' => ( default => 'engvallex.xml' );

has '+valency_dict_prefix' => ( default => 'en-v#' );

has '+sempos_filter' => ( default => 'v' );

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetValencyFrameRefVW

=head1 DESCRIPTION

This is just a default configuration of L<Treex::Block::A2T::SetValencyFrameRefVW> for English, containing pre-set
paths to the trained models and configuration in the Treex shared directory. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
