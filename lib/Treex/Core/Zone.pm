package Treex::Core::Zone;

# antecedent of DocZone and BundleZone

use Moose;
use Treex::Moose;
use MooseX::NonMoose;

extends 'Treex::PML::Seq::Element';

has language => (is => 'rw');

has selector => (is => 'rw');

sub set_attr {
    my ($self, $attr_name, $attr_value) = @_;
    return $self->value->{$attr_name} = $attr_value;
}

sub get_attr {
    my ($self, $attr_name) = @_;
    return $self->value->{$attr_name};
}

sub get_label {
    my ($self) = @_;
    return $self->get_attr('selector') . $self->get_attr('language');
}
1;
