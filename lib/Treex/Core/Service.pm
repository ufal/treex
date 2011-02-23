package Treex::Core::Service;
use Moose;
use Treex::Core::Config;

# 'instance' should be called instead of 'new': it allows to reuse already initilized services
sub instance {
    my ($self, $arg_ref) = @_;

    my $new_service = $class->new(@_);

    my $existing_service = $Treex::Core::Config::service->{$new_service->name};

    return $existing_service || $new_service;

}

# 'initialize' should be used instead of 'BUILD'
sub initialize {
    my ($self,$arg_ref) = shift;
    log_warn 'Missing method "initialize" in ' .ref($self);
}


sub name {
    my ($self,$arg_ref) = shift;
    return __PACKAGE__;
}

# unified interface to all services: one input hashref, one output hashref
sub process {
    my ($self,$arg_ref) = @_;
    return {};
}




1;

__END__

