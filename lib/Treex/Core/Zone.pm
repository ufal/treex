package Treex::Core::Zone;

# antecedent of DocZone and BundleZone

use Moose;
use Treex::Moose;
use MooseX::NonMoose;

extends 'Treex::PML::Struct';

has language => ( is => 'rw', isa => 'LangCode', required => 1 );

has selector => ( is => 'rw', isa => 'Selector', default => '' );

sub BUILD {
    # print "Zone BUILD\n";
    #
    # ERROR: This is not executed when the document is loaded from a file.
    # The reason is that Treex::Core::Document uses:
    # foreach my $zone ( map { $_->value() } $bundle->{zones}->elements ) {
    #   bless $zone, 'Treex::Core::BundleZone';
    #   ...
    # and this is not the correct way.
    # Maybe we should use MooseX::NonMoose::FOREIGNBUILDARGS...
}

sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    return $self->{$attr_name} = $attr_value;
}

sub get_attr {
    my ( $self, $attr_name ) = @_;
    return $self->{$attr_name};
}

sub get_label {
    my ($self) = @_;
    return $self->selector . $self->language;
}
1;
