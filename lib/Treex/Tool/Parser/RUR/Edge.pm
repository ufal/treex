package Treex::Tool::Parser::RUR::Edge;

use Moose;

use Treex::Tool::Parser::RUR::Node;

has config => (
    isa => 'Treex::Tool::Parser::RUR::Config',
    is  => 'rw',
);

has parent => (
    isa      => 'Treex::Tool::Parser::RUR::Node',
    is       => 'ro',
    required => 1,
);

has child => (
    isa      => 'Treex::Tool::Parser::RUR::Node',
    is       => 'ro',
    required => 1,
);

has first => (
    isa => 'Treex::Tool::Parser::RUR::Node',
    is  => 'rw',
);

has second => (
    isa => 'Treex::Tool::Parser::RUR::Node',
    is  => 'rw',
);

has sentence => (
    isa      => 'Treex::Tool::Parser::RUR::Sentence',
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

has features => (
    is  => 'rw',
    isa => 'Maybe[ArrayRef[Str]]',
);

sub BUILD {
    my ($self) = @_;

    if ( $self->parent->ord < $self->child->ord ) {

        # parent precedes child
        $self->first( $self->parent );
        $self->second( $self->child );

    } else {

        # parent follows child
        $self->first( $self->child );
        $self->second( $self->parent );
    }

    $self->config( $self->parent->config );

    return;
}

sub signature {
    my ($self) = @_;
    return
        $self->sentence->id .
        '#' . $self->parent->ord .
        '#' . $self->child->ord .
        '#' . $self->child->label;
}

# all features, including dynamic if applicable, for labelling only
sub features_all_labeller {
    my ($self) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM < 20 ) {
        return $self->features;
    } else {
        if ( keys %{ $self->config->labelledFeaturesControl->dynamic_features } ) {
            my @features = @{ $self->features };
            push @features,
                @{
                $self->config->labelledFeaturesControl->get_all_features(
                    $self, 1
                    )
                };
            return \@features;
        } else {
            return $self->features;
        }
    }
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::RUR::Edge

=head1 DESCRIPTION

Represents a dependency edge (i.e. a pair of nodes where one of them
is a parent to the other one which is its child).

=head1 FIELDS

=over 4

=item child

The child (dependent) node (L<Treex::Tool::Parser::RUR::Node>) of the edge.

=item parent

The parent (governing, head) node of the edge.

=item first

The one of C<child> and C<parent> which comes first in the sentence
(L<Treex::Tool::Parser::RUR::Node/ord>).

Filled automatically when edge is created.

=item second

The one of C<child> and C<parent> which comes second in the sentence
(i.e. the one which is not in the C<first> field)

Filled automatically when edge is created.

=item sentence

The sentence (L<Treex::Tool::Parser::RUR::Sentence>) which contains
the nodes (C<child> and C<parent>).

=back

=head1 METHODS

=over 4

=item my $edge = Treex::Tool::Parser::RUR::Edge->new(
    child    => $child_node,
    parent   => $parent_node,
    sentence => $sentence,
);

Initializes an instance of an edge between the C<child> node
and the C<parent> node
(instances of L<Treex::Tool::Parser::RUR::Node>)
in the given C<sentence> (L<Treex::Tool::Parser::RUR::Sentence>).

=item my $edge_signature = $edge->signature()

String uniquely identifying the edge, composed of sentence C<id>
(L<Treex::Tool::Parser::RUR::Sentence/id>), C<ord>s of the edge nodes
(L<Treex::Tool::Parser::RUR::Node/ord>)
and label of the edge (which is stored with the child node -
L<Treex::Tool::Parser::RUR::Node/label>).
Used to identify the edge
in the edge features
cache (L<Treex::Tool::Parser::RUR::FeaturesControl/edge_features_cache>).

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
