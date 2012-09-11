package Treex::Block::W2A::EN::ParseFanse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::Fanse;

#has model     => ( is => 'ro', isa => 'Str',  default => 'en' );
has fill_tags => ( is => 'ro', isa => 'Bool', default => 0 );

#TODO: shared parser for more instances only if they share the same model
my $parser;

sub BUILD {
    my ($self) = @_;
    if ( !$parser ) {
        $parser = Treex::Tool::Parser::Fanse->new();
    }
    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;
    my @forms = map { $_->form } @a_nodes;

    # the actual parsing
    my ( $parents_rf, $deprel_rf, $tags_rf ) = $parser->parse( \@forms );

    # build a-tree
    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $deprel = shift @$deprel_rf;
        $a_node->set_conll_deprel($deprel);

        my $parent_index = shift @$parents_rf;
        if ($parent_index) {
            my $parent = $a_nodes[ $parent_index - 1 ];
            $a_node->set_parent($parent);
        }
        else {
            push @roots, $a_node;
        }

        if ( $self->fill_tags ) {
            $a_node->set_tag( shift @$tags_rf );
        }
    }
    return @roots;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::EN::ParseFanse

=head1 DECRIPTION

FANSEParser (Stephen Tratz and Eduard Hovy, 2011,
see http://www.isi.edu/publications/licensed-sw/fanseparser)
is used to determine the topology of a-layer trees and I<deprel> edge labels.
It can be used also to determine POS tags.

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
