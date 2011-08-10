package Treex::Tool::Parser::Charniak::Node;

use Moose;

has term => (
    isa      => 'Str',
    is       => 'rw',
    required => 1,
    default  => 'null'
);

has children =>
    (
    isa     => 'ArrayRef',
    is      => 'rw',
    default => sub { [] },
    reader  => 'get_children',
    );

sub BUILD {
    my ( $self, $params ) = @_;
}

sub add_child {
    my ( $self, $child ) = @_;
    push @{ $self->children }, $child;
}

sub get_type {
    my ($self) = @_;
    return $self->{term};
}

1;
__END__


