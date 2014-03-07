package Treex::Block::SemevalABSA::KnownAspect;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

has aspects => (
    isa => 'HashRef',
    is  => 'rw',
);

has aspect_file => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
);

sub BUILD {
    my ( $self ) = @_;
    open( my $hdl, $self->{aspect_file} ) or log_fatal "$self->{aspect_file}: $!";
    while (<$hdl>) {
        chomp;
        $self->{aspects}->{$_} = 1;
    }
    close $hdl;
    return 1;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @nodes = $atree->get_descendants;
    for my $node ( @nodes ) {
        if ( $self->{aspects}->{ lc( $node->form ) }
            && ! $self->is_aspect_candidate( $node ) ) {
            $self->mark_node( "known0" );
        }
    }

    return 1;
}

1;
