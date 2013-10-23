package Treex::Block::W2A::JA::ParseJDEPP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::JDEPP;

# we use kyoto-partial model as a default model (installed as default during jdepp installation)
# other models should be trained through jdepp itself before use
has 'model_dir' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'data/models/parser/jdepp/kyoto-partial',
    documentation => 'path to the model relative to Treex resource_path',
);

has parser => ( is => 'rw' );

sub BUILD {
    my ($self)  = @_;

    return;
}

sub process_start {
    my ($self)  = @_;

    
    #TODO: Model dir must be set outside Treex, via Jdepp itself -> fix this in the future!
    my $model_dir = $self->require_files_from_share( $self->model_dir );

    my $parser = Treex::Tool::Parser::JDEPP->new( model_dir => $model_dir );
    $self->set_parser( $parser );

    $self->SUPER::process_start();

    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    my @words = map { $_->form } @a_nodes;
    my @tags  = map { $_->tag } @a_nodes;

    my ( $parents_rf ) = $self->parser->parse_sentence( \@words, \@tags );

    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $parent_index = shift @$parents_rf;
        if ($parent_index) {
            my $parent = $a_nodes[ $parent_index - 1 ];
            $a_node->set_parent($parent);
        }
        else {
            push @roots, $a_node;
        }
    }
    return @roots;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::ParseJDEPP

=head1 DECRIPTION

JDEPP parser is used to determine the topology of a-layer trees.

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

=head1 AUTHORS

Dusan Varis



