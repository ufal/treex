package Treex::Block::Test::ParameterCanHaveWideChars;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'problematic_attribute' => ( is => 'rw', isa => 'Str', default => "no wide chars as default but they can be set in scenario" );

sub BUILD {
    my $self = shift;
    log_info("ParameterCanHaveWideChars loaded, problematic_attribute=" . $self->problematic_attribute);
}

sub process_document {
    my $self = shift;
    log_info("ParameterCanHaveWideChars executed, problematic_attribute=" . $self->problematic_attribute);
}

1;
