package Treex::Core::Node::A;

use namespace::autoclean;
use Moose;
use Treex::Core::Common;
use Storable;
extends 'Treex::Core::Node';
with 'Treex::Core::Node::Ordered';
with 'Treex::Core::Node::InClause';
with 'Treex::Core::Node::EffectiveRelations';
with 'Treex::Core::Node::Interset' => { interset_attribute => 'iset' };

# Original w-layer and m-layer attributes
has [qw(form lemma tag no_space_after)] => ( is => 'rw' );

# Original a-layer attributes
# (Only afun and is_parenthesis_root originate from PDT, the rest was added in Treex).
has [
    qw(deprel afun is_parenthesis_root edge_to_collapse is_auxiliary translit gloss)
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

sub n_node {
    my ($self)         = @_;
    my ($first_n_node) = $self->get_referencing_nodes('a.rf');
    return $first_n_node;
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
    my $self     = shift;
    my $warnings = shift;
    my $afun     = $self->afun();
    if ( not defined($afun) ) {
        $afun = '';
    }
    if ( $afun =~ m/^Aux[PC]$/ )
    {
        my @children = $self->children();
        # Exclude punctuation children (afun-wise, not POS-tag-wise: we do not want to exclude coordination heads).
        @children = grep {$_->afun() !~ m/^Aux[XGK]$/} (@children);
        my $n        = scalar(@children);
        if ( $n < 1 )
        {
            if ($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $self->form();
                log_warn("$afun node does not have children (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            if ( $n > 1 && $warnings )
            {
                my $i_sentence = $self->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $self->form();
                log_warn("$afun node has $n children so it is not clear which one bears the real afun (sentence $i_sentence, '$form')");
            }
            return $children[0]->get_real_afun();
        }
    }
    elsif ( $self->is_coap_root() )
    {
        my @members = $self->get_coap_members();
        my $n       = scalar(@members);
        if ( $n < 1 )
        {
            if ($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $self->form();
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
    my $self     = shift;
    my $new_afun = shift;
    my $warnings = shift;
    my $afun     = $self->afun();
    if ( not defined($afun) ) {
        $afun = '';
    }
    if ( $afun =~ m/^Aux[PC]$/ )
    {
        my @children = $self->children();
        # Exclude punctuation children (afun-wise, not POS-tag-wise: we do not want to exclude coordination heads).
        @children = grep {$_->afun() !~ m/^Aux[XGK]$/} (@children);
        my $n        = scalar(@children);
        if ( $n < 1 )
        {
            if ($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $self->form();
                log_warn("$afun node does not have children (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            if ( $warnings && $n > 1 )
            {
                my $i_sentence = $self->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $self->form();
                log_warn("$afun node has $n children so it is not clear which one bears the real afun (sentence $i_sentence, '$form')");
            }
            foreach my $child (@children)
            {
                $child->set_real_afun($new_afun);
            }
            return;
        }
    }
    elsif ( $self->is_coap_root() )
    {
        my @members = $self->get_coap_members();
        my $n       = scalar(@members);
        if ( $n < 1 )
        {
            if ($warnings)
            {
                my $i_sentence = $self->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $self->form();
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
# Recursively copy attributes and children from myself to another node.
# This function is specific to the A layer because it contains the list of
# attributes. If we could figure out the list automatically, the function would
# become general enough to reside directly in Node.pm.
#
# NOTE: We could possibly make just copy_attributes() layer-dependent and unify
# the main copy_atree code.
#------------------------------------------------------------------------------
sub copy_atree
{
    my $self   = shift;
    my $target = shift;

    # Copy all attributes of the original node to the new one.
    # We do this for all the nodes including the ‘root’ (which may actually be
    # an ordinary node if we are copying a subtree).
    $self->copy_attributes($target);

    my @children0 = $self->get_children( { ordered => 1 } );
    foreach my $child0 (@children0)
    {
        # Create a copy of the child node.
        my $child1 = $target->create_child();
        # Call recursively on the subtrees of the children.
        $child0->copy_atree($child1);
    }

    return;
}

#------------------------------------------------------------------------------
# Copies values of all attributes from one node to another. The only difference
# between the two nodes afterwards should be their ids.
#------------------------------------------------------------------------------
sub copy_attributes
{
    my ( $self, $other ) = @_;
    # We should copy all attributes that the node has but it is not easy to figure out which these are.
    # TODO: As a workaround, we list the attributes here directly.
    foreach my $attribute (
        'form', 'lemma', 'tag', 'no_space_after', 'translit', 'gloss',
        'ord', 'deprel', 'afun', 'is_member', 'is_parenthesis_root',
        'conll/deprel', 'conll/cpos', 'conll/pos', 'conll/feat', 'is_shared_modifier', 'morphcat',
        )
    {
        my $value = $self->get_attr($attribute);
        $other->set_attr( $attribute, $value );
    }
    # copy values of interset features
    my $f = $self->get_iset_structure();
    $other->set_iset($f);
    # deep copy of wild attributes
    $other->set_wild( Storable::dclone( $self->wild ) );
    return;
}

# -- linking to p-layer --

sub get_terminal_pnode {
    my ($self) = @_;
    my $p_rf = $self->get_attr('p_terminal.rf') or return;
    my $doc = $self->get_document();
    return $doc->get_node_by_id($p_rf);
}

sub set_terminal_pnode {
    my ( $self, $pnode ) = @_;
    my $new_id = defined $pnode ? $pnode->id : undef;
    $self->set_attr( 'p_terminal.rf', $new_id );
    return;
}

sub get_nonterminal_pnodes {
    my ($self) = @_;
    my $pnode = $self->get_terminal_pnode() or return;
    my @nonterminals = ();
    while ( $pnode->is_head ) {
        $pnode = $pnode->get_parent();
        push @nonterminals, $pnode;
    }
    return @nonterminals;
}

sub get_pnodes {
    my ($self) = @_;
    return ( $self->get_terminal_pnode, $self->get_nonterminal_pnodes );
}

# -- referenced node ids --

override '_get_reference_attrs' => sub {
    my ($self) = @_;
    return ('p_terminal.rf');
};

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
    return join '', map { defined( $_->form ) ? ( $_->form . ( $_->no_space_after ? '' : ' ' ) ) : '' } $self->get_descendants( { ordered => 1 } );
}

#------------------------------------------------------------------------------
# Serializes a tree to a string of dependencies (similar to the Stanford
# dependency format). Useful for debugging (quick comparison of two tree
# structures and an info string for the error message at the same time).
#------------------------------------------------------------------------------
sub get_subtree_dependency_string
{
    my $self = shift;
    my $for_brat = shift; # Do we want a format that spans multiple lines but can be easily visualized in Brat?
    my @nodes = $self->get_descendants({'ordered' => 1});
    my $offset = $for_brat ? 1 : 0;
    my @dependencies = map
    {
        my $n = $_;
        my $no = $n->ord()+$offset;
        my $nf = $n->form();
        my $p = $n->parent();
        my $po = $p->ord()+$offset;
        my $pf = $p->is_root() ? 'ROOT' : $p->form();
        my $d = defined($n->deprel()) ? $n->deprel() : defined($n->afun()) ? $n->afun() : defined($n->conll_deprel()) ? $n->conll_deprel() : 'NR';
        if($n->is_member())
        {
            if(defined($n->deprel()))
            {
                $d .= ':member';
            }
            else
            {
                $d .= '_M';
            }
        }
        "$d($pf-$po, $nf-$no)"
    }
    (@nodes);
    my $sentence = join(' ', map {$_->form()} (@nodes));
    if($for_brat)
    {
        $sentence = "ROOT $sentence";
        my $tree = join("\n", @dependencies);
        return "~~~ sdparse\n$sentence\n$tree\n~~~\n";
    }
    else
    {
        my $tree = join('; ', @dependencies);
        return "$sentence\t$tree";
    }
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

#---------- Morphcat -------------

sub morphcat_pos        { return $_[0]->get_attr('morphcat/pos'); }
sub morphcat_subpos     { return $_[0]->get_attr('morphcat/subpos'); }
sub morphcat_number     { return $_[0]->get_attr('morphcat/number'); }
sub morphcat_gender     { return $_[0]->get_attr('morphcat/gender'); }
sub morphcat_case       { return $_[0]->get_attr('morphcat/case'); }
sub morphcat_person     { return $_[0]->get_attr('morphcat/person'); }
sub morphcat_tense      { return $_[0]->get_attr('morphcat/tense'); }
sub morphcat_negation   { return $_[0]->get_attr('morphcat/negation'); }
sub morphcat_voice      { return $_[0]->get_attr('morphcat/voice'); }
sub morphcat_grade      { return $_[0]->get_attr('morphcat/grade'); }
sub morphcat_mood       { return $_[0]->get_attr('morphcat/mood'); }
sub morphcat_possnumber { return $_[0]->get_attr('morphcat/possnumber'); }
sub morphcat_possgender { return $_[0]->get_attr('morphcat/possgender'); }

sub set_morphcat_pos        { return $_[0]->set_attr( 'morphcat/pos',        $_[1] ); }
sub set_morphcat_subpos     { return $_[0]->set_attr( 'morphcat/subpos',     $_[1] ); }
sub set_morphcat_number     { return $_[0]->set_attr( 'morphcat/number',     $_[1] ); }
sub set_morphcat_gender     { return $_[0]->set_attr( 'morphcat/gender',     $_[1] ); }
sub set_morphcat_case       { return $_[0]->set_attr( 'morphcat/case',       $_[1] ); }
sub set_morphcat_person     { return $_[0]->set_attr( 'morphcat/person',     $_[1] ); }
sub set_morphcat_tense      { return $_[0]->set_attr( 'morphcat/tense',      $_[1] ); }
sub set_morphcat_negation   { return $_[0]->set_attr( 'morphcat/negation',   $_[1] ); }
sub set_morphcat_voice      { return $_[0]->set_attr( 'morphcat/voice',      $_[1] ); }
sub set_morphcat_grade      { return $_[0]->set_attr( 'morphcat/grade',      $_[1] ); }
sub set_morphcat_mood       { return $_[0]->set_attr( 'morphcat/mood',       $_[1] ); }
sub set_morphcat_possnumber { return $_[0]->set_attr( 'morphcat/possnumber', $_[1] ); }
sub set_morphcat_possgender { return $_[0]->set_attr( 'morphcat/possgender', $_[1] ); }

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

=head1 ATTRIBUTES

For each attribute (e.g. C<tag>), there is
a getter method (C<< my $tag = $anode->tag(); >>)
and a setter method (C<< $anode->set_tag('NN'); >>).

=head2 Original w-layer and m-layer attributes

=over

=item form

=item lemma

=item tag

=item no_space_after

=back

=head2 Original a-layer attributes

=over

=item afun

=item is_parenthesis_root

=item edge_to_collapse

=item is_auxiliary

=back

=head1 METHODS

=head2 Links from a-trees to phrase-structure trees

=over 4

=item $node->get_terminal_pnode

Returns a terminal node from the phrase-structure tree
that corresponds to the a-node.

=item $node->set_terminal_pnode($pnode)

Set the given terminal node from the phrase-structure tree
as corresponding to the a-node.

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

=item n_node()

If this a-node is a part of a named entity,
this method returns the corresponding n-node (L<Treex::Core::Node::N>).
If this node is a part of more than one named entities,
only the most nested one is returned.
For example: "Bank of China"

 $n_node_for_china = $a_node_china->n_node();
 print $n_node_for_china->get_attr('normalized_name'); # China
 $n_node_for_bank_of_china = $n_node_for_china->get_parent();
 print $n_node_for_bank_of_china->get_attr('normalized_name'); # Bank of China

=item $node->get_subtree_string

Return the string corresponding to a subtree rooted in C<$node>.
It's computed based on attributes C<form> and C<no_space_after>.

=back


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
