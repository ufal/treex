package Treex::Core::Zone;

# antecedent of DocZone and BundleZone

use Moose;
use Treex::Core::Common;
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
        return { ( @_, undef ) };
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
    my $self = shift;
    my ( $attr_name, $attr_value ) = pos_validated_list(
        \@_,
        { isa => 'Str' },
        { isa => 'Any' },
    );

    return $self->{$attr_name} = $attr_value;
}

sub get_attr {
    my $self = shift;
    my ($attr_name) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );
    return $self->{$attr_name};
}

sub get_label {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return $self->language . ( $self->selector ? '_' . $self->selector : '' );
}
1;

__END__


=for Pod::Coverage BUILDARGS FOREIGNBUILDARGS set_attr get_attr

=encoding utf-8

=head1 NAME

Treex::Core::Zone - base class for Zones

=head1 DESCRIPTION

C<Treex::Core::Zone> is an abstract class, it is the antecedent
of L<Treex::Core::DocZone> and
L<Treex::Core::BundleZone>.

=head1 ATTRIBUTES

C<Treex::Core::Zone> instances have the following attributes:

=over 4

=item language

=item selector

=back

=head1 METHODS

=over 4

=item $my $label = $zone->get_label;

I<Zone label> is a string containing the zone's language
and selector concatenated with 'C<_>'(if the latter one is defined,
otherwise only the language).

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
