package Treex::Tool::UMR::CS::GrammatemeSetter;
use Moose::Role;
with 'Treex::Tool::UMR::GrammatemeSetter';

use experimental qw{ signatures };

=head1 NAME

Treex::Tool::UMR::CS::GrammatemeSetter - Language specific grammateme
deduction from morphology.

=cut

{    my %REGEX = (person => '^.{7}([123])',
                  number => '^(?x:(?| .{6} ([SP])'
                                 . '| .{3} ([SP]) ))');
    sub tag_regex($self, $grammateme) { $REGEX{$grammateme} }
}

{   my %GRAM = (person => {1 => 1,
                           2 => 2,
                           3 => 3},
                number => {S => 'sg',
                           P => 'pl'});
    sub translate($self, $grammateme, $value) { $GRAM{$grammateme}{$value} }
}

sub is_valid_tag($self, $tag) {
    $tag =~ /^[NAP]/
}


__PACKAGE__
