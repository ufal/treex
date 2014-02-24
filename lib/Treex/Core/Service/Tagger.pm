package Treex::Core::Service::Tagger;

use Moose;
use Treex::Core::Loader qw/load_module/;
use Treex::Core::Log;
use namespace::autoclean;

extends 'Treex::Core::Service';

has 'tagger' => (
  is => 'ro',
  does => 'Treex::Tool::Tagger::Role',
  writer => '_set_tagger'
);

sub initialize {
  my ($self, $args_ref) = @_;

  super();
  my $module_name = delete $args_ref->{module};
  my $module = "Treex::Tool::Tagger::$module_name";
  load_module($module);

  $self->_set_tagger($module->new($args_ref));
}

sub process {
  return shift->tagger->tag_sentence(@_);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Service::Tagger

=head1 AUTHOR

Michal Sedlak <sedlak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
