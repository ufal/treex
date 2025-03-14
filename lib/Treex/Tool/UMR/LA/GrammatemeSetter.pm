package Treex::Tool::UMR::LA::GrammatemeSetter;
use Moose::Role;
with 'Treex::Tool::UMR::GrammatemeSetter';

use experimental qw{ signatures };

=head1 NAME

Treex::Tool::UMR::LA::GrammatemeSetter - Language specific grammateme
deduction from morphology.

=cut

{    my %REGEX = (person => '^.([123])',
                 number => '^..([sp])');
    sub tag_regex($self, $grammateme) { $REGEX{$grammateme} }
}

{   my %GRAM = (person => {1     => '1st',
                           2     => '2nd',
                           3     => '3rd'},
                number => {s     => 'singular',
                           p     => 'plural'});
    sub translate($self, $grammateme, $value) { $GRAM{$grammateme}{$value} }
}

__PACKAGE__
