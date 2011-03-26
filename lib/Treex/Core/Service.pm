package Treex::Core::Service;

use Treex::Core::Log;
use Moose;

my %registered_service;    # probably will be moved to some ServiceManager in the future

sub BUILD {
    my $self = shift;
    return;
}

# 'instance' should be called instead of 'new': it allows to reuse already initilized services
sub instance {
    my ( $class, $arg_ref ) = @_;

    my $new_service = $class->new( @_[ 1 .. $#_ ] );

    my $existing_service = $registered_service{ $new_service->name };

    return $existing_service if defined $existing_service;

    $new_service->initialize(@_);
    $registered_service{ $new_service->name } = $new_service;
    return $new_service;

}

# 'initialize' should be used instead of 'BUILD'
sub initialize {
    my ( $self, $arg_ref ) = shift;

    #    log_info 'Method initialize is supposed to be redeclared in ' .ref($self);
    return;
}

sub name {
    my ($self) = shift;

    # concatenating underscores are ugly, but can service names contain spaces (e.g. in soap)?
    return join "_",
        ( __PACKAGE__,
        map {"$_=$self->{$_}"} sort grep { !/^_/ } keys %{$self}
        );
}

# unified interface to all services: one input hashref, one output hashref
sub process {
    my ( $self, $arg_ref ) = @_;
    log_warn "No action defined for this service";
    return {};
}

1;

__END__

=for Pod::Coverage BUILD

=head1 NAME

Treex::Core::Service

=head1 DESCRIPTION

Service.pm
