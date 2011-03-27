package Treex::Core::Node::EffectiveRelations;
use Moose::Role;
use Treex::Core::Log;

requires 'is_coap_root';

# Implementation details:
# Members of a coordination can be distinguished from shared modifiers
# according to the attribute is_member. The only problem is when some
# members are hanged on prepositions(afun=AuxP) or subord. conjunctions(AuxC).
# The PDT style is that Aux[CP] nodes can never have is_member=1, resulting in
# e.g. "It was in(parent=and) Prague(parent=in,is_member=1)
#       and(parent=was) in(parent=and) London(parent=in,is_member=1)."
# The style adpoted in Treex is that members have always is_member=1
# no matter what afun they have. This results in:
#  "It was in(parent=and,is_member=1) Prague(parent=in)
#   and(parent=was) in(parent=and,is_member=1) London(parent=in)."
# Both annotation styles have their pros and cons.

sub get_echildren {
    my ( $self, $arg_ref ) = @_;
    if (!defined $arg_ref) {
        $arg_ref = {};
    }
    log_fatal('Incorrect number of arguments') if @_ > 2;
    $self->_can_apply_eff($arg_ref) or return $self->get_children();

    # 1) Get my own effective children (i.e. I am their only eff. parent).
    # These are in my subtree.
    my @echildren = $self->_get_my_own_echildren($arg_ref);

    # 2) Add shared effective children
    # (i.e. I am their eff. parent, but not the only one).
    # This can happen only if I am member of a coordination
    # and these eff. children are shared modifiers of the coordination.
    push @echildren, $self->_get_shared_echildren($arg_ref);

    # 3) Process eventual switches (ordered=>1, add_self=>1,...)
    #return @echildren if !$arg_ref; TODO this cannot happen now, see $arg_ref = {} if !defined $arg_ref;
    delete $arg_ref->{dive};
    delete $arg_ref->{or_topological};
    return $self->_process_switches( $arg_ref, @echildren );
}

sub get_eparents {
    my ( $self, $arg_ref ) = @_;
    if (!defined $arg_ref) {
        $arg_ref = {};
    }
    log_fatal('Incorrect number of arguments') if @_ > 2;
    $self->_can_apply_eff($arg_ref) or return $self->get_parent();

    # 0) Check if there is a topological parent.
    # Otherwise, there is no chance getting effective parents.
    if ( !$self->get_parent() ) {
        my $id = $self->id;

        #TODO: log_fatal if !$robust
        log_warn("The node $id has no effective nor topological parent, using the root");
        return $self->get_root();
    }

    # 1) If $self is a member of a coordination/aposition,
    # get the highest node representing $self -- i.e. the coord/apos root.
    # Otherwise, let $node be $self.
    my $node = $self->_get_transitive_coap_root($arg_ref) || $self;

    # 2) Get the parent
    $node = $node->get_parent() or return $self->_fallback_parent();

    # 3) If it is a node to be dived, look above for the first non-dive ancestor.
    while ( $arg_ref->{dive}->($node) ) {
        $node = $node->get_parent() or return $self->_fallback_parent();
    }

    # If $node is not a head of a coordination/aposition,
    # it is the effective parent we are looking for.
    return $node if !$node->is_coap_root();

    # Otherwise, there can be more than one effective parent.
    # All effective parents (of $self) are shared modifiers
    # of the coordination rooted in $node.
    my @eff = $node->get_coap_members($arg_ref);
    return @eff if @eff;
    return $self->_fallback_parent();
}

# --- Utility methods for get_echildren and get_eparents

sub _is_auxCP {
    my ($self) = @_;
    my $afun = $self->afun || '';
    return $afun =~ /^Aux[CP]$/;
}

sub _get_direct_coap_root {
    my ( $self, $arg_ref ) = @_;
    my $parent = $self->get_parent() or return;
    return $parent if $self->get_attr('is_member');
    return if !$arg_ref->{dive} || $arg_ref->{dive}->($self);
    while ( $arg_ref->{dive}->($parent) ) {
        return $parent->get_parent() if $parent->get_attr('is_member');
        $parent = $parent->get_parent() or return;
    }
    return;
}

sub _get_transitive_coap_root {
    my ( $self, $arg_ref ) = @_;
    my $root = $self->_get_direct_coap_root($arg_ref) or return;
    while ( $root->get_attr('is_member') ) {
        $root = $root->_get_direct_coap_root($arg_ref) or return;
    }
    return $root;
}

sub _can_apply_eff {
    my ( $self, $arg_ref ) = @_;
    if ( !$arg_ref->{dive} ) {
        $arg_ref->{dive} = sub {0};
    }
    elsif ( $arg_ref->{dive} eq 'AuxCP' ) {
        $arg_ref->{dive} = \&_is_auxCP;
    }
    my $error = $arg_ref->{dive}->($self)
        ? 'a node that is "to be dived"'
        : $self->is_coap_root() ? 'coap root' : 0;
    return 1 if !$error;
    return 0 if $arg_ref->{or_topological};    #TODO: document
    my $method_name = ( caller 1 )[3];
    my $id          = $self->id;
    log_warn( "$method_name called on $error ($id). Fallback to topological one.", 1 );
    return 0;
}

sub _fallback_parent {
    my ($self) = @_;
    my $id = $self->get_attr('id');
    log_warn("The node $id has no effective parent, using the topological one.");
    return $self->get_parent();
}

# Get my own effective children (i.e. I am their only eff. parent).
sub _get_my_own_echildren {
    my ( $self, $arg_ref ) = @_;
    my @members = ();
    my @queue   = $self->get_children();
    while (@queue) {
        my $node = shift @queue;
        if ( $arg_ref->{dive}->($node) ) {
            push @queue, $node->get_children();
        }
        elsif ( $node->is_coap_root() ) {
            push @members, $node->get_coap_members($arg_ref);

            #push @queue, grep { $_->get_attr('is_member') } $node->get_children();
        }
        else {
            push @members, $node;
        }
    }
    return @members;
}

# Get shared effective children
# (i.e. I am their eff. parent but not the only one).
sub _get_shared_echildren {
    my ( $self, $arg_ref ) = @_;

    # Only members of coord/apos can have shared eff. children
    my $coap_root = $self->_get_direct_coap_root($arg_ref) or return ();
    my @shared_echildren = ();

    # All shared modifiers of $coap_root are eff. children of $self.
    # We must process all possibly nested coap_roots.
    #  In the first iteration, $self is one of children of $coap_root.
    #  (In case of "diving", it's not $self, but its governing Aux[CP].)
    #  However, it has is_member==1, so it won't get into @shared_echildren.
    #  Similarly for other iterations.
    while ($coap_root) {
        push @shared_echildren,
            map  { $_->get_coap_members($arg_ref) }
            grep { !$_->get_attr('is_member') }
            $coap_root->get_children();
        $coap_root = $coap_root->_get_direct_coap_root($arg_ref);
    }
    return @shared_echildren;
}

sub get_coap_members {
    my ( $self, $arg_ref ) = @_;
    log_fatal('Incorrect number of arguments') if @_ > 2;
    return $self if !$self->is_coap_root();
    my $direct_only = $arg_ref->{direct_only};
    my $dive = $arg_ref->{dive} || sub {0};
    if ( $dive eq 'AuxCP' ) { $dive = \&_is_auxCP; }
    my @members = ();

    my @queue = grep { $_->is_member } $self->get_children();
    while (@queue) {
        my $node = shift @queue;
        if ( $dive->($node) ) {
            push @queue, $node->get_children();
        }
        elsif ( !$direct_only && $node->is_coap_root() ) {
            push @queue, grep { $_->is_member } $node->get_children();
        }
        else {
            push @members, $node;
        }
    }
    return @members;
}

1;

__END__

=head1 NAME

Treex::Core::Node::EffectiveRelations

=head1 DESCRIPTION

Moose role for nodes with a notion of so called
I<effective> parents and I<effective> children.
This notion is used both
on the a-layer (L<Treex::Core::Node::A>) and
on the t-layer (L<Treex::Core::Node::T>).

TODO: explain it, some examples, reference to PDT manual 

Note that to skip prepositions and subordinating conjunctions on the a-layer,
you must use option C<dive>, e.g.:

    my $eff_children = $node->get_echildren({dive=>'AuxCP'});

Methods C<get_eparents> and C<get_echildren> produce a warning
"called on coap root ($id). Fallback to topological one."
when called on a root of coordination or apposition,
because effective children/parents are not properly defined in this case.
This warning can be supressed by option C<or_topological>.

=head1 METHODS

=over

=item my @effective_children = $node->get_echildren($arg_ref?)

Returns a list of effective children of the C<$node>. It means that 
a) instead of coordination/aposition heads, their members are returned
b) shared modifiers of a coord/apos (technically hanged on the head of coord/apos)
   count as effective children of the members.

OPTIONS:

=over

=item dive=>$sub_ref

Using C<dive>, you can define nodes to be skipped (or I<dived>).
C<dive> is a reference to a subroutine that decides
whether the given node should be skipped or not.
Typically this is used for prepositions and subord. conjunctions on a-layer.
You can set C<dive> to the string C<AuxCP> which is a shortcut
for C<sub {my $self=shift;return $self->afun =~ /^Aux[CP]$/;}>. 

=item ordered, add_self, following_only, preceding_only, first_only, last_only

You can specify the same options as in L<Treex::Core::Node::get_children()>.

=back


=item my @effective_parents = $node->get_eparents($arg_ref?)

Returns a list of effective parents of the C<$node>.

OPTIONS

=over

=item dive

see C<get_echildren>

=item or_topological

If the notion of effective parent is not defined
(if $node is a head of coordination),
return the topological parent without warnings.

=back



=item $node->get_coap_members($arg_ref?)

If the node is a coordination/apposition head
(see L<is_coap_root()>) a list of all coordinated members is returned.
Otherwise, the node itself is returned. 

OPTIONS

=over

=item direct_only

In case of nested coordinations return only "first-level" members.
The default is to return I<transitive> members.
For example "(A and B) or C":
$or->get_coap_members();                 # returns A,B,C
$or->get_coap_members({direct_only=>1}); # returns and,C

=item dive

see C<get_echildren>

=back

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README

