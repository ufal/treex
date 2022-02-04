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

has [qw(form lemma tag no_space_after fused_with_next fused_form fused_misc)] => ( is => 'rw' );

has [
    qw(deprel afun is_parenthesis_root edge_to_collapse is_auxiliary translit ltranslit gloss)
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
        'form', 'lemma', 'tag', 'no_space_after', 'translit', 'ltranslit', 'gloss',
        'fused_with_next', 'fused_form', 'fused_misc',
        'ord', 'deprel', 'afun', 'is_member', 'is_parenthesis_root',
        'conll/deprel', 'conll/cpos', 'conll/pos', 'conll/feat', 'is_shared_modifier', 'morphcat',
        'clause_number', 'is_clause_head',
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



#------------------------------------------------------------------------------
# The MISC attributes from CoNLL-U files are stored as wild attributes. These
# methods should be in a Universal Dependencies related role but we don't have one.
# Returns a list of MISC attributes (possibly an empty list).
#------------------------------------------------------------------------------
sub get_misc
{
    my $self = shift;
    my @misc;
    my $wild = $self->wild();
    if (exists($wild->{misc}) && defined($wild->{misc}))
    {
        @misc = split(/\|/, $wild->{misc});
    }
    return @misc;
}



#------------------------------------------------------------------------------
# Returns the first value of the given MISC attribute, or undef.
#------------------------------------------------------------------------------
sub get_misc_attr
{
    my $self = shift;
    my $attr = shift;
    my @misc = grep {m/^$attr=/} ($self->get_misc());
    if(scalar(@misc) > 1)
    {
        log_warn("Multiple values of MISC attribute '$attr'.");
    }
    if(scalar(@misc) > 0)
    {
        if($misc[0] =~ m/^$attr=(.*)$/)
        {
            my $value = $1 // '';
            return $value;
        }
    }
    return undef;
}



#------------------------------------------------------------------------------
# Takes a list of MISC attributes (possibly an empty list) and stores it as
# a wild attribute of the node. Any previous list will be forgotten.
#------------------------------------------------------------------------------
sub set_misc
{
    my $self = shift;
    my @misc = @_;
    my $wild = $self->wild();
    if (scalar(@misc) > 0)
    {
        $wild->{misc} = join('|', @misc);
    }
    else
    {
        delete($wild->{misc});
    }
}



#------------------------------------------------------------------------------
# Takes an attribute name and value. Assumes that MISC elements are attr=value
# pairs. Replaces the first occurrence of that attribute; if it does not yet
# occur in MISC, pushes it at the end. Does not do anything if the value is
# undef! For clearing the attribute in MISC, use clear_misc_attr().
#------------------------------------------------------------------------------
sub set_misc_attr
{
    my $self = shift;
    my $attr = shift;
    my $value = shift;
    if (defined($attr) && defined($value))
    {
        my @misc = $self->get_misc();
        my $found = 0;
        for(my $i = 0; $i <= $#misc; $i++)
        {
            if ($misc[$i] =~ m/^(.+?)=(.+)$/ && $1 eq $attr)
            {
                if ($found)
                {
                    splice(@misc, $i--, 1);
                }
                else
                {
                    $misc[$i] = "$attr=$value";
                    $found = 1;
                }
            }
        }
        if (!$found)
        {
            push(@misc, "$attr=$value");
        }
        $self->set_misc(@misc);
    }
}



#------------------------------------------------------------------------------
# Takes an attribute name. Assumes that MISC elements are attr=value pairs.
# Removes all occurrences of that attribute.
#------------------------------------------------------------------------------
sub clear_misc_attr
{
    my $self = shift;
    my $attr = shift;
    if (defined($attr))
    {
        my @misc = $self->get_misc();
        @misc = grep {!(m/^(.+?)=/ && $1 eq $attr)} (@misc);
        $self->set_misc(@misc);
    }
}



#------------------------------------------------------------------------------
# Says whether this node is member of a fused ("multiword") token.
#------------------------------------------------------------------------------
sub is_fused
{
    my $self = shift;
    return 1 if($self->fused_with_next());
    my $prev = $self->get_prev_node();
    return defined($prev) && $prev->fused_with_next();
}



#------------------------------------------------------------------------------
# If this node is fused with one or more preceding nodes, returns the first
# node of the fusion. Otherwise returns this node.
#------------------------------------------------------------------------------
sub get_fusion_start
{
    my $self = shift;
    my $prev = $self->get_prev_node();
    if(defined($prev) && $prev->fused_with_next())
    {
        return $prev->get_fusion_start();
    }
    return $self;
}



#------------------------------------------------------------------------------
# If this node is fused with one or more following nodes, returns the last
# node of the fusion. Otherwise returns this node.
#------------------------------------------------------------------------------
sub get_fusion_end
{
    my $self = shift;
    if($self->fused_with_next())
    {
        my $next = $self->get_next_node();
        if(defined($next))
        {
            return $next->get_fusion_end();
        }
    }
    return $self;
}



#------------------------------------------------------------------------------
# Returns list of fused nodes including this node. If the node is not fused
# with its neighbors, the list contains only this node.
#------------------------------------------------------------------------------
sub get_fused_nodes
{
    my $self = shift;
    my @nodes = ($self);
    my $x = $self->get_prev_node();
    while(defined($x) && $x->fused_with_next())
    {
        unshift(@nodes, $x);
        $x = $x->get_prev_node();
    }
    $x = $self;
    while($x->fused_with_next())
    {
        $x = $x->get_next_node();
        last if(!defined($x));
        push(@nodes, $x);
    }
    return @nodes;
}



#------------------------------------------------------------------------------
# Returns the fused form stored in the first node of the fusion (multiword
# token). If this node is not part of any fusion, returns the fused_form of
# this node, which should be undefined.
#------------------------------------------------------------------------------
sub get_fusion
{
    my $self = shift;
    return $self->get_fusion_start()->fused_form();
}



#------------------------------------------------------------------------------
# Returns the MISC attributes stored in the first node of the fusion (multiword
# token). If this node is not part of any fusion, returns the fused_misc of
# this node, which should be undefined.
#------------------------------------------------------------------------------
sub get_fused_misc
{
    my $self = shift;
    return $self->get_fusion_start()->fused_misc();
}



#------------------------------------------------------------------------------
# Returns the sentence text, observing the current setting of no_space_after
# and of the fused multi-word tokens. That is, this method does not reach to
# the sentence attribute of the zone. Instead, it visits all nodes including
# $self, puts together their word forms and spaces. The result can be compared
# to the zone's sentence attribute, or even used to update the attribute.
#------------------------------------------------------------------------------
sub collect_sentence_text
{
    my $self = shift;
    my @nodes = $self->get_root()->get_descendants({'ordered' => 1});
    my $text = '';
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        if($node->is_fused() && $node->get_fusion_start() == $node)
        {
            my $last_node = $node->get_fusion_end();
            $text .= $node->get_fusion();
            $text .= ' ' unless($last_node->no_space_after());
            $i += $last_node->ord() - $node->ord();
        }
        else
        {
            $text .= $node->form();
            $text .= ' ' unless($node->no_space_after());
        }
    }
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}



#==============================================================================
# Enhanced Universal Dependencies and empty nodes
#==============================================================================



#------------------------------------------------------------------------------
# Returns the list of incoming enhanced edges for a node. Each element of the
# list is a pair: 1. ord of the parent node; 2. relation label.
#------------------------------------------------------------------------------
sub get_enhanced_deps
{
    my $self = shift;
    my $wild = $self->wild();
    if(!exists($wild->{enhanced}) || !defined($wild->{enhanced}) || ref($wild->{enhanced}) ne 'ARRAY')
    {
        # Silently create the wild attribute: an empty array.
        $wild->{enhanced} = [];
    }
    return @{$wild->{enhanced}};
}



#------------------------------------------------------------------------------
# Adds a new enhanced edge incoming to the current node, unless the same
# relation with the same parent already exists.
#------------------------------------------------------------------------------
sub add_enhanced_dependency
{
    my $self = shift; # child
    my $parent = shift;
    my $deprel = shift;
    # Self-loops are not allowed in enhanced dependencies.
    # We could silently ignore the call but there is probably something wrong
    # at the caller's side, so we will throw an exception.
    if($parent == $self)
    {
        my $ord = $self->ord();
        my $form = $self->form() // '';
        log_fatal("Self-loops are not allowed in the enhanced graph but we are attempting to attach the node no. $ord ('$form') to itself.");
    }
    my $pord = $parent->get_conllu_id();
    my @edeps = $self->get_enhanced_deps();
    unless(any {$_->[0] eq $pord && $_->[1] eq $deprel} (@edeps))
    {
        push(@{$self->wild()->{enhanced}}, [$pord, $deprel]);
    }
}



#------------------------------------------------------------------------------
# Returns the list of parents of a node in the enhanced graph, i.e., the list
# of nodes from which there is at least one edge incoming to the given node.
# The list is ordered by their ord value.
#
# Optionally the parents will be filtered by regex on relation type.
#------------------------------------------------------------------------------
sub get_enhanced_parents
{
    my $self = shift;
    my $relregex = shift;
    my $negate = shift; # return parents that do not match $relregex
    my @edeps = $self->get_enhanced_deps();
    if(defined($relregex))
    {
        if($negate)
        {
            @edeps = grep {$_->[1] !~ m/$relregex/} (@edeps);
        }
        else
        {
            @edeps = grep {$_->[1] =~ m/$relregex/} (@edeps);
        }
    }
    # Remove duplicates.
    my %epmap; map {$epmap{$_->[0]}++} (@edeps);
    my @parents = sort {$a->ord() <=> $b->ord()} (map {$self->get_node_by_conllu_id($_)} (keys(%epmap)));
    return @parents;
}



#------------------------------------------------------------------------------
# Returns the list of children of a node in the enhanced graph, i.e., the list
# of nodes that have at least one incoming edge from the given start node.
# The list is ordered by their ord value.
#
# Optionally the children will be filtered by regex on relation type.
#------------------------------------------------------------------------------
sub get_enhanced_children
{
    my $self = shift;
    my $relregex = shift;
    my $negate = shift; # return children that do not match $relregex
    # We do not maintain an up-to-date list of outgoing enhanced edges, only
    # the incoming ones. Therefore we must search all nodes of the sentence.
    my @nodes = $self->get_root()->get_descendants({'ordered' => 1});
    my @children;
    foreach my $n (@nodes)
    {
        my @edeps = $n->get_enhanced_deps();
        if(defined($relregex))
        {
            if($negate)
            {
                @edeps = grep {$_->[1] !~ m/$relregex/} (@edeps);
            }
            else
            {
                @edeps = grep {$_->[1] =~ m/$relregex/} (@edeps);
            }
        }
        if(any {$_->[0] == $self->get_conllu_id()} (@edeps))
        {
            push(@children, $n);
        }
    }
    # Remove duplicates.
    my %ecmap; map {$ecmap{$_->ord()} = $_ unless(exists($ecmap{$_->ord()}))} (@children);
    @children = map {$ecmap{$_}} (sort {$a <=> $b} (keys(%ecmap)));
    return @children;
}



#------------------------------------------------------------------------------
# Returns the list of nodes to which there is a path from the current node in
# the enhanced graph. The list is not ordered and does not include $self.
#------------------------------------------------------------------------------
sub get_enhanced_descendants
{
    my $self = shift;
    my $visited = shift;
    # Keep track of visited nodes. Avoid endless loops.
    my @_dummy;
    if(!defined($visited))
    {
        $visited = \@_dummy;
    }
    return () if($visited->[$self->ord()]);
    $visited->[$self->ord()]++;
    my @echildren = $self->get_enhanced_children();
    my @echildren2;
    foreach my $ec (@echildren)
    {
        my @ec2 = $ec->get_enhanced_descendants($visited);
        if(scalar(@ec2) > 0)
        {
            push(@echildren2, @ec2);
        }
    }
    # Unlike the method Node::get_descendants(), we currently do not support
    # the parameters add_self, ordered, preceding_only etc. The caller has
    # to take care of sort and grep themselves. (We could do sorting but it
    # would be inefficient to do it in each step of the recursion. And in any
    # case we would not know whether to add self or not; if yes, then the
    # sorting would have to be repeated again.)
    #my @result = sort {$a->ord() <=> $b->ord()} (@echildren, @echildren2);
    my @result = (@echildren, @echildren2);
    return @result;
}



#------------------------------------------------------------------------------
# Creates an empty node. In the sentence node sequence, it will be placed at
# the end (while its decimal CoNLL-U ID/ord will be stored as a wild
# attribute). In the basic tree, it will be connected to the artificial root
# via a fake dependency 'dep:empty' (all UD-processing blocks should be aware
# of the possibility that some nodes are empty).
#------------------------------------------------------------------------------
sub create_empty_node
{
    my $self = shift;
    my $enord = shift;
    my $root = $self->get_root();
    my $node = $root->create_child();
    $node->set_deprel('dep:empty');
    $node->wild()->{enhanced} = [];
    $node->wild()->{enord} = $enord;
    $node->shift_after_subtree($root);
    return $node;
}



#------------------------------------------------------------------------------
# Empty nodes in enhanced UD graphs are modeled using fake a-nodes at the end
# of the sentence. In the a-tree they are attached directly to the artificial
# root, with the deprel 'dep:empty'. Their ord is used internally in Treex,
# e.g., in the wild attributes that model the enhanced dependencies. Their
# CoNLL-U id ("decimal ord") is stored in a wild attribute.
#------------------------------------------------------------------------------
sub is_empty
{
    my $self = shift;
    return defined($self->deprel()) && $self->deprel() eq 'dep:empty';
}



#------------------------------------------------------------------------------
# Returns the CoNLL-U node ID. For regular nodes it is their ord; for empty
# nodes the decimal id is stored in a wild attribute.
#------------------------------------------------------------------------------
sub get_conllu_id
{
    my $self = shift;
    return $self->is_empty() ? $self->wild()->{enord} : $self->ord();
}



#------------------------------------------------------------------------------
# Returns the CoNLL-U node ID split to major and minor number (useful for
# sorting).
#------------------------------------------------------------------------------
sub get_major_minor_id
{
    my $self = shift;
    my $major = $self->get_conllu_id();
    my $minor = 0;
    if($major =~ s/^(\d+)\.(\d+)$/$1/)
    {
        $minor = $2;
    }
    return ($major, $minor);
}



#------------------------------------------------------------------------------
# Finds a node with a given id in the same tree. This is useful if we are
# looking at the list of incoming enhanced edges and need to actually access
# one of the parents listed there by ord. We assume that if the method is
# called, the caller is confident that the node should exist. The method will
# throw an exception if there is no node or multiple nodes with the given ord.
#------------------------------------------------------------------------------
sub get_node_by_conllu_id
{
    my $self = shift;
    my $id = shift;
    my $root = $self->get_root();
    return $root if($id == 0);
    my @results = grep {$_->get_conllu_id() == $id} ($root->get_descendants());
    if(scalar(@results) == 0)
    {
        log_warn($self->get_forms_with_ords_and_conllu_ids());
        log_fatal("No node with CoNLL-U ID '$id' found.");
    }
    if(scalar(@results) > 1)
    {
        log_warn($self->get_forms_with_ords_and_conllu_ids());
        log_fatal("There are multiple nodes with CoNLL-U ID '$id'.");
    }
    return $results[0];
}



#------------------------------------------------------------------------------
# Returns all words in the current sentence together with their ords and
# CoNLL-U ids. Used for debugging.
#------------------------------------------------------------------------------
sub get_forms_with_ords_and_conllu_ids
{
    my $self = shift;
    my $root = $self->get_root();
    my @nodes = $root->get_descendants({'ordered' => 1});
    my @triples = map {my $f = $_->form() // '_'; my $o = $_->ord() // '_'; my $i = $_->get_conllu_id() // '_'; "$o:$i:$f"} (@nodes);
    return join(' ', @triples);
}



#------------------------------------------------------------------------------
# Converts the old hack for empty nodes to a new hack. The old hack does not
# use a Node object for an empty node. Instead, the enhanced dependency encodes
# the path between two real nodes via one or more empty nodes: 'conj>3.5>obj'.
# In the new hack, there will be a Node object for the empty node. It will have
# a fake basic dependency, directly on the artificial root node, with the
# deprel 'dep:empty'. It will have an integer ord at the end of the sentence,
# while its decimal ord for CoNLL-U will be saved in a wild attribute. All
# blocks that deal with a UD tree must be aware of the possibility that there
# are empty nodes, and these nodes must be excluded from operations with basic
# dependencies.
#
# Even after all UD-related blocks are updated to work with the new hack, we
# may need to call this method on data that has been saved in the Treex format
# while the old hack was used.
#------------------------------------------------------------------------------
sub expand_empty_nodes
{
    my $self = shift;
    log_fatal('expand_empty_nodes() must be called on a root node') if(!$self->is_root());
    my @nodes = $self->get_descendants({'ordered' => 1});
    # Populate the hash of empty nodes in the current sentence.
    my %enords;
    foreach my $node (@nodes)
    {
        my @iedges = $node->get_enhanced_deps();
        foreach my $ie (@iedges)
        {
            # We are looking for deprels of the form 'conj>3.5>obj' (there may
            # be multiple empty nodes in the chain).
            if($ie->[1] =~ m/>/)
            {
                my @parts = split(/>/, $ie->[1]);
                foreach my $part (@parts)
                {
                    if($part =~ m/^\d+\.\d+$/)
                    {
                        $enords{$part}++;
                    }
                }
            }
        }
    }
    # Create empty nodes at the end of the sentence.
    my @enords = sort {$a <=> $b} (keys(%enords));
    my %emptynodes; # Node objects indexed by enords
    foreach my $enord (@enords)
    {
        my $node = $self->create_empty_node($enord);
        $emptynodes{$enord} = $node;
    }
    # Redirect paths through empty nodes.
    # @nodes still holds only the regular nodes.
    foreach my $node (@nodes)
    {
        my @iedges = $node->get_enhanced_deps();
        my $modified = 0;
        foreach my $ie (@iedges)
        {
            # We are looking for deprels of the form 'conj>3.5>obj' (there may
            # be multiple empty nodes in the chain).
            if($ie->[1] =~ m/>/)
            {
                my @parts = split(/>/, $ie->[1]);
                # The number of parts must be odd.
                if(scalar(@parts) % 2 == 0)
                {
                    log_fatal("Cannot understand enhanced deprel '$ie->[1]': even number of parts.");
                }
                my $pord = $ie->[0];
                my $parent = $self->get_node_by_conllu_id($pord);
                while(scalar(@parts) > 1)
                {
                    my $deprel = shift(@parts);
                    my $cord = shift(@parts);
                    if(!exists($emptynodes{$cord}))
                    {
                        log_fatal("Unknown empty node '$cord'.");
                    }
                    my $child = $emptynodes{$cord};
                    $child->add_enhanced_dependency($parent, $deprel);
                    $parent = $child;
                }
                # The remaining part is a deprel, and we know the current parent.
                $ie->[0] = $parent->ord();
                $ie->[1] = $parts[0];
                $modified = 1;
            }
        }
        # We may have modified our copy of the @iedges array. We have to copy
        # it back to the wild attributes of the node.
        if($modified)
        {
            @{$node->wild()->{enhanced}} = @iedges;
        }
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
