package Treex::Core::Node::A;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';
with 'Treex::Core::Node::Ordered';
with 'Treex::Core::Node::InClause';
with 'Treex::Core::Node::EffectiveRelations';
with 'Treex::Core::Node::Interset';

# _set_n_node is called only from Treex::Core::Node::N
# (automatically, when a new n-node is added to the n-tree).
has 'n_node' => ( is => 'ro', writer => '_set_n_node', );

# Original w-layer and m-layer attributes
has [qw(form lemma tag no_space_after)] => ( is => 'rw' );

# Original a-layer attributes
has [
    qw(afun is_parenthesis_root edge_to_collapse is_auxiliary)
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

#------------------------------------------------------------------------------
# Figures out the real function of the subtree. If its own afun is AuxP or
# AuxC, finds the first descendant with a real afun and returns it. If this is
# a coordination or apposition root, finds the first member and returns its
# afun (but note that members of the same coordination can differ in afuns if
# some of them have 'ExD').
#------------------------------------------------------------------------------
sub get_real_afun
{
    my $self = shift;
    my $warnings = shift;
    my $afun = $self->afun(); $afun = '' if(!defined($afun));
    if($afun =~ m/^Aux[PC]$/)
    {
        my @children = $self->children();
        my $n = scalar(@children);
        if($n<1)
        {
            if($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position()+1; # tred numbers from 1
                my $form = $self->form();
                log_warn("$afun node does not have children (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            if($n>1 && $warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position()+1; # tred numbers from 1
                my $form = $self->form();
                log_warn("$afun node has $n children so it is not clear which one bears the real afun (sentence $i_sentence, '$form')");
            }
            return $children[0]->get_real_afun();
        }
    }
    elsif($self->is_coap_root())
    {
        my @members = $self->get_coap_members();
        my $n = scalar(@members);
        if($n<1)
        {
            if($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position()+1; # tred numbers from 1
                my $form = $self->form();
                log_warn("$afun does not have members (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            return $members[0]->get_real_afun();
        }
    }
    return $afun;
}

#------------------------------------------------------------------------------
# Sets the real function of the subtree. If its current afun is AuxP or AuxC,
# finds the first descendant with a real afun replaces it. If this is
# a coordination or apposition root, finds all the members and replaces their
# afuns (but note that members of the same coordination can differ in afuns if
# some of them have 'ExD'; this method can only set the same afun for all).
#------------------------------------------------------------------------------
sub set_real_afun
{
    my $self = shift;
    my $new_afun = shift;
    my $warnings = shift;
    my $afun = $self->afun(); $afun = '' if(!defined($afun));
    if($afun =~ m/^Aux[PC]$/)
    {
        my @children = $self->children();
        my $n = scalar(@children);
        if($n<1)
        {
            if($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position()+1; # tred numbers from 1
                my $form = $self->form();
                log_warn("$afun node does not have children (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            if($warnings && $n>1)
            {
                my $i_sentence = $self->get_bundle()->get_position()+1; # tred numbers from 1
                my $form = $self->form();
                log_warn("$afun node has $n children so it is not clear which one bears the real afun (sentence $i_sentence, '$form')");
            }
            foreach my $child (@children)
            {
                $child->set_real_afun($new_afun);
            }
            return;
        }
    }
    elsif($self->is_coap_root())
    {
        my @members = $self->get_coap_members();
        my $n = scalar(@members);
        if($n<1)
        {
            if($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position()+1; # tred numbers from 1
                my $form = $self->form();
                log_warn("$afun does not have members (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            foreach my $member (@members)
            {
                $member->set_real_afun($new_afun);
            }
            return;
        }
    }
    $self->set_afun($new_afun);
    return $afun;
}

#------------------------------------------------------------------------------
# Recursively copy children from myself to another node.
# This function is specific to the A layer because it contains the list of
# attributes. If we could figure out the list automatically, the function would
# become general enough to reside directly in Node.pm.
#------------------------------------------------------------------------------
sub copy_atree
{
    my $self = shift;
    my $target = shift;
    my @children0 = $self->get_children({ordered => 1});
    foreach my $child0 (@children0)
    {
        # Create a copy of the child node.
        my $child1 = $target->create_child();
        # We should copy all attributes that the node has but it is not easy to figure out which these are.
        # As a workaround, we list the attributes here directly.
        foreach my $attribute ('form', 'lemma', 'tag', 'no_space_after', 'ord', 'afun', 'is_member', 'is_parenthesis_root',
                               'conll/deprel', 'conll/cpos', 'conll/pos', 'conll/feat')
        {
            my $value = $child0->get_attr($attribute);
            $child1->set_attr($attribute, $value);
        }
        # Call recursively on the subtrees of the children.
        $child0->copy_atree($child1);
    }
}

# -- linking to p-layer --

sub get_terminal_pnode {
    my ($self) = @_;
    my $document = $self->get_document();
    if ( $self->get_attr('p-terminal.rf') ) {
        return $document->get_node_by_id( $self->get_attr('p-terminal.rf') );
    }
    else {
        log_fatal('SEnglishA node pointing to no SEnglishP node');
    }
}

sub get_nonterminal_pnodes {
    my ($self) = @_;
    my $document = $self->get_document();
    my @nonterminals = ();
    if ( $self->get_attr('p-terminal.rf') ) {
        my $node = $document->get_node_by_id($self->get_attr('p-terminal.rf'));
        while ($node->get_attr('is_head')) {
            $node = $node->get_parent();
            push @nonterminals, $node
        }
    }
    return @nonterminals;
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

# Used only for reading from PCEDT/PDT trees, so far.
sub get_subtree_string {
    my ($self) = @_;
    return join '', map { $_->form . ( $_->no_space_after ? '' : ' ' ) } $self->get_descendants( { ordered => 1 } );
}

#----------- CoNLL attributes -------------

sub conll_deprel { return $_[0]->get_attr('conll/deprel'); }
sub conll_cpos   { return $_[0]->get_attr('conll/cpos'); }
sub conll_pos    { return $_[0]->get_attr('conll/pos'); }
sub conll_feat   { return $_[0]->get_attr('conll/feat'); }

sub set_conll_deprel { return $_[0]->set_attr( 'conll/deprel', $_[1] ); }
sub set_conll_cpos   { return $_[0]->set_attr( 'conll/cpos',   $_[1] ); }
sub set_conll_pos    { return $_[0]->set_attr( 'conll/pos',    $_[1] ); }
sub set_conll_feat   { return $_[0]->set_attr( 'conll/feat',   $_[1] ); }

1;

__END__

######## QUESTIONABLE / DEPRECATED METHODS ###########


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


=encoding utf-8

=head1 NAME

Treex::Core::Node::A

=head1 DESCRIPTION

a-layer (analytical) node

=head1 METHODS

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
(C<a-root.type>, C<a-node.type>)

=item is_coap_root

Is this node a root (or head) of a coordination/apposition construction?
On a-layer this is decided based on C<afun =~ /^(Coord|Apos)$/>.

=item get_real_afun()

Figures out the real function of the subtree. If its own afun is C<AuxP> or
C<AuxC>, finds the first descendant with a real afun and returns it. If this is
a coordination or apposition root, finds the first member and returns its
afun (but note that members of the same coordination can differ in afuns if
some of them have C<ExD>).

=item set_real_afun($new_afun)

Sets the real function of the subtree. If its current afun is C<AuxP> or C<AuxC>,
finds the first descendant with a real afun replaces it. If this is
a coordination or apposition root, finds all the members and replaces their
afuns (but note that members of the same coordination can differ in afuns if
some of them have C<ExD>; this method can only set the same afun for all).

=item copy_atree()

Recursively copy children from myself to another node.
This method is specific to the A layer because it contains the list of
attributes. If we could figure out the list automatically, the method would
become general enough to reside directly in Node.pm.

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

=item $node->get_subtree_string

Return the string coresponding to a subtree rooted in C<$node>.
It's computed based on attributes C<form> and C<no_space_after>.

=back


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
