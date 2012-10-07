package Treex::Block::Test::FieldCanHaveWideChars;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'problematic_attribute' => ( is => 'rw', isa => 'Str', default => "žluťoučký" );

sub BUILD {
    my $self = shift;
    log_info("FieldCanHaveWideChars loaded, problematic_attribute=" . $self->problematic_attribute);
}

sub process_document {
    my $self = shift;
    log_info("FieldCanHaveWideChars executed, problematic_attribute=" . $self->problematic_attribute);
}

1;
