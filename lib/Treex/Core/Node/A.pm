package Treex::Core::Node::A;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Node';
with 'Treex::Core::Node::Ordered';
with 'Treex::Core::Node::EffectiveRelations';

# _set_n_node is called only from Treex::Core::Node::N
# (automatically, when a new n-node is added to the n-tree).
has 'n_node' => ( is => 'ro', writer => '_set_n_node', );

# Original w-layer and m-layer attributes
has [qw(form lemma tag no_space_after)] => ( is => 'rw' );

# Original a-layer attributes
has [
    qw(afun is_member is_parenthesis_root conll_deprel
        edge_to_collapse is_auxiliary clause_number is_clause_head)
] => ( is => 'rw' );

sub get_pml_type_name {
    my ($self) = @_;
    return $self->is_root() ? 'a-root.type' : 'a-node.type';
}

# the node is a root of a coordination/apposition construction
sub is_coap_root {
    my ($self) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 1;
    return defined $self->afun && $self->afun =~ /^(Coord|Apos)$/;
}


# -- linking to p-layer --

sub get_terminal_pnode {
    my ($self) = @_;
    my $document = $self->get_document();
    if ( $self->get_attr('p/terminal.rf') ) {
        return $document->get_node_by_id( $self->get_attr('p/terminal.rf') );
    }
    else {
        log_fatal('SEnglishA node pointing to no SEnglishP node');
    }
}

sub get_nonterminal_pnodes {
    my ($self) = @_;
    my $document = $self->get_document();
    if ( $self->get_attr('p/nonterminals.rf') ) {
        return grep {$_} map { $document->get_node_by_id($_) } @{ $self->get_attr('p/nonterminals.rf') };
    }
    else {
        return ();
    }
}

sub get_pnodes {
    my ($self) = @_;
    return ( $self->get_terminal_pnode, $self->get_nonterminal_pnodes );
}

# -- other --

# Used only for Czech, so far.
sub reset_morphcat {
    my ($self) = @_;
    foreach my $category (
        qw(pos subpos gender number case possgender possnumber
        person tense grade negation voice reserve1 reserve2)
        )
    {
        my $old_value = $self->get_attr("morphcat/$category");
        if ( !defined $old_value ) {
            $self->set_attr( "morphcat/$category", '.' );
        }
    }
    return;
}

1;

__END__

######## QUESTIONABLE / DEPRECATED METHODS ###########

# If this should be part of API, it should be renamed to
# get_subtree_string (it is a whole sentence only if self==root)
sub get_sentence_string {
    my ($self) = @_;
    return join '', map { $_->form . ( $_->no_space_after ? '' : ' ' ) } $self->get_descendants( { ordered => 1 } );
}


# For backward compatibility with PDT-style
# TODO: This should be handled in format converters/Readers.
sub is_coap_member {
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    return (
        $self->is_member
            || ( ( $self->afun || '' ) =~ /^Aux[CP]$/ && grep { $_->is_coap_member } $self->get_children )
        )
        ? 1 : undef;
}

# deprecated, use get_coap_members
sub get_transitive_coap_members {    # analogy of PML_T::ExpandCoord
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    if ( $self->is_coap_root ) {
        return (
            map { $_->is_coap_root ? $_->get_transitive_coap_members : ($_) }
                grep { $_->is_coap_member } $self->get_children
        );
    }
    else {

        #log_warn("The node ".$self->get_attr('id')." is not root of a coordination/apposition construction\n");
        return ($self);
    }
}

# deprecated,  get_coap_members({direct_only})
sub get_direct_coap_members {
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    if ( $self->is_coap_root ) {
        return ( grep { $_->is_coap_member } $self->get_children );
    }
    else {

        #log_warn("The node ".$self->get_attr('id')." is not root of a coordination/apposition construction\n");
        return ($self);
    }
}

# too easy to implement and too rarely used to be a part of API
sub get_transitive_coap_root {    # analogy of PML_T::GetNearestNonMember
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    while ( $self->is_coap_member ) {
        $self = $self->get_parent;
    }
    return $self;
}


=head1 NAME

Treex::Core::Node::A

=head1 DESCRIPTION

Analytical node

=head1 METHODS

!!! missing description of

=over 4

=item is_coap_root
=item get_echildren
=item get_eparents
=item get_coap_members
=item is_coap_member
=item get_transitive_coap_members
=item get_direct_coap_members
=item get_transitive_coap_root

=back

=head2 Links from a-trees to phrase-structure trees

=over 4

=item $node->get_terminal_pnode

   Returns a terminal node from the phrase-structure tree
   that corresponds to the a-node.

=item $node->get_nonterminal_pnodes

   Returns an array of non-terminal nodes from the phrase-structure tree
   that correspond to the a-node.

=item $node->get_pnodes

   Returns the corresponding terminal node and all non-terminal nodes.

=back

=head2 Other

=over 4

=item reset_morphcat

=item get_pml_type_name

     Root and non-root nodes have different PML type in the pml schema
     (a-root.type, a-node.type)

=item get_mnode

   Obsolete, should be removed after merging m- and a-layer.

=item get_n_node()

 If this a-node is a part of a named entity,
 this method returns the corresponding n-node (L<Treex::Core::Node::N>).
 If this node is a part of more than one named entities,
 only the most nested one is returned.
 For example: "Bank of China"
 $n_node_for_china = $a_node_china->get_n_node();
 print $n_node_for_china->get_attr('normalized_name'); # China
 $n_node_for_bank_of_china = $n_node_for_china->get_parent();
 print $n_node_for_bank_of_china->get_attr('normalized_name'); # Bank of China 


=item $node->get_coap_members($arg_ref?)

If the node is a coordination/apposition head
(see L<is_coap_root()>) a list of all coordinated members is returned.
Otherwise, the node itself is returned. 

Options (using C<$arg_ref> hash):

=over

=item direct_only

In case of nested coordinations return only "first-level" members.
The default is to return I<transitive> members.
For example "(A and B) or C":
$or->get_coap_members();                 # returns A,B,C
$or->get_coap_members({direct_only=>1}); # returns and,C

=item dive=>$sub_ref

"Dive" through nodes for which the subroutine returns a true value.
Typically this is used for prepositions and subord. conjunctions.

=back

=back

=head1 COPYRIGHT

Copyright 2006-2009 Zdenek Zabokrtsky, Martin Popel.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
