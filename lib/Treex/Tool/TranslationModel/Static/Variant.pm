package Treex::Tool::TranslationModel::Static::Variant;

use strict;
use warnings;
use utf8;

use Readonly;
Readonly my $LOG2 => log(2);

sub new {
    my ( $class, $value, $prob ) = @_;
    my $self = [ $value, $prob ];
    bless $self, $class;
    return $self;
}

sub value   { return $_[0][0]; }
sub prob    { return $_[0][1]; }
sub logprob { return log( $_[0][1] ) / $LOG2; }
use overload (
    q{""}    => 'value',
    fallback => 1,
);

1;

__END__

=pod

This class is just a container for two attributes: value and prob(ability).
When its instances are used in string context, value is returned.

This class is impossible to implement with C<Class::Std> since it can't be serialized. 
I tried C<Class::Std::Storable> but it is cca 10 times slower
than this simple array-based implementation. 

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
