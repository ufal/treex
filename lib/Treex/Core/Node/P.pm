package Treex::Core::Node::P;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';

# dirty: merging terminal and nonterminal nodes' attributes

# common:
has [qw(is_head index coindex edgelabel)] => ( is => 'rw' );

# terminal specific
has [qw(form lemma tag)] => ( is => 'rw' );

# non-terminal specific
has [qw( phrase functions )] => ( is => 'rw' );

sub get_pml_type_name {
    my ($self) = @_;

    if ( $self->is_root() or $self->phrase ) {
        return 'p-nonterminal.type';
    }
    elsif ( $self->tag ) {
        return 'p-terminal.type';
    }
    else {
        return;
    }
}

# Nodes on the p-layer have no ordering attribute.
# (It is not needed, trees are projective,
#  the order is implied by the ordering of siblings.)
override 'get_ordering_value' => sub {
    my ($self) = @_;
    return;
};

sub is_terminal {
  my $self = shift @_;
  return $self->get_pml_type_name eq 'p-terminal.type' ? 1 : 0;
}

sub create_nonterminal_child {
    my $self    = shift @_;
    my $fs_file = $self->get_bundle->get_document()->_pmldoc;
    my $child   = $self->create_child(@_);
    $child->set_type_by_name( $fs_file->metaData('schema'), 'p-nonterminal.type' );
    $child->{'#name'} = 'nonterminal';
    return $child;
}

sub create_terminal_child {
    my $self    = shift @_;
    my $fs_file = $self->get_bundle->get_document()->_pmldoc;
    my $child   = $self->create_child(@_);
    $child->set_type_by_name( $fs_file->metaData('schema'), 'p-terminal.type' );
    $child->{'#name'} = 'terminal';
    return $child;
}

sub create_from_mrg {
    my ( $self, $mrg_string ) = @_;

    # normalize spaces
    $mrg_string =~ s/([()])/ $1 /g;
    $mrg_string =~ s/\s+/ /g;
    $mrg_string =~ s/^ //g;
    $mrg_string =~ s/ $//g;

    # remove back brackets (except for round)
    $mrg_string =~ s/-LSB-/\[/g;
    $mrg_string =~ s/-RSB-/\]/g;
    $mrg_string =~ s/-LCB-/\{/g;
    $mrg_string =~ s/-RCB-/\}/g;

    # remove extra outer parenthesis
    $mrg_string =~ s/^\( (\(.+) \)$/$1/;

    # remove one extra non-terminal (ROOT comes from Stanford, S1 comes from Charniak parser)
    $mrg_string =~ s/^\( (ROOT|S1) (.+) \)$/$2/g;
    my @tokens = split / /, $mrg_string;

    $self->_parse_mrg_nonterminal( \@tokens );
    return;
}

sub _reduce {
    my ( $self, $tokens_rf, $expected_token ) = @_;
    if ( $tokens_rf->[0] eq $expected_token ) {
        return shift @{$tokens_rf};
    }
    else {
        log_fatal "Unparsable mrg remainder: '$expected_token' is not at the beginning of: "
            . join( " ", @$tokens_rf );
    }
}

sub _parse_mrg_nonterminal {
    my ( $self, $tokens_rf ) = @_;
    $self->_reduce( $tokens_rf, "(" );

    # phrase type and (optionally) a list of grammatical functions
    my $label = shift @{$tokens_rf};
    my @label_components = split /-/, $label;
    $self->set_phrase( shift @label_components );

    # TODO: handle traces correctly
    # Delete trace indices (e.g. NP-SBJ-10 ... -NONE- *T*-10)
    @label_components = grep { !/^\d+$/ } @label_components;

    if (@label_components) {
        $self->set_functions( \@label_components );
    }

    while ( $tokens_rf->[0] eq "(" ) {
        if ( $tokens_rf->[2] eq "(" ) {
            my $new_nonterminal = $self->create_nonterminal_child();
            $new_nonterminal->_parse_mrg_nonterminal($tokens_rf);
        }
        else {
            my $new_terminal_child = $self->create_terminal_child();
            $new_terminal_child->_parse_mrg_terminal($tokens_rf);
        }
    }

    $self->_reduce( $tokens_rf, ")" );
    return;
}

sub _parse_mrg_terminal {
    my ( $self, $tokens_rf ) = @_;
    $self->_reduce( $tokens_rf, "(" );

    my $tag  = shift @{$tokens_rf};
    my $form = shift @{$tokens_rf};
    $form =~ s/-LRB-/\(/g;
    $form =~ s/-RRB-/\)/g;
    $self->set_form($form);
    $self->set_tag($tag);

    $self->_reduce( $tokens_rf, ")" );
    return;
}

sub stringify_as_mrg {
    my ($self) = @_;
    my $string;
    if ( $self->phrase ) {
        my @functions = $self->functions ? @{ $self->functions } : ();
        $string = join '-', $self->phrase, @functions;
        $string .= ' ';
    }
    else {
        my $tag  = defined $self->tag  ? $self->tag  : '?';
        my $form = defined $self->form ? $self->form : '?';
        $form =~ s/ /_/g;
        $string = "$tag $form";
        $string =~ s/\(/-LRB-/g;
        $string =~ s/\)/-RRB-/g;
    }
    if ( $self->children ) {
        $string .= join ' ', map { $_->stringify_as_mrg() } $self->children;
    }
    return "($string)";
}

sub stringify_as_text {
    my ($self) = @_;
    my @children = $self->get_children();
    return $self->form // '<?>' if !@children;
    return join ' ', map { $_->stringify_as_text() } @children;
}

#------------------------------------------------------------------------------
# Recursively copy children from myself to another node.
# This function is specific to the P layer because it contains the list of
# attributes. If we could figure out the list automatically, the function would
# become general enough to reside directly in Node.pm.
#------------------------------------------------------------------------------
sub copy_ptree
{
    my $self      = shift;
    my $target    = shift;

    # TODO probably we should do deepcopy
    my %copy_of_wild = %{$self->wild};
    $target->set_wild(\%copy_of_wild);

    my @children0 = $self->get_children();
    foreach my $child0 (@children0)
    {

        # Create a copy of the child node.
        my $child1 = $child0->is_leaf() ? $target->create_terminal_child() : $target->create_nonterminal_child();

        # We should copy all attributes that the node has but it is not easy to figure out which these are.
        # TODO: As a workaround, we list the attributes here directly.
        foreach my $attribute (
            'form', 'lemma', 'tag', # terminal
            'phrase', 'functions', # nonterminal
            'edgelabel', 'is_head', 'index', 'coindex' # common
            )
        {
            my $value = $child0->get_attr($attribute);
            $child1->set_attr( $attribute, $value );
        }

        # TODO probably we should do deepcopy
        %copy_of_wild = %{$child0->wild};
        $child1->set_wild(\%copy_of_wild);

        # Call recursively on the subtrees of the children.
        $child0->copy_ptree($child1);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Node::P

=head1 DESCRIPTION

Representation of nodes of phrase structure (constituency) trees.

=head1 METHODS

=head2 $node->is_terminal()

Is C<$node> a terminal node?
Does its C<get_pml_type_name eq 'p-terminal.type'>?

=head2 my $child_phrase = $node->create_nonterminal_child()

Create a new non-terminal child node,
i.e. a node representing a constituent (phrase). 

=head2 my $child_terminal = $node->create_terminal_child()

Create a new terminal child node,
i.e. a node representing a token. 

=head2 my $node->create_from_mrg($mrg_string)

Fill C<$node>'s attributes and create its subtree
from the serialized string in the PennTB C<mrg> format.
E.g.: I<(NP (DT a) (JJ nonexecutive) (NN director))>.

=head2 my $mrg_string = $node->stringify_as_mrg()

Serialize the tree structure of C<$node> and its subtree
as a string in the PennTB C<mrg> format.
E.g.: I<(NP (DT a) (JJ nonexecutive) (NN director))>.

=head2 my $tokenized_text = $node->stringify_as_text()

Get the text representing C<$node>'s subtree.
The text is tokenized, i.e. all tokens are separated by a space.

=head2 $node->copy_ptree($target_node)

Recursively copy children from C<$node> to C<$target_node>.
This method is specific to the P layer because it contains the list of
attributes. If we could figure out the list automatically, the method would
become general enough to reside directly in Node.pm.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>
Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>
Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
