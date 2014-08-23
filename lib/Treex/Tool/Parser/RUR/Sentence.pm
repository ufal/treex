package Treex::Tool::Parser::RUR::Sentence;

use Moose;

use Treex::Tool::Parser::RUR::Node;
use Treex::Tool::Parser::RUR::RootNode;

has config => (
    isa      => 'Treex::Tool::Parser::RUR::Config',
    is       => 'ro',
    required => '1',
);

# unique for each sentence, where sentence means sequence of words
# (i.e. stays the same for copies of the same sentence)
# needed for caching of features when training the parser
# (can be undef if not needed)
has id => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

has nodes => (
    is       => 'rw',
    isa      => 'ArrayRef[Treex::Tool::Parser::RUR::Node]',
    required => 1,
);

# root node added
has nodes_with_root => (
    is  => 'rw',
    isa => 'ArrayRef[Treex::Tool::Parser::RUR::Node]',
);

# used only in unlabelled parsing
has features => (
    is  => 'rw',
    isa => 'Maybe[ArrayRef[Str]]',
);

# TODO
# has betweenFeatureValues => (
#     isa      => 'HashRef',
#     is       => 'rw',
#     default => sub { {} },
# );

has edges => (
    is  => 'rw',
    isa => 'Maybe[ArrayRef[Treex::Tool::Parser::RUR::Edge]]',
);

sub BUILD {
    my ($self) = @_;

    #add root
    my $root = Treex::Tool::Parser::RUR::RootNode->new(
        fields => $self->config->root_field_values,
        config => $self->config
    );
    my @nodes_with_root;
    push @nodes_with_root, $root;
    push @nodes_with_root, @{ $self->nodes };
    $self->nodes_with_root( [@nodes_with_root] );

    # fill node ords
    my $ord = 1;
    foreach my $node ( @{ $self->nodes } ) {
        $node->ord($ord);
        $ord++;
    }

    return;
}

sub fill_fields_after_parse {

    my ($self) = @_;

    #compute edges
    $self->compute_edges();

    #compute features
    $self->compute_features( $self->config->unlabelledFeaturesControl );

    return;
}

sub fill_fields_before_labelling {

    my ($self) = @_;

    if ( $self->config->DEBUG >= 3 ) {
        print $self->id . " fill_fields_before_labelling()\n";
    }

    #compute edges
    $self->compute_edges();

    #compute features
    $self->compute_features( $self->config->labelledFeaturesControl );

    return;
}

# sub fill_fields_after_labelling {
#
#     my ($self) = @_;
#
#     seems there is nothing to compute here
#     (provided that the labels are somewhat extra,
#      i.e. not part of the feature values)
#
#     return;
# }

# compute node parents and the array of edges
# used both in fill_fields_after_parse and fill_fields_before_labelling methods
sub compute_edges {
    my ($self) = @_;

    my @edges;
    foreach my $node ( @{ $self->nodes } ) {

        # fill node parent
        # (it can be set either in parent or in parentOrd field)
        if ( $node->parent ) {
            $node->parentOrd( $node->parent->ord );
        } else {    # $node->parentOrd
            $node->parent( $self->getNodeByOrd( $node->parentOrd ) );
        }

        if ( $self->config->DEBUG >= 3 ) {
            print $node->parentOrd
                . '(' . $node->parent->fields->[1] . ')'
                . ' -> '
                . $node->ord
                . '(' . $node->fields->[1] . ')'
                . "\n";
        }

        # add a new edge
        my $edge = Treex::Tool::Parser::RUR::Edge->new(
            child    => $node,
            parent   => $node->parent,
            sentence => $self
        );
        push @edges, $edge;

        # add edge to the parent's list of children
        push @{ $node->parent->children }, $edge;

    }
    $self->edges( [@edges] );

    return;
}

# compute edge features and join them into sentence features
sub compute_features {

    my ( $self, $featuresControl ) = @_;

    my @features;
    foreach my $edge ( @{ $self->edges } ) {
        my $edge_features;
        my $ALGORITHM = $self->config->labeller_algorithm;
        if ( $ALGORITHM < 20 ) {
            $edge_features = $featuresControl->get_all_features($edge);
        } else {
            $edge_features = $featuresControl->get_all_features( $edge, -1 );
        }
        $edge->features($edge_features);
        push @features, @{$edge_features};
    }

    # (TODO) used only in unlabelled parsing
    $self->features( [@features] );

    return;
}

sub clear_parse {
    my ($self) = @_;

    #clear node parents and labels
    foreach my $node ( @{ $self->nodes } ) {
        $node->parent(undef);
        $node->parentOrd(0);
        $node->label('_');
    }

    #clear edges
    $self->edges(undef);

    #clear features
    $self->features(undef);

    return;
}

sub copy_nonparsed {
    my ($self) = @_;

    #copy nodes
    my @nodes;
    foreach my $node ( @{ $self->nodes } ) {
        my $node_copy = $node->copy_nonparsed();
        push @nodes, $node_copy;
    }

    #create a new instance
    my $copy = Treex::Tool::Parser::RUR::Sentence->new(

        # TODO: maybe should get a different ID for the sake of labelling
        # (but this is curently not used anyway)
        id     => $self->id,
        nodes  => [@nodes],
        config => $self->config,
    );

    return $copy;
}

sub copy_nonlabelled {
    my ($self) = @_;

    #copy nodes
    my @nodes;
    foreach my $node ( @{ $self->nodes } ) {
        my $node_copy = $node->copy_nonlabelled();
        push @nodes, $node_copy;
    }

    #create a new instance
    my $copy = Treex::Tool::Parser::RUR::Sentence->new(

        # TODO: maybe should get a different ID for the sake of labelling
        # (but this is curently not used anyway)
        id     => $self->id,
        nodes  => [@nodes],
        config => $self->config,
    );

    return $copy;
}

sub setChildParent {

    # (Int $childOrd, Int $parentOrd)
    my ( $self, $childOrd, $parentOrd ) = @_;

    my $child  = $self->getNodeByOrd($childOrd);
    my $parent = $self->getNodeByOrd($parentOrd);

    $child->parent($parent);

    return;
}

sub len {
    my ($self) = @_;
    return scalar( @{ $self->nodes } )
}

sub getNodeByOrd {

    # (Int $ord)
    my ( $self, $ord ) = @_;

    if ( $ord >= 0 && $ord <= $self->len() ) {
        return $self->nodes_with_root->[$ord];
    } else {
        return;    # undef
    }
}

sub count_errors_attachement {

    # (Treex::Tool::Parser::RUR::Sentence $correct_sentence)
    my ( $self, $correct_sentence ) = @_;

    my $errors = 0;

    #assert that nodes in the sentences with the same ords
    # are corresponding nodes
    foreach my $my_node ( @{ $self->nodes } ) {
        my $my_parent      = $my_node->parentOrd;
        my $correct_node   = $correct_sentence->getNodeByOrd( $my_node->ord );
        my $correct_parent = $correct_node->parentOrd;
        if ( $my_parent != $correct_parent ) {
            if ( $self->config->lossFunction ) {
                $errors +=
                    $self->attachement_error(
                    $my_node, $my_node->parent, $correct_node->parent
                    );
            }
            else {
                $errors++;
            }
        }
    }

    return $errors;
}

sub attachement_error {
    my ( $self, $node, $assignedParent, $correctParent ) = @_;

    # TODO how do the undefines happen?
    # they only seem to occur during testing, not during training
    return 1 if ( !defined $assignedParent || !defined $correctParent );

    my $error = 1;

    my $lossFunction = $self->config->lossFunction;

    if ( $lossFunction eq 'J' ) {
        if ( defined $correctParent ) {
            if ( $correctParent->fields->[4] =~ /^J/ ) {
                $error = 10;
            }
        }
    }
    elsif ( $lossFunction eq 'A' ) {
        if ( $node->fields->[4] =~ /^A/ ) {
            $error = 10;
        }
    }
    elsif ( $lossFunction eq 'NA' ) {
        if ( defined $correctParent ) {
            if ($node->fields->[4] =~ /^A/
                && $correctParent->fields->[4] =~ /^N/
                )
            {
                $error = 10;
            }
        }
    }
    elsif ( $lossFunction eq 'NA2' ) {

        # if the child is A
        if ( $node->fields->[4] =~ /^A/ ) {

            # and the assigned or correct parent is N
            if ( $correctParent->fields->[4] =~ /^N/ || $assignedParent->fields->[4] =~ /^N/ ) {
                $error = 10;
            }
        }
    }
    elsif ( $lossFunction eq 'JNA' ) {
        if ( defined $correctParent ) {
            if ($node->fields->[4] =~ /^A/
                &&
                (
                    $correctParent->fields->[4] =~ /^N/
                    || $correctParent->fields->[4] =~ /^J/
                )
                )
            {
                $error = 10;
            }
        }
    }
    elsif ( $lossFunction eq 'NR2' ) {

        # if the child is N
        if ( $node->fields->[4] =~ /^N/ ) {

            # and the assigned or correct parent is R
            if ( $correctParent->fields->[4] =~ /^R/ || $assignedParent->fields->[4] =~ /^R/ ) {
                $error = 10;
            }
        }
    }
    elsif ( $lossFunction eq 'JNR2' ) {

        # if the child is N or J
        if ( $node->fields->[4] =~ /^[NJ]/ ) {

            # and the assigned or correct parent is R
            if ( $correctParent->fields->[4] =~ /^R/ || $assignedParent->fields->[4] =~ /^R/ ) {
                $error = 10;
            }
        }
    }
    elsif ( $lossFunction eq 'J2' ) {

        # if the assigned or correct parent is J
        if ( $correctParent->fields->[4] =~ /^J/ || $assignedParent->fields->[4] =~ /^J/ ) {
            $error = 10;
        }
    }

    return $error;
}

sub count_errors_labelling {

    # (Treex::Tool::Parser::RUR::Sentence $correct_sentence)
    my ( $self, $correct_sentence ) = @_;

    my $errors = 0;

    my @correct_labels =
        map { $_->label } @{ $correct_sentence->nodes };
    my @my_labels =
        map { $_->label } @{ $self->nodes };
    for ( my $i = 0; $i < @correct_labels; $i++ ) {
        if ( $correct_labels[$i] ne $my_labels[$i] ) {
            $errors++;
        }
    }

    return $errors;
}

sub count_errors_attachement_and_labelling {

    # (Treex::Tool::Parser::RUR::Sentence $correct_sentence)
    my ( $self, $correct_sentence ) = @_;

    my $errors = 0;

    #assert that nodes in the sentences with the same ords
    # are corresponding nodes
    foreach my $my_node ( @{ $self->nodes } ) {
        my $my_parent      = $my_node->parentOrd;
        my $my_label       = $my_node->label;
        my $correct_node   = $correct_sentence->getNodeByOrd( $my_node->ord );
        my $correct_parent = $correct_node->parentOrd;
        my $correct_label  = $correct_node->label;
        if ( $my_parent != $correct_parent || $my_label ne $correct_label ) {
            $errors++;
        }
    }

    return $errors;
}

sub toParentOrdsArray {
    my ($self) = @_;

    my @parents;
    foreach my $node ( @{ $self->nodes } ) {
        push @parents, $node->parentOrd;
    }

    return [@parents];
}

sub toLabelsArray {
    my ($self) = @_;

    my @labels;
    foreach my $node ( @{ $self->nodes } ) {
        push @labels, $node->label;
    }

    return [@labels];
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::RUR::Sentence

=head1 DESCRIPTION

Represents a sentence, both parsed an unparsed.
Contains an array of nodes which represent the words in the sentence.

The nodes are ordered, their C<ord> is their 1-based position in the sentence.
The C<0 ord> value is reserved for the (technical) sentence root.

=head1 FIELDS

=over 4

=item id (Int)

An integer id unique for each sentence (in its proper sense, where sentence
is a sequence of tokens - i.e. C<id> stays the same for copies of the same
sentence).

=item nodes (ArrayRef[Treex::Tool::Parser::RUR::Node])

(A reference to) an array of nodes (C<Treex::Tool::Parser::RUR::Node>) of
the sentence.

A node represents both a token of the sentence (usually this is a word) and a
node in the parse tree of the sentence as well (if the sentence have been
parsed).

=item nodes_with_root (ArrayRef[Treex::Tool::Parser::RUR::Node])

Copy of C<nodes> field with a root node
(L<Treex::Tool::Parser::RUR::RootNode>) added at the beginning. As the
root node's C<ord> is C<0> by definition, the position of the nodes in this
array exactly corresponds to its C<ord>.

=item edges (Maybe[ArrayRef[Treex::Tool::Parser::RUR::Edge]])

If the sentence is parsed (i.e. the nodes know their parents), this field
contains (a reference to) an array of all edges
(L<Treex::Tool::Parser::RUR::Edge>) in the parse tree of the sentence.

This field is set by the C<sub> C<fill_fields_after_parse>.

If the sentence is not parsed, this field is C<undef>.

=item features (Maybe[ArrayRef[Str]])

If the sentence is parsed, this field
contains (a reference to) an array of all features of all edges in the parse
tree of the sentence. If some of the features are repeated in the sentence
(i.e. they are present in severeal edges or even repeated in one edge), they
are repeated here as well, i.e. this is not a set in mathematical sense but a
(generally unordered) list.

This field is set by the C<sub> C<fill_fields_after_parse>.

If the sentence is not parsed, this field is C<undef>.

=back

=head1 METHODS

=head2 Constructor

=over 4

=item my $sentence = Treex::Tool::Parser::RUR::Sentence->new(
    id => 12, nodes => [$node1, $node2, $node3, ...]);

Creates a new sentence. The C<id> must be unique (but copies of the same
sentence are to share the same id). It is used for edge signature generation
(L<Treex::Tool::Parser::RUR::Edge/signature>) in edge features caching (and
therefore does not have to be set if caching is disabled).

The order of the nodes denotes their order in the sentence, starting from the
node with C<ord> 1, i.e. the technical root
(L<Treex::Tool::Parser::RUR::RootNode>) is not to be included as it is
generated automatically in the constructor.
The C<ord>s of the nodes (L<Treex::Tool::Parser::RUR::Node/ord>) do not
have to (and actually shouldn't) be filled in. If they are, they are checked
and a warning on STDERR is issued if they do not correspond to the position of
the nodes in the array. If they are not, they are filled in automatically
during the sentence creation.

Other fields (C<nodes_with_root>, C<edges> and C<features>) should usually not
be set. C<nodes_with_root> are set automatically during sentence creation (and
any value set to it is discarded). C<edges> and C<features> are to be set only
if the sentence is parsed (i.e. the nodes know their parents, see
L<Treex::Tool::Parser::RUR::Node/parent> and
L<Treex::Tool::Parser::RUR::Node/parentOrd>) by calling the
C<fill_fields_after_parse> method.

So, if the sentence is already parsed, you should call the
C<fill_fields_after_parse> method immediately after creaion of the sentence.

=item my $unparsed_sentence_copy = $sentence->copy_nonparsed();

Creates a new instance of the same sentence with the same C<id> and with
copies of the nodes but without any parsing information (like after calling
C<clear_parse>). The nodes are copied by calling
L<Treex::Tool::Parser::RUR::Node/copy_nonparsed>.

=back

=head2 Action methods

=over 4

=item $sentence->setChildParent(5, 3)

Sets the parent of the node with the first C<ord> to be the node with the second
C<ord> - eg. here, the 3rd node is the parent of the 5th node.
It only sets the C<parent> and C<parentOrd> fields in the child node
(i.e. it does not create or modify any edges).

When all nodes' parents have been set, C<fill_fields_after_parse> can be called.

=item $sentence->fill_fields_after_parse()

Fills the fields of the sentence and fields of its nodes which can be filled
only for a sentence that has already been parsed (i.e. if the nodes' C<parent>
or C<parentOrd> fields are filled).

The fields which are filled by this subroutine are C<edges> and C<features>
for the sentence and C<parent> or C<parentOrd> for each of the sentence nodes
which do not have the field set.

=item $sentence->clear_parse()

Is kind of an inversion of the C<fill_fields_after_parse> method. It clears
the C<edges> and C<features> fields and also unsets the parents of all nodes
(by setting their C<parent> field to C<undef> and C<parentOrd> to C<0>).

=back

=head2 Information methods

=over 4

=item $sentence->len()

Returns length of the sentence, i.e. number of nodes in the sentence.
Each node corresponds to one word (one token to be more precise).

=item $sentence->count_errors_attachement($correct_sentence)

Compares the parse tree of the sentence with its correct parse tree,
represented by an instance of the same sentence containing its correct parse.

An error is considered to be an incorrectly assigned governing node. So, the
parents of all nodes (obviously not including the root node) are compared and
if they are different, it is counted as an error. This leads to a minimum
number of errors equal to 0 and maximum number equal to the length of the
sentence.

=item $sentence->count_errors_labelling($correct_sentence)

Compares the labelling of the sentence with its correct labelling,
represented by an instance of the same sentence containing the correct labels.

An error is considered to be an incorrectly assigned label. So, the
labels of all edges (technically stored in the child nodes) are compared and
if they are different, it is counted as an error. This leads to a minimum
number of errors equal to 0 and maximum number equal to the length of the
sentence.

=item $sentence->getNodeByOrd(6)

Returns the node with this C<ord> (it can also be the root node if the C<ord>
is 0) or C<undef> if the C<ord> is out of range.

=item $sentence->toString()

Returns forms of the nodes joined by spaces (i.e. the sentence as a text but
with a space between each two adjacent tokens).

=item $sentence->toParentOrdsArray()

Returns (a reference to) an array of node parent ords, i.e. for the sentence
"Tom is big", where "is" is a child of the root node and "Tom" and "big" are
children of "is", this method returns C<[2, 0, 2]>.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
