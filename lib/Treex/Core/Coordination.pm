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
#     Technically: orphan => 0|1
#                  symbol => 0|1
# pmod ... reference to the list of private modifiers of the participant
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
        my $form = $node->form(); $form = '' if(!defined($form));
        my $address = $node->get_address();
        log_fatal("Node $node ('$form') is already a participant of this coordination!\n$address");
    }
    # Is it private modifier of a participant?
    if(grep {$_ == $node} (map {@{$_->{pmod}}} @participants))
    {
        my $form = $node->form(); $form = '' if(!defined($form));
        my $address = $node->get_address();
        log_fatal("Node $node ('$form') is already a private modifier of a participant of this coordination!\n$address");
    }
    # Is it a shared modifier?
    if(grep {$_ == $node} @smod)
    {
        my $form = $node->form(); $form = '' if(!defined($form));
        my $address = $node->get_address();
        log_fatal("Node $node ('$form') is already a shared modifier of this coordination!\n$address");
    }
    # Is it registered as parent of the whole coordination?
    # Note: We want the world consistent as far as our knowledge reaches.
    # But we want to be independent of the parent-child links between the nodes.
    # So we cannot guarantee that changing the parent-child links will not introduce cycles!
    # If e.g. the registered parent is grandchild of a participant, we will not know about it.
    # Then the Node object will launch alarm when we attempt to shape the coordination.
    if(defined($self->parent()) && $node == $self->parent())
    {
        my $form = $node->form(); $form = '' if(!defined($form));
        my $address = $node->get_address();
        log_fatal("Node $node ('$form') is already a parent of this coordination!\n$address");
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
    my @list = $self->get_shared_modifiers();
    foreach my $participant (@{$self->_get_participants()})
    {
        push(@list, @{$participant->{pmod}});
    }
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
# links between nodes and labels of the relations). Expects Prague style,
# including normalization of AuxP/AuxC and nested coordinations. Thus it calls
# $node->set/get_real_afun().
# That makes the method suitable for repeated conversion between the tree (i.e.
# dependency relations and afuns between Node objects) and the Coordination
# object, during the later stages of normalization and after normalization.
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
            if($child->get_real_afun() eq 'ExD')
            {
                $orphan = 1;
            }
            elsif($self->afun() eq 'ExD') # take the first non-ExD encountered
            {
                # Coordination will never have afun AuxP or AuxC.
                # Neither will it have Coord (it marks the head but it's not afun of the whole structure).
                # If the first conjunct is a nested coordination, get_real_afun() will look for the afun among nested conjuncts.
                $self->set_afun($child->get_real_afun());
            }
            $self->add_conjunct($child, $orphan, $child->children());
        }
        # No need for get_real_afun() here: these three auxiliaries should never appear with preposition or as nested conjuncts!
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
# roles of the nodes in coordination. Uses Prague style. Returns the head node.
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
        log_warn('Coordination has no delimiters.');
        # It can happen, however rare, that there are no delimiters between the coordinated nodes.
        # We have to be robust and to survive such cases if possible.
        if ( scalar(@conjuncts)==0 )
        {
            # Give the user at least some pointer to the tree.
            log_warn($self->parent()) if(defined($self->parent()));
            # Robustness has limits. Where would we attach shared modifiers?
            log_fatal('Trying to shape an empty coordination (no conjuncts and no delimiters).');
        }
        elsif ( scalar(@conjuncts)==1 )
        {
            # Accompany the above warning by the address of the conjunct.
            log_warn($conjuncts[0]->get_address());
            # If there was one conjunct and one delimiter, it would be a deficient (typically clausal) coordination.
            # The conjunct would depend on the delimiter.
            # In this case however there is one "conjunct" and no delimiters.
            # It is thus a normal node and we will act as if there was no coordination at all.
            $conjuncts[0]->set_parent($self->parent());
            $conjuncts[0]->set_real_afun($self->afun());
            $conjuncts[0]->set_is_member($self->is_member());
            # Attach all shared modifiers to the node.
            foreach my $modifier ( @shared_modifiers )
            {
                $modifier->set_parent($conjuncts[0]);
                $modifier->set_is_member(0);
            }
            return $conjuncts[0];
        }
        else
        {
            # Accompany the above warning by the address of the conjunct.
            log_warn($conjuncts[0]->get_address());
            # Since there seems to be no better solution, the first member of the coordination will become the root.
            # It will no longer be recognizable as coordination member. The coordination may now be deficient and have only one member.
            ###!!! Another possible solution would be to resort to Tesnière style and attach the conjuncts directly to the parent.
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
    return $croot;
}



#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects the Alpino (Dutch)
# variant of the Prague style, i.e. the head of the coordination bears the
# label of the relation between the coordination and its parent. The afuns
# (and wild attributes) of conjuncts just mark them as conjuncts.
# The method assumes that nothing has been normalized yet. In particular it
# assumes that there are no AuxP/AuxC afuns (there are PrepArg/SubArg instead).
# Thus the method does not call $node->set/get_real_afun().
#------------------------------------------------------------------------------
sub detect_alpino
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    # Are there any children that are conjuncts?
    my @children = $node->children();
    my @conjuncts = grep {$_->wild()->{conjunct}} (@children);
    return unless(@conjuncts);
    $self->set_parent($node->parent());
    $self->set_is_member($node->is_member());
    $self->set_afun($node->afun());
    # Note that $symbol is a guess only here.
    # Also, the current labeling scheme does not allow for private modifiers of this delimiter.
    my $symbol = $node->form() !~ m/^\pL+$/;
    $self->add_delimiter($node, $symbol);
    foreach my $child (@children)
    {
        # The wild attribute conjunct should have been filled during deprel_to_afun().
        if($child->wild()->{conjunct})
        {
            my $orphan = 0;
            $self->add_conjunct($child, $orphan, $child->children());
        }
        # No need for get_real_afun() here: these three auxiliaries should never appear with preposition or as nested conjuncts!
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
    # We now know all we can.
    # It's time for a few more heuristics.
    # Even though the Alpino style belongs to the Prague family, it does not seem to take the opportunity to distinguish shared modifiers.
    # There are frequent non-projective dependents of the first conjunct that appear in the sentence after the last conjunct.
    $self->reconsider_distant_private_modifiers();
}



#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects Moscow or Stanford
# style, without nested coordinations and without shared modifiers (example
# treebank is Danish):
# - the root of the coordination is not marked
# - conjuncts have wild->{conjunct}
#   (the afun 'CoordArg' may have not survived Aux[CP] normalization)
# - conjunctions have wild->{coordinator}
#   (the afun 'Coord' may have not survived Aux[CP] normalization)
# - all such children are collected recursively
# - all other children along the way are private modifiers
# The method assumes that nothing has been normalized yet. In particular it
# assumes that there are no AuxP/AuxC afuns (there are PrepArg/SubArg instead).
# Thus the method does not call $node->set/get_real_afun().
#------------------------------------------------------------------------------
sub detect_mosford
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    log_fatal("Missing node") unless(defined($node));
    # This function is recursive. If we already have conjuncts then we know this is not the top level.
    my $top = scalar($self->get_conjuncts())==0;
    ###!!!DEBUG
    my $debug = 0;
    if($debug)
    {
        my $form = $node->form();
        $form = '' if(!defined($form));
        if($top)
        {
            $node->set_form("T:$form");
        }
        else
        {
            $node->set_form("X:$form");
        }
    }
    ###!!!END
    my @children = $node->children();
    my @participants = grep
    {
        $_->wild()->{coordinator} ||
        $_->wild()->{conjunct} ||
        # We cannot use get_real_afun() because the foreign data is not yet fully normalized
        # and there are things like AuxP with two children, first AuxX, second AuxC.
        # get_real_afun() would return AuxX, then we would think it is a delimiter rather than modifier,
        # even though the preposition governs a whole modifier subtree.
        # Also, get_real_afun() processes coordinations, and our coordination is not yet valid.
        #$_->get_real_afun() =~ m/^Aux[GXY]$/
        $_->afun() =~ m/^Aux[GXY]$/
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
    my $exdorphans = !$top && $node->wild()->{coordinator};
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
        # We cannot use get_real_afun() because the foreign data is not yet fully normalized (see above).
        #my $afun = $_->get_real_afun();
        my $afun = $_->afun();
        !$_->wild()->{coordinator} &&
        !$_->wild()->{conjunct} &&
        $afun !~ m/^Aux[GXY]$/ &&
        (
          !$exdorphans ||
          $afun ne 'ExD'
        )
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
        # We cannot use get_real_afun() because the foreign data is not yet fully normalized (see above).
        #$self->set_afun($node->get_real_afun());
        $self->set_afun($node->afun());
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
            # We cannot use get_real_afun() because the foreign data is not yet fully normalized (see above).
            #my $afun = $participant->get_real_afun();
            my $afun = $participant->afun();
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
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects left-to-right
# Moscow style with conjunctions and commas attached to the following conjunct.
# This style allows limited representation of nested coordination. It cannot
# distinguish (A,(B,C)) from (A,B,C). Having nested coordination as the
# last conjunct is a problem. Example treebank is Swedish. (Note however that
# the Swedish treebank distinguishes conjunct labels CJ and CC. We do not
# understand the difference and convert both to CoordArg. They may be able to
# describe nested coordination in full!)
# - the root of the coordination is not marked
# - conjuncts have wild->{conjunct}
#   (the afun 'CoordArg' may have not survived normalization)
# - if a conjunct has two or more conjuncts as children, there is nested
#   coordination. The parent conjunct first combines with the first child
#   conjunct (and its descendants, if any). The resulting coordination is a
#   conjunct that combines with the next child conjunct (and its descendants).
#   The process goes on until all child conjuncts are processed.
# - conjunctions have wild->{coordinator}
#   (the afun 'Coord' may have not survived normalization)
#   Any such child of a conjunct is collected; no conjuncts are expected under
#   it.
# - punctuation lying to the left of a conjunct and attached to it is
#   considered delimiter
# - all other children along the way are private modifiers
# The method assumes that nothing has been normalized yet. In particular it
# assumes that there are no AuxP/AuxC afuns (there are PrepArg/SubArg instead).
# Thus the method does not call $node->set/get_real_afun().
#------------------------------------------------------------------------------
sub detect_moscow
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    my $nontop = shift; # other than top level of recursion?
    log_fatal("Missing node") unless(defined($node));
    my $top = !$nontop;
    ###!!!DEBUG
    my $debug = 0;
    if($debug)
    {
        my $form = $node->form();
        $form = '' if(!defined($form));
        if($top)
        {
            $node->set_form("T:$form");
        }
        else
        {
            $node->set_form("X:$form");
        }
    }
    ###!!!END
    my @children = $node->children();
    my @conjuncts = grep {$_->wild()->{conjunct}} @children;
    my $bottom = scalar(@conjuncts)==0;
    if($top && $bottom)
    {
        # No participants found. This $node is not a root of coordination.
        # (We do not expect delimiters under a node that is not a conjunct (first or not).)
        return;
    }
    # Even if there are no conjuncts and no recursion ($bottom) there may be delimiters which we have to add.
    my @delimiters = grep
    {
        ! $_->wild()->{conjunct} &&
        # Very rarely (and probably erroneously) a conjunction is attached to the left.
        # Ignoring it here would mean that it keeps the Coord afun without actually heading a coordination.
        # The issue does not affect punctuation.
        (
            $_->wild()->{coordinator} ||
            $_->afun() =~ m/^Aux[GXY]$/ &&
            $_->ord() < $node->ord()
        )
    }
    @children;
    my @modifiers = grep
    {
        ! $_->wild()->{conjunct} &&
        !(
            $_->wild()->{coordinator} ||
            $_->afun() =~ m/^Aux[GXY]$/ &&
            $_->ord() < $node->ord()
        )
    }
    @children;
    # If we are here we have participants: either conjuncts or delimiters or both.
    if($top)
    {
        # Add the root conjunct.
        # Note: root of the tree is never a conjunct! If this is the tree root, we are dealing with a deficient (probably clausal) coordination.
        unless($node->is_root())
        {
            my $orphan = 0;
            $self->add_conjunct($node, $orphan, @modifiers);
            # Save the relation of the coordination to its parent.
            $self->set_parent($node->parent());
            $self->set_afun($node->afun());
            $self->set_is_member($node->is_member());
        }
        else
        {
            ###!!! The coordination still needs to know its parent (the root) and afun (which we are guessing here but we should find a real conjunct instead).
            $self->set_parent($node);
            $self->set_afun('Pred');
            $self->set_is_member(0);
        }
    }
    ###!!! POZOR! Když to zůstane takhle, budeme rozpouštět vnořené koordinace!
    ###!!! Je potřeba zjistit, zda máme více než jedno dítě, které je členem koordinace.
    ###!!! Dokud máme dvě nebo více takových dětí, je třeba se spojit s prvním z nich a vytvořit vnořenou koordinaci.
    ###!!! To znamená nový objekt Coordination, kompletní běh detect_moscow(), potom asi už i shape_prague() a novým kořenem si nahradit náš člen.
    ###!!! Další obtíž se skrývá v tom, že nás pravděpodobně zavolal někdo, kdo chce postupně rozpoznat všechny koordinace ve větě.
    ###!!! Čili jednak je tu disproporce, protože pro nevnořené koordinace si shape_prague() volá ten někdo sám.
    ###!!! A za druhé ten někdo chce pak detekci zavolat také na všechna rozvití (sdílená i soukromá) a všechny sirotky té koordinace, kterou mu vrátíme.
    ###!!! OTÁZKA: Vnořená koordinace má svá sdílená i soukromá rozvití. Dostaneme opravdu všechna do seznamu soukromých rozvití člena, který je tvořen vnořenou koordinací?
    foreach my $conjunct (@conjuncts)
    {
        my $orphan = 0;
        my $nontop = 1;
        my @partmodifiers = $self->detect_moscow($conjunct, $nontop);
        $self->add_conjunct($conjunct, $orphan, @partmodifiers);
    }
    foreach my $delimiter (@delimiters)
    {
        my $symbol = $delimiter->afun() =~ m/^Aux[GX]$/;
        my @partmodifiers = $delimiter->children();
        $self->add_delimiter($delimiter, $symbol, @partmodifiers);
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
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects left-to-right
# Stanford style.
# This style allows limited representation of nested coordination. It cannot
# distinguish ((A,B),C) from (A,B,C). Having nested coordination as the first
# conjunct is a problem. Example treebank is Bulgarian.
# - the root of the coordination is not marked
# - conjuncts have wild->{conjunct}
#   (the afun 'CoordArg' may have not survived normalization)
# - conjunctions have wild->{coordinator}
#   (the afun 'Coord' may have not survived normalization)
# - punctuation lying to the left of a conjunct and attached to the first
#   conjunct is considered delimiter
# - the second and any consequent conjuncts, as well as all conjunctions and
#   conjunct-delimiting punctuation are attached to the first conjunct.
#   There is no recursion. If a non-first conjunct has a child that is also
#   conjunct, then there is nested coordination.
# - all other children of the first conjunct are its private modifiers
# The method assumes that nothing has been normalized yet. In particular it
# assumes that there are no AuxP/AuxC afuns (there are PrepArg/SubArg instead).
# Thus the method does not call $node->set/get_real_afun().
#------------------------------------------------------------------------------
sub detect_stanford
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    my $nontop = shift; # other than top level of recursion?
    log_fatal("Missing node") unless(defined($node));
    my $top = !$nontop;
    ###!!!DEBUG
    my $debug = 0;
    if($debug)
    {
        my $form = $node->form();
        $form = '' if(!defined($form));
        if($top)
        {
            $node->set_form("T:$form");
        }
        else
        {
            $node->set_form("X:$form");
        }
    }
    ###!!!END
    my @children = $node->children();
    my @conjuncts = grep {$_->wild()->{conjunct}} @children;
    my $bottom = scalar(@conjuncts)==0;
    if($bottom)
    {
        # No conjuncts found, so we do not look for delimiters.
        return;
    }
    # Delimiting conjunctions are attached at the same level as conjuncts.
    my @delimiters = grep {! $_->wild()->{conjunct} && $_->wild()->{coordinator}} @children;
    my @modifiers = grep {! $_->wild()->{conjunct} && !$_->wild()->{coordinator}} @children;
    # If we are here we have conjuncts.
    if($top)
    {
        # Add the root conjunct.
        # Note: root of the tree is never a conjunct! If this is the tree root, we are dealing with a deficient (probably clausal) coordination.
        unless($node->is_root())
        {
            my $orphan = 0;
            $self->add_conjunct($node, $orphan, @modifiers);
            # Save the relation of the coordination to its parent.
            $self->set_parent($node->parent());
            $self->set_afun($node->afun());
            $self->set_is_member($node->is_member());
        }
    }
    # Add all non-root conjuncts.
    foreach my $conjunct (@conjuncts)
    {
        my $orphan = 0;
        my $nontop = 1;
        my @partmodifiers = $conjunct->children();
        $self->add_conjunct($conjunct, $orphan, @partmodifiers);
    }
    foreach my $delimiter (@delimiters)
    {
        my $symbol = $delimiter->afun() =~ m/^Aux[GX]$/;
        my @partmodifiers = $delimiter->children();
        $self->add_delimiter($delimiter, $symbol, @partmodifiers);
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



#------------------------------------------------------------------------------
# If there is a comma that transitively depends on a conjunct and lies word-
# order-wise between two conjuncts (or between a conjunct and a conjunction),
# it should be considered a coordination delimiter and raised accordingly.
# This is a heuristic that applies e.g. to the Dutch Alpino treebank where
# punctuation symbols are attached to neighboring tokens.
#------------------------------------------------------------------------------
sub capture_commas
{
    my $self = shift;
    my $participants = $self->_get_participants();
    # Get the limits of every subtree.
    my @descendants;
    foreach my $participant (@{$participants})
    {
        # Get descendants of the current conjunct. Examine the span of the subtree.
        # To not depend on the current way of annotation of coordination in the dependency tree,
        # do not call $conjunct->get_descendants(). Look at the private conjunct modifiers
        # known to the Coordination object instead.
        my @current_descendants = ($participant->{node});
        foreach my $pm (@{$participant->{pmod}})
        {
            push(@current_descendants, $pm->get_descendants({'add_self' => 1}));
        }
        @current_descendants = sort {$a->{ord} <=> $b->{ord}} (@current_descendants);
        push(@descendants, \@current_descendants);
    }
    # Search for commas between conjuncts.
    for(my $i = 1; $i<=$#descendants; $i++)
    {
        # Search for comma between this and the previous conjunct.
        # Skip this position if the two subtrees overlap.
        next if($descendants[$i][0]->ord()<$descendants[$i-1][-1]->ord());
        # Is the last node in the left subtree a comma?
        if($participants->[$i-1]{type} eq 'conjunct' && $descendants[$i-1][-1]->form() eq ',')
        {
            # Make the comma a delimiter in the coordination.
            # Re-attachment will be taken care of later during re-shaping of the coordination.
            # If the comma is currently known as private modifier, remove it from the list of private modifiers.
            @{$participants->[$i-1]{pmod}} = grep {$_!=$descendants[$i-1][-1]} (@{$participants->[$i-1]{pmod}});
            $self->add_delimiter($descendants[$i-1][-1], 1);
        }
        # Is the first node in the right subtree a comma?
        if($participants->[$i]{type} eq 'conjunct' && $descendants[$i][0]->form() eq ',')
        {
            # Make the comma a delimiter in the coordination.
            # Re-attachment will be taken care of later during re-shaping of the coordination.
            # If the comma is currently known as private modifier, remove it from the list of private modifiers.
            @{$participants->[$i]{pmod}} = grep {$_!=$descendants[$i][0]} (@{$participants->[$i]{pmod}});
            $self->add_delimiter($descendants[$i][0], 1);
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
