package Treex::Core::Coordination;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;



# Root nodes of conjuncts and delimiters are participants of coordination.
# Shared and private modifiers are not participants, even though we keep track of them.
# We maintain one array of records (hashes) about participants.
# For every participant, we maintain the following information:
# node ... reference to the corresponding Node object
# type ... conjunct|delimiter
# subtype ... conjunct|orphan||conjunction|symbol
# list of root nodes of dependents of the participant
#     It is not necessarily identical to the list of current children of the node in the tree!
#     Depending on the currently used annotation scheme, other participants may be among the children
#     but they will not be listed here!
has _participants => (
    is       => 'rw',
    isa      => 'ArrayRef[HashRef]',
    writer   => '_set_participants',
    reader   => '_get_participants',
    default  => sub { [] }
);



# We also maintain a list of shared modifiers, i.e. root nodes of subtrees that ought to depend on the root of the coordination.
# This is a simple array of references to Node objects, without any wrapping information.
has _smod => (
    is       => 'rw',
    isa      => 'ArrayRef[Treex::Core::Node]',
    writer   => '_set_smod',
    reader   => '_get_smod',
    default  => sub { [] }
);



# Relation of the whole coordination to its parent.
has parent => (
    is       => 'rw',
    isa      => 'Treex::Core::Node',
    writer   => 'set_parent',
    reader   => 'parent'
);
has afun => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'set_afun',
    reader   => 'afun'
);
has is_member => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'set_is_member',
    reader   => 'is_member'
);



#------------------------------------------------------------------------------
# Checks that a node is not yet known to the coordination. We do not want to
# know one node in two different roles (not even twice in the same role!)
# This function either returns true or throws FATAL right away. So it cannot
# be used to check a node before we attempt to add it.
#------------------------------------------------------------------------------
sub check_that_node_is_new
{
    my $self = shift;
    my $node = shift;
    my $p = shift; my @participants = @{$p};
    my $s = shift; my @smod = @{$s};
    log_fatal("Missing node") unless(defined($node));
    # Is it a participant?
    if(grep {$_->{node} == $node} @participants)
    {
        log_fatal("Node $node is already a participant of this coordination! ", $node->ord(), " ", $node->form());
    }
    # Is it private modifier of a participant?
    if(grep {$_ == $node} (map {@{$_->{pmod}}} @participants))
    {
        log_fatal("Node $node is already a private modifier of a participant of this coordination! ", $node->ord(), " ", $node->form());
    }
    # Is it a shared modifier?
    if(grep {$_ == $node} @smod)
    {
        log_fatal("Node $node is already a shared modifier of this coordination! ", $node->ord(), " ", $node->form());
    }
    # Is it registered as parent of the whole coordination?
    # Note: We want the world consistent as far as our knowledge reaches.
    # But we want to be independent of the parent-child links between the nodes.
    # So we cannot guarantee that changing the parent-child links will not introduce cycles!
    # If e.g. the registered parent is grandchild of a participant, we will not know about it.
    # Then the Node object will launch alarm when we attempt to shape the coordination.
    if(defined($self->parent()) && $node == $self->parent())
    {
        log_fatal("Node $node is already a parent of this coordination! ", $node->ord(), " ", $node->form());
    }
    return 1;
}



#------------------------------------------------------------------------------
# Adds participant to coordination.
#------------------------------------------------------------------------------
sub add_participant
{
    my $self = shift;
    my $node = shift;
    my $type = shift;
    my $orphan = shift; # nonzero when this is a (ExD-like) dependent of a deleted conjunct
    my $symbol = shift; # nonzero if this is a punctuation symbol
    log_fatal("Missing node") unless(defined($node));
    my @pmod = @_; # list of dependent nodes (not participants of this coordination!)
    my $participants = $self->_get_participants();
    my $smod = $self->_get_smod();
    $self->check_that_node_is_new($node, $participants, $smod);
    my %record =
    (
        'node'   => $node,
        'type'   => $type,
        'orphan' => $orphan,
        'symbol' => $symbol,
        'pmod'   => []
    );
    push(@{$participants}, \%record);
    foreach my $pm (@pmod)
    {
        $self->check_that_node_is_new($pm, $participants, $smod);
        push(@{$record{pmod}}, $pm);
    }
    return \%record;
}



#------------------------------------------------------------------------------
# Adds conjunct to coordination.
#------------------------------------------------------------------------------
sub add_conjunct
{
    my $self = shift;
    my $node = shift;
    my $orphan = shift; # nonzero when this is a (ExD-like) dependent of a deleted conjunct
    log_fatal("Missing node") unless(defined($node));
    my @pmod = @_; # list of dependent nodes (not participants of this coordination!)
    return $self->add_participant($node, 'conjunct', $orphan, 0, @pmod);
}



#------------------------------------------------------------------------------
# Adds conjunct delimiter (conjunction, punctuation) to coordination.
#------------------------------------------------------------------------------
sub add_delimiter
{
    my $self = shift;
    my $node = shift;
    my $symbol = shift; # nonzero if this is a punctuation symbol
    log_fatal("Missing node") unless(defined($node));
    my @pmod = @_; # list of dependent nodes (not participants of this coordination!)
    return $self->add_participant($node, 'delimiter', 0, $symbol, @pmod);
}



#------------------------------------------------------------------------------
# Adds shared modifier to coordination.
#------------------------------------------------------------------------------
sub add_shared_modifier
{
    my $self = shift;
    my $node = shift;
    log_fatal("Missing node") unless(defined($node));
    my $participants = $self->_get_participants();
    my $smod = $self->_get_smod();
    $self->check_that_node_is_new($node, $participants, $smod);
    push(@{$smod}, $node);
}



#------------------------------------------------------------------------------
# Finds a private modifier of a conjunct and makes it shared modifier.
#------------------------------------------------------------------------------
sub change_private_modifier_to_shared
{
    my $self = shift;
    my $node = shift;
    my $conjunct = shift; # helps find the modifier
    log_fatal("Missing node") unless(defined($node));
    my $participants = $self->_get_participants();
    foreach my $p (@{$participants})
    {
        if($p->{node}==$conjunct)
        {
            for(my $i = 0; $i<=$#{$p->{pmod}}; $i++)
            {
                if($p->{pmod}[$i]==$node)
                {
                    # Remove it from the list of private modifiers.
                    splice(@{$p->{pmod}}, $i, 1);
                    # Add it to the list of shared modifiers.
                    my $smod = $self->_get_smod();
                    push(@{$smod}, $node);
                    # Return success (if we get past the loops, it means we didn't find it).
                    return 1;
                }
            }
            log_fatal("Unknown private modifier of a conjunct");
        }
    }
    log_fatal("Unknown conjunct");
}



#------------------------------------------------------------------------------
# Finds a shared modifier and makes it private modifier of a conjunct.
#------------------------------------------------------------------------------
sub change_shared_modifier_to_private
{
    my $self = shift;
    my $node = shift;
    my $conjunct = shift;
    log_fatal("Missing node") unless(defined($node));
    my $smod = $self->_get_smod();
    for(my $i = 0; $i<=$#{$smod}; $i++)
    {
        if($smod->[$i]==$node)
        {
            my $participants = $self->_get_participants();
            foreach my $p (@{$participants})
            {
                if($p->{node}==$conjunct)
                {
                    # Remove it from the list of shared modifiers.
                    splice(@{$smod}, $i, 1);
                    # Add it to the list of private modifiers.
                    push(@{$p->{pmod}}, $node);
                    # Return success (if we get past the loops, it means we didn't find it).
                    return 1;
                }
            }
            log_fatal("Unknown conjunct");
        }
    }
    log_fatal("Unknown shared modifier");
}



#------------------------------------------------------------------------------
# Returns the list of participants (all conjuncts and delimiters).
#------------------------------------------------------------------------------
sub get_participants
{
    my $self = shift;
    my %prm = @_;
    my @list = map {$_->{node}} (@{$self->_get_participants()});
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of conjuncts (including orphans).
#------------------------------------------------------------------------------
sub get_conjuncts
{
    my $self = shift;
    my %prm = @_;
    my @list = map {$_->{node}} (grep {$_->{type} eq 'conjunct'} @{$self->_get_participants()});
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of orphan conjuncts.
#------------------------------------------------------------------------------
sub get_orphans
{
    my $self = shift;
    my %prm = @_;
    my @list = map {$_->{node}} (grep {$_->{type} eq 'conjunct' && $_->{orphan}} @{$self->_get_participants()});
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of delimiters.
#------------------------------------------------------------------------------
sub get_delimiters
{
    my $self = shift;
    my %prm = @_;
    my @list = map {$_->{node}} (grep {$_->{type} eq 'delimiter'} @{$self->_get_participants()});
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of conjunctions, i.e. non-symbol delimiters.
#------------------------------------------------------------------------------
sub get_conjunctions
{
    my $self = shift;
    my %prm = @_;
    my @list = map {$_->{node}} (grep {$_->{type} eq 'delimiter' && !$_->{symbol}} @{$self->_get_participants()});
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of shared modifiers.
#------------------------------------------------------------------------------
sub get_shared_modifiers
{
    my $self = shift;
    my %prm = @_;
    my @list = @{$self->_get_smod()};
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of private modifiers of a given conjunct.
#------------------------------------------------------------------------------
sub get_private_modifiers
{
    my $self = shift;
    my $conjunct = shift; # Node
    log_fatal("Unknown conjunct") unless(defined($conjunct));
    my %prm = @_;
    my $participants = $self->_get_participants();
    my @list;
    foreach my $participant (@{$participants})
    {
        if($participant->{node}==$conjunct)
        {
            @list = @{$participant->{pmod}};
            last;
        }
    }
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of immediate dependents of the coordination, i.e. shared and
# private modifiers.
#------------------------------------------------------------------------------
sub get_children
{
    my $self = shift;
    my %prm = @_;
    my @smod = $self->get_shared_modifiers();
    my @pmod = map {@{$_->{pmod}}} @{$self->_get_participants()};
    my @list = (@smod, @pmod);
    if($prm{ordered})
    {
        @list = sort {$a->ord() <=> $b->ord()} (@list);
    }
    return @list;
}
sub children
{
    return get_children(@_);
}



#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects Prague style.
#------------------------------------------------------------------------------
sub detect_prague
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    return unless($node->afun() eq 'Coord');
    $self->set_parent($node->parent());
    $self->set_is_member($node->is_member());
    $self->set_afun('ExD'); # for the case that all conjuncts are ExD
    # Note that $symbol is a guess only here.
    # Also, the current labeling scheme does not allow for private modifiers of this delimiter.
    my $symbol = $node->form() !~ m/^\pL+$/;
    $self->add_delimiter($node, $symbol);
    my @children = $node->children();
    foreach my $child (@children)
    {
        if($child->is_member())
        {
            # Note that this is a guess only.
            # ExD could also mean that the whole coordination is in ExD (broken) relation to its parent.
            my $orphan = 0;
            if($child->afun() eq 'ExD')
            {
                $orphan = 1;
            }
            else
            {
                $self->set_afun($child->afun());
            }
            $self->add_conjunct($child, $orphan, $child->children());
        }
        elsif($child->afun() =~ m/^Aux[GXY]$/)
        {
            # Note that the current labeling style does not allow to distinguish between:
            # - delimiters between conjuncts (commas, semicolons, dashes, conjunctions etc.)
            # - dependents of the head delimiter (comma right before conjunction; other words of multiword conjunction)
            # - dependents of the whole coordination if they are symbols (e.g. quotation marks around coordination)
            ###!!! At least quotation marks and parentheses at the outer margin could be excluded?
            my $symbol = $child->afun() =~ m/^Aux[GX]$/;
            $self->add_delimiter($child, $symbol, $child->children());
        }
        else
        {
            $self->add_shared_modifier($child);
        }
    }
}



#------------------------------------------------------------------------------
# Sets and labels parent-child relations between nodes so that they reflect the
# roles of the nodes in coordination. Uses Prague style.
#------------------------------------------------------------------------------
sub shape_prague
{
    my $self = shift;
    my @conjuncts = $self->get_conjuncts();
    my @delimiters = $self->get_delimiters();
    my @shared_modifiers = $self->get_shared_modifiers();
    # Select the last delimiter as the new root.
    if ( scalar(@delimiters)==0 )
    {

        # It can happen, however rare, that there are no delimiters between the coordinated nodes.
        # We have to be robust and to survive such cases.
        # Since there seems to be no better solution, the first member of the coordination will become the root.
        ###!!! Another possible solution would be to resort to Tesni&egra;re style and attach the conjuncts directly to the parent.
        # It will no longer be recognizable as coordination member. The coordination may now be deficient and have only one member.
        # If it was already a deficient coordination, i.e. if it had no delimiters and only one member, then something went wrong
        # (probably it is no coordination at all).
        if ( scalar(@conjuncts)<2 )
        {
            log_fatal('Coordination has fewer than two conjuncts and no delimiters.');
        }
        else
        {
            push( @delimiters, shift( @conjuncts ) );
        }
    }
    # There is no guarantee that we obtained ordered lists of members and delimiters.
    # They may have been added during tree traversal, which is not ordered linearly.
    my @conjunctions = $self->get_conjunctions();
    my @ordered_delimiters = sort {$a->ord() <=> $b->ord()} (@conjunctions ? @conjunctions : @delimiters);
    my $croot = pop(@ordered_delimiters);
    # Attach the new root to the parent of the coordination.
    $croot->set_parent($self->parent());
    $croot->set_afun('Coord');
    $croot->set_is_member($self->is_member());
    # Attach all coordination members to the new root.
    foreach my $conjunct ( @conjuncts )
    {
        $conjunct->set_parent($croot);
        $conjunct->set_is_member(1);
        # Assign the afun of the whole coordination to the member.
        # Prepositional members require special treatment: the afun goes to the argument of the preposition.
        # Some members are in fact orphan dependents of an ellided member.
        # Their current afun is ExD and they shall keep it, unlike the normal members.
        $conjunct->set_real_afun($self->afun()) unless ( $conjunct->get_real_afun() eq 'ExD' );
    }
    # Attach all remaining delimiters to the new root.
    # We need the $symbol attribute, thus we cannot use @ordered_delimiters.
    my @otherdelim = grep {$_->{type} eq 'delimiter' && $_->{node}!=$croot} (@{$self->_get_participants()});
    foreach my $delimrec ( @otherdelim )
    {
        my $delimiter = $delimrec->{node};
        my $symbol = $delimrec->{symbol};
        $delimiter->set_parent($croot);
        $delimiter->set_is_member(0);
        if ( $delimiter->form() eq ',' )
        {
            $delimiter->set_afun('AuxX');
        }
        elsif ( $symbol )
        {
            $delimiter->set_afun('AuxG');
        }
        else
        {
            $delimiter->set_afun('AuxY');
        }
    }
    # Attach all shared modifiers to the new root.
    foreach my $modifier ( @shared_modifiers )
    {
        $modifier->set_parent($croot);
        $modifier->set_is_member(0);
    }
}



#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects Moscow or Stanford
# style, without nested coordinations and without shared modifiers:
# - the root of the coordination is not marked
# - conjuncts have wild->{conjunct}
#   (the afun 'CoordArg' may have not survived Aux[CP] normalization)
# - conjunctions have wild->{coordinator}
#   (the afun 'Coord' may have not survived Aux[CP] normalization)
# - all such children are collected recursively
# - all other children along the way are private modifiers
#------------------------------------------------------------------------------
sub detect_mosford
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    log_fatal("Missing node") unless(defined($node));
    # This function is recursive. If we already have conjuncts then we know this is not the top level.
    my $top = scalar($self->get_conjuncts())==0;
    my @children = $node->children();
    my @participants = grep
    {
        $_->wild()->{coordinator} ||
        $_->wild()->{conjunct} ||
        $_->get_real_afun() =~ m/^Aux[GXY]$/
    }
    @children;
    my @recursive_participants = grep
    {
        $_->wild()->{coordinator} ||
        $_->wild()->{conjunct}
    }
    @participants;
    my $bottom = scalar(@recursive_participants)==0;
    if($top && $bottom)
    {
        # No participants found. This $node is not a root of coordination.
        return;
    }
    # Orphans are treated similarly to conjuncts but they can be only detected under Coord
    # and there will be no recursion over them.
    my $exdorphans = !$top && $node->parent()->wild()->{coordinator};
    if($exdorphans)
    {
        my @orphans = grep {$_->afun() eq 'ExD'} @children;
        # Orphans can be added right away. There will be no recursion over them.
        foreach my $orphan (@orphans)
        {
            $self->add_conjunct($orphan, 1, $orphan->children());
        }
    }
    my @modifiers = grep
    {
        !$_->wild()->{coordinator} &&
        !$_->wild()->{conjunct} &&
        $_->get_real_afun() !~ m/^Aux[GXY]$/ &&
        (!$exdorphans || $_->get_real_afun() ne 'ExD')
    }
    @children;
    if($bottom)
    {
        # Return my modifiers to the upper level. They will need them when they add me as participant.
        return @modifiers;
    }
    # If we are here we have participants: either conjuncts or delimiters or both.
    if($top)
    {
        # Add the root conjunct before recursion. That's how the lower levels will know they're not the top level.
        my $orphan = 0;
        $self->add_conjunct($node, $orphan, @modifiers);
        # Save the relation of the coordination to its parent.
        $self->set_parent($node->parent());
        $self->set_afun($node->get_real_afun());
        $self->set_is_member($node->is_member());
    }
    foreach my $participant (@participants)
    {
        my $recursive = $participant->wild()->{coordinator} || $participant->wild()->{conjunct};
        # Recursion first. Someone must sort the grandchildren as participants vs. modifiers.
        # Conjunction and conjunct require recursion. Aux nodes terminate it even if they have children.
        my @partmodifiers = $recursive ? $self->detect_mosford($participant) : $participant->children();
        if($participant->wild()->{conjunct})
        {
            my $orphan = 0;
            $self->add_conjunct($participant, $orphan, @partmodifiers);
        }
        else
        {
            my $afun = $participant->get_real_afun();
            my $symbol = $afun =~ m/^Aux[GX]$/;
            $self->add_delimiter($participant, $symbol, @partmodifiers);
        }
    }
    # If this is the top level, we now know all we can.
    # It's time for a few more heuristics.
    if($top)
    {
        $self->reconsider_distant_private_modifiers();
    }
    # Return the list of modifiers to the upper level.
    # They will need it when they add me as a participant.
    unless($top)
    {
        return @modifiers;
    }
}



#------------------------------------------------------------------------------
# Examines private modifiers of the first (word-order-wise) conjunct. If they
# lie after the last conjunct, the function reclassifies them as shared
# modifiers. This is a heuristic that should work well with coordinations that
# were originally encoded in left-to-right Moscow or Stanford styles.
#------------------------------------------------------------------------------
sub reconsider_distant_private_modifiers
{
    my $self = shift;
    my @conjuncts = $self->get_conjuncts('ordered' => 1);
    return if(scalar(@conjuncts)<2);
    # We will only compare the root nodes of the constituents, not the whole subtrees that could be interleaved.
    my $maxord = $conjuncts[-1]->ord();
    my @pord = $self->get_private_modifiers($conjuncts[0]);
    foreach my $po (@pord)
    {
        if($po->ord() > $maxord)
        {
            $self->change_private_modifier_to_shared($po, $conjuncts[0]);
        }
    }
}



1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Coordination

=head1 DESCRIPTION

Coordination is an object that collect information about a coordination structure in a dependency tree.
It knows all nodes involved in the coordination, i.e. it holds references to the corresponding Node objects.

=over 4

=item conjuncts (root nodes of subtrees that represent a conjunct and its dependents)

=item orphan conjuncts can be distinguished: ExD orphans of deleted real conjuncts

=item delimiters (conjunctions and punctuation delimiting conjuncts, such as commas)

=item conjunctions can have their own private dependents (multi-word-conjunctions such as Czech "nejen-ale"; comma-conjunction pair etc.);
then, we link to the head node of the conjunction subtree

=item shared modifiers (root nodes of subtrees that depend on the whole coordination,
either linguistically motivated (e.g. shared subject of three verb conjuncts)
or a technical rule (e.g. attach quotation marks to the root of the text between them))

=item private modifiers (direct dependents of any conjunct, or, in exceptional cases,
of a delimiter)

=back

All this information is stored independently of the current parent-child relations in the tree,
i.e. independently of the scheme currently used to represent a paratactic structure using dependencies and labels.
The Coordination object is thus useful to collect and store information about coordination during its transformation between two schemes.

Nevertheless, there are methods that can use the current parent-child links
and labels to identify the nodes participating in coordination and to register
them within this object.
And there are other methods that can relink the current nodes using a
particular annotation scheme.

Important:

Logically, participants and modifiers are subtrees.
We store references to the current root nodes of the subtrees.
If the inner topology of the subtree changes our references will no longer be valid.
We may still be pointing into the subtree but we will not hold its local root.
In particular, if the participant or modifier is a nested coordination,
it is covered by a separate Coordination object,
and a method of that object is invoked
to reshape the coordination according to a particular annotation scheme,
our reference will get broken.

This issue requires special care when manipulating coordinations.
We have to be aware of what we are doing outside the Coordination object and that it is rather short-lived.

A possible partial solution would be to setup a function that handles root changes.
The node we refer to would get a reference to the handler as a wild attribute.
Coordination-aware transformations could call it when they downgrade the node within its own subtree.
We would still be vulnerable to other manipulations from the outer world.
The handler would get references to the old and the new root of the subtree.
Wherever it would find reference to the old root in the coordination, it would redirect it to the new root.
It would also have to change the list of its private modifiers
(which could be even conjuncts of the nested coordination;
as long as they do not participate in our coordination, it is OK).

Another partial solution would be to define an abstract object class that could be
either Node or Coordination. Lists of participants and modifiers would refer to
objects of this class instead of just Nodes. If a nested coordination was detected,
the target object would be a Coordination.

=head1 METHODS

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
