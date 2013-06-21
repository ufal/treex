package Treex::Core::WildAttr;
use Moose::Role;

use Treex::Core::Log;

use Data::Dumper;

has wild => (
    is => 'rw',

    #    isa    => 'HashRef',
    reader  => '_get_wild',
    writer  => 'set_wild',
    default => sub { return {} },
);

sub wild {
    my ($self) = @_;
    if ( !$self->_get_wild ) {
        $self->set_wild( {} );
    }
    return $self->_get_wild;

}

sub _wild_dump {
    my ($self) = @_;
    if ( $self->isa('Treex::Core::Document') ) {
        my $metadata = $self->metaData('pml_root');
        my $meta = $metadata->{meta};
        return $meta->{wild_dump};
    }
    else {
        return $self->{wild_dump};
    }
}

sub _set_wild_dump {
    my ( $self, $value ) = @_;

    my $storing_hash_ref = $self;
    if ( $self->isa('Treex::Core::Document') ) {
        $storing_hash_ref = $self->metaData('pml_root')->{meta};
    }

    $storing_hash_ref->{wild_dump} = $value;
    return;
}

sub serialize_wild {
    my ($self) = @_;
    if ( %{ $self->wild } ) {
        $self->_set_wild_dump( Dumper( $self->wild ) );
    }
    else {
        $self->_set_wild_dump(undef);
    }
    return;
}

sub deserialize_wild {
    my ($self) = @_;
    if ( $self->_wild_dump ) {
        $self->set_wild( eval "my " . $self->_wild_dump . '; return $VAR1' ); ## no critic (ProhibitStringyEval)
    }
    else {
        $self->set_wild( {} );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::WildAttr - role for arbitrary attributes of Treex objects

=for test_synopsis my ($node, $value);
=head1 SYNOPSIS

  $node->wild->{name_of_my_new_attribute} = $value;
  $value = $node->wild->{name_of_my_new_attribute};

=head1 DESCRIPTION

Moose role for Treex objects that can possess any attributes
without defining them in the PML schema. Such 'wild'
attributes are stored in trees data files as strings
serialized by Data::Dumper.


Expected use cases: you need to store some data structures which are not defined
by the Treex PML schema because
(1) you do not want to change the schema
(e.g. the new attributes are still very unstable, or they are likely to serve only
for tentative purposes, or you do not feel competent to touch the PML schema), or
(2) you cannot change the schema, because you do not have write permissions for the
location in which L<Treex::Core> is installed.

=head1 ATTRIBUTES

=over

=item wild

Reference to a hash for storing wild attributes.
The attributes are to be accessed as follows:

 $object->wild->{$wild_attr_name} = $wild_attr_value;

=item wild_dump

PML-standard attribute which stores stringified
content of the attribute C<wild>. C<wild> and C<wild_dump>
are synchronized by methods C<serialize_wild> and
C<deserialize_wild>; C<wild_dump> should not be
accessed otherwise.

=back

=head1 METHODS

=over

=item serialize_wild();

Stores the content of the C<wild> hash into the C<wild_dump> string.

=item deserialize_wild();

Loads the content from the C<wild_dump> string into the C<wild> hash.

=back


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
