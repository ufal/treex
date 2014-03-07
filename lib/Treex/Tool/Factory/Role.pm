package Treex::Tool::Factory::Role;

use Moose::Role;
use Treex::Core::Config;
use Treex::Core::Log;

use Moose::Autobox;
use Module::Runtime qw( use_package_optimistically );
use Try::Tiny;
use namespace::autoclean;

has _options => (
    is => 'ro',
    isa => 'ArrayRef[Any]'
);

has _implementation => (
    is => 'ro',
    isa => 'Str'
);

has use_services => (
    is  => 'ro',
    isa => 'Bool',
    default => sub { Treex::Core::Config->use_services; },
    writer => '_set_use_services'
);

sub create {
    my ($class, $impl, @impl_args) = @_;

    if (defined $impl) {
        my $factory
          = $class->new({
              _implementation => $impl,
              _options => [ @impl_args ]
          });

        my $implementation = $factory->_create_instance();

        if ($factory->use_services &&
              $implementation->isa('Treex::Core::Service') &&
                !$implementation->ping()) {
            log_warn 'Service server ping is unvailable. Falling back to standard tool implementation.';
            $factory->_set_use_services(0); # Disable service
            $implementation = $factory->_create_instance(); # Create standard instanace for the tool
        }

        return $implementation;
    } else {
        confess('No implementation provided');
    }
}

sub _create_instance {
    my ($factory) = @_;

    my $iclass
      = $factory->_get_implementation_class(
          $factory->_implementation()
      );

    # pull in our implementation class
    $factory->_validate_implementation_class($iclass);

    my $iconstructor = $iclass->meta->constructor_name;

    my @args = (@{ $factory->_options },
                ($factory->use_services ?
                   ($factory->_get_service_attr => $factory->_implementation()) : ()));
    my $implementation
      = $iclass->$iconstructor($factory->use_services ? (args => {@args}) : @args);

    # TODO - should we sneak a factory attr onto the metaclass?
    return $implementation;

}

sub _get_implementation_class {
    my ($self, $impl) = @_;

    my $class = blessed $self;
    if ($self->meta->has_class_maker) {
        return $self->meta->implementation_class_maker->($impl, $self);
    } else {
        return $class . "::$impl";
    }
}

sub _get_service_attr {
    my ($self) = @_;

    if ($self->meta->has_service_attr) {
        return $self->meta->implementation_service_attr;
    } else {
        return 'class';
    }
}

sub _validate_implementation_class {
    my ($self, $iclass) = @_;

    try {
        # can we load the class?
        use_package_optimistically($iclass); # may die if user really stuffed up _get_implementation_class()

        if ($self->meta->has_implementation_roles) {
            my $roles = $self->meta->implementation_roles();

            # create an anon class that's a subclass of it
            my $anon = Moose::Meta::Class->create_anon_class();

            # make it a subclass of the implementation
            $anon->superclasses($iclass);

            # Lifted from MooseX::Recipe::Builder->_build_anon_meta()

            # load our role classes
            $roles->map( sub { use_package_optimistically($_); } );

            # apply roles to anon class
            if (scalar @{$roles} == 1) {
                $roles->[0]->meta->apply($anon);
            } else {
                Moose::Meta::Role->combine($roles->map(sub { $_->meta; } ))->apply($anon);
            }
        }
    } catch {
        confess "Invalid implementation class $iclass: $_";
    };

    return;
}

1;
__END__

=head1 NAME

Treex::Tool::Factory::Role - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Tool::Factory::Role;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Tool::Factory::Role,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
