package Treex::Core::Zone;

# antecedent of DocZone and BundleZone

use Moose;
use Treex::Moose;
use MooseX::NonMoose;

extends 'Treex::PML::Struct';

has language => ( is => 'rw', isa => 'LangCode', required => 1 );

has selector => ( is => 'rw', isa => 'Selector', default => '' );

# Based on source code of Moose::Object::BUILDARGS,
# but we don't want to copy args (return { %{$_[0]} };).
# The motivation for this is that we want
# to enable "Moose-aware reblessing" of Treex::PML::Struct
# foreach my $zone ( map { $_->value() } $bundle->{zones}->elements ) {
#     Treex::Core::BundleZone->new($zone);
#     ...
sub BUILDARGS {
    my $class = shift;
    if ( scalar @_ == 1 ) {
        unless ( defined $_[0] && ref $_[0] ) {
            Carp::confess('Single parameter to new() must be a HASH ref');
        }
        return $_[0];
    }
    elsif ( @_ % 2 ) {
        Carp::carp(
            "The new() method for $class expects a hash reference or a key/value list."
                . " You passed an odd number of arguments"
        );
        return { @_, undef };
    }
    else {
        return {@_};
    }
}

sub FOREIGNBUILDARGS {
    my $class   = shift;
    my $arg_ref = $class->BUILDARGS(@_);

    # We want to reuse the $arg_ref hashref as the blessed instance variable, i.e.
    # $reuse = 1; Treex::PML::Struct->new( $arg_ref, $reuse )
    return ( $arg_ref, 1 );
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
