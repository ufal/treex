package Treex::Core::Zone;

# antecedent of DocZone and BundleZone

use Moose;
use Treex::Moose;
use MooseX::NonMoose;

extends 'Treex::PML::Struct';

has language => (is => 'rw', isa=>'LangCode', required=>1);

has selector => (is => 'rw', isa=>'Selector', default=>'');

sub set_attr {
    my ($self, $attr_name, $attr_value) = @_;
    return $self->{$attr_name} = $attr_value;
}

sub get_attr {
    my ($self, $attr_name) = @_;
    return $self->{$attr_name};
}

sub get_label {
    my ($self) = @_;
    return $self->selector . $self->language;
}
1;
