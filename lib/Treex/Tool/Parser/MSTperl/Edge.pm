package Treex::Tool::Parser::MSTperl::Edge;

use Moose;

use Treex::Tool::Parser::MSTperl::Node;

has parent => (
    isa      => 'Treex::Tool::Parser::MSTperl::Node',
    is       => 'ro',
    required => 1,
);

has child => (
    isa      => 'Treex::Tool::Parser::MSTperl::Node',
    is       => 'ro',
    required => 1,
);

has first => (
    isa => 'Treex::Tool::Parser::MSTperl::Node',
    is  => 'rw',
);

has second => (
    isa => 'Treex::Tool::Parser::MSTperl::Node',
    is  => 'rw',
);

has sentence => (
    isa      => 'Treex::Tool::Parser::MSTperl::Sentence',
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

sub BUILD {
    my ($self) = @_;

    # parent precedes child
    if ( $self->parent->ord < $self->child->ord ) {
        $self->first( $self->parent );
        $self->second( $self->child );

        # parent follows child
    } else {
        $self->first( $self->child );
        $self->second( $self->parent );
    }

    return;    # only technical
}

sub signature {
    my ($self) = @_;
    return
        $self->sentence->id .
        '#' . $self->parent->ord .
        '#' . $self->child->ord;
}

1;

__END__

=head1 NAME

Treex::Tool::Parser::MSTperl::Edge

=head1 DESCRIPTION

Represents a dependency edge (i.e. a pair of nodes where one of them
is a parent to the other one which is its child).

=head1 FIELDS

=over 4

=item child

The child (dependent) node (L<Treex::Tool::Parser::MSTperl::Node>) of the edge.

=item parent

The parent (governing, head) node of the edge.

=item first

The one of C<child> and C<parent> which comes first in the sentence 
(L<Treex::Tool::Parser::MSTperl::Node/ord).

Filled automatically when edge is created.

=item second

The one of C<child> and C<parent> which comes second in the sentence 
(i.e. the one which is not in the C<first> field).

Filled automatically when edge is created.

=item sentence

The sentence (L<Treex::Tool::Parser::MSTperl::Sentence>) which contains
the nodes (C<child> and C<parent>).

=back

=head1 METHODS

=over 4

=item my $edge = Treex::Tool::Parser::MSTperl::Edge->new(
    child    => $node,
    parent   => $parent_node,
    sentence => $self
);

=item my $edge_signature = $edge->signature()

String uniquely identifying the edge, composed of sentence C<id> 
(L<Treex::Tool::Parser::MSTperl::Sentence/id>) and C<ord>s of the edge nodes 
(L<Treex::Tool::Parser::MSTperl::Node/ord>). Used to identify the edge
in the edge features 
cache (L<Treex::Tool::Parser::MSTperl::FeaturesControl/edge_features_cache>).

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
