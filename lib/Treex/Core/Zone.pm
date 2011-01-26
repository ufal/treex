package Treex::Core::Zone;

# antecedent of DocZone and BundleZone

use Moose;
use MooseX::NonMoose;
use MooseX::FollowPBP;

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



1;
