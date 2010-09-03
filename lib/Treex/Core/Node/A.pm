package Treex::Core::Node::A;

use 5.008;
use strict;
use warnings;
use Report;
use List::MoreUtils qw( any all );

use Treex::Core::Document;
use Treex::Core::Bundle;
use Treex::Core::Node;

use Moose;
use MooseX::FollowPBP;
extends 'Treex::Core::Node';

# No need to override - Treex::Core::Node::ordering_attribute() also returns 'ord'
# sub ordering_attribute {'ord'}

sub get_pml_type_name {
    my ($self) = @_;
    return $self->is_root() ? 'a-root.type' : 'a-node.type';
}


# these two methods won't work until merging m- and a-layer is finished
sub get_mnode {
    my ($self) = @_;
    return $self;
    my $m_rf = $self->get_attr('m.rf') or return;
    return $self->get_document()->get_node_by_id( $m_rf);
}

sub get_n_node {
	my ($self) = @_;
	my $m_node = $self->get_mnode() or return;
	return $m_node->get_n_node();
}

#----------- Effective children and parents -------------

# the node is a root of a coordination/apposition construction
sub is_coap_root {    # analogy of PML_T::IsCoord
    my ($self) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    return defined $self->get_attr('afun') && $self->get_attr('afun') =~ /^(Coord|Apos)$/;
}

# -------- New implementation --------
# Details:
# Members of a coordination can be distinguished from shared modifiers
# according to the attribute is_member. The only problem is when some
# members are hanged on prepositions(afun=AuxP) or subord. conjunctions(AuxC).
# The PDT style is that Aux[CP] nodes can never have is_member=1, resulting in
# e.g. "It was in(parent=and) Prague(parent=in,is_member=1)
#       and(parent=was) in(parent=and) London(parent=in,is_member=1)."
# The style adpoted in TectoMT is that members have always is_member=1
# no matter what afun they have. This results in:
#  "It was in(parent=and,is_member=1) Prague(parent=in)
#   and(parent=was) in(parent=and,is_member=1) London(parent=in)."
# Both annotation styles have their pros and cons.
# Following subroutines suppose TectoMT style trees.
# For backward compatibility and not breaking old code
# I left the old implementation (get_eff_*) intact
# and choose new names get_e(children|parents).

=item $node->get_echildren($arg_ref?)

Returns a list of effective children of the C<$node>. It means that 
a) instead of coordination/aposition heads, their members are returned
b) shared modifiers of a coord/apos (technically hanged on the head of coord/apos)
   count as effective children of the members.

TODO describe here that: with argument C<dive> you can define nodes to be skipped (e.g. prepositions)

Optionally you can specify with C<$arg_ref> the same options
as in L<Treex::Core::Node::get_children()>.

=cut

sub get_echildren {
    my ( $self, $arg_ref ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ > 2;
    my $dive = ( delete $arg_ref->{dive} ) || sub {0};
    if ( $dive eq 'AuxCP' ) { $dive = \&_is_auxCP; }
    $self->_can_apply_eff($dive) or return $self->get_children();

    # 1) Get my own effective children (i.e. I am their only eff. parent).
    # These are in my subtree.
    my @echildren = $self->_get_my_own_echildren($dive);

    # 2) Add shared effective children
    # (i.e. I am their eff. parent, but not the only one).
    # This can happen only if I am member of a coordination
    # and these eff. children are shared modifiers of the coordination.
    push @echildren, $self->_get_shared_echildren($dive);

    # 3) Process eventual switches (ordered=>1, add_self=>1,...)
    return @echildren if !$arg_ref;
    return $self->_process_switches( $arg_ref, @echildren );
}

sub get_eparents {
    my ( $self, $arg_ref ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ > 2;
    my $dive = ( delete $arg_ref->{dive} ) || sub {0};
    if ( $dive eq 'AuxCP' ) { $dive = \&_is_auxCP; }
    $self->_can_apply_eff($dive) or return $self->get_parent();

    # 0) Check if there is a topological parent.
    # Otherwise, there is no chance getting effective parents.
    if ( !$self->get_parent() ) {
        my $id = $self->get_attr('id');
        Report::warn("The node $id has no effective nor topological parent, using the root");
        return $self->get_root();
    }

    # 1) If $self is a member of a coordination/aposition,
    # get the highest node representing $self -- i.e. the coord/apos root.
    # Otherwise, let $node be $self.
    my $node = $self->_get_transitive_coap_root($dive) || $self;

    # 2) Get the parent
    $node = $node->get_parent() or return $self->_fallback_parent();

    # 3) If it is a node to be dived, look above for the first non-dive ancestor.
    while ( $dive->($node) ) {
        $node = $node->get_parent() or return $self->_fallback_parent();
    }

    # If $node is not a head of a coordination/aposition,
    # it is the effective parent we are looking for.
    return $node if !$node->is_coap_root();

    # Otherwise, there can be more than one effective parent.
    # All effective parents (of $self) are shared modifiers
    # of the coordination rooted in $node.
    my @eff = $node->get_coap_members({dive=>$dive});
    return @eff if @eff;
    return $self->_fallback_parent();
}

# --- Utility methods for get_echildren and get_eparents

sub _is_auxCP {
    my ($self) = @_;
    my $afun = $self->get_attr('afun') || '';
    return $afun =~ /^Aux[CP]$/;
}

sub _get_direct_coap_root {
    my ( $self, $dive ) = @_;
    my $parent = $self->get_parent() or return;
    return $parent if $self->get_attr('is_member');
    return if !$dive || $dive->($self);
    while ( $dive->($parent) ) {
        return $parent->get_parent() if $parent->get_attr('is_member');
        $parent = $parent->get_parent() or return;
    }
    return;
}

sub _get_transitive_coap_root {
    my ( $self, $dive ) = @_;
    my $root = $self->_get_direct_coap_root($dive) or return;
    while ( $root->get_attr('is_member') ) {
        $root = $root->_get_direct_coap_root($dive) or return;
    }
    return $root;
}

sub _can_apply_eff {
    my ( $self, $dive ) = @_;
    my $error = $dive->($self)
        ? 'a node that is "to be dived"'
        : $self->is_coap_root() ? 'coap root' : 0;
    return 1 if !$error;
    my $method_name = ( caller 1 )[3];
    my $id          = $self->get_attr('id');
    Report::warn("$method_name called on $error ($id). Fallback to topological one.");
    return 0;
}

sub _fallback_parent {
    my ($self) = @_;
    my $id = $self->get_attr('id');
    Report::warn("The node $id has no effective parent, using the topological one.");
    return $self->get_parent();
}

# Get my own effective children (i.e. I am their only eff. parent).
sub _get_my_own_echildren {
    my ( $self, $dive ) = @_;
    my @members = ();
    my @queue   = $self->get_children();
    while (@queue) {
        my $node = shift @queue;
        if ( $dive->($node) ) {
            push @queue, $node->get_children();
        }
        elsif ( $node->is_coap_root() ) {
            push @members, $node->get_coap_members({dive=>$dive});

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
    my ( $self, $dive ) = @_;

    # Only members of coord/apos can have shared eff. children
    my $coap_root = $self->_get_direct_coap_root($dive) or return ();
    my @shared_echildren = ();

    # All shared modifiers of $coap_root are eff. children of $self.
    # We must process all possibly nested coap_roots.
    #  In the first iteration, $self is one of children of $coap_root.
    #  (In case of "diving", it's not $self, but its governing Aux[CP].)
    #  However, it has is_member==1, so it won't get into @shared_echildren.
    #  Similarly for other iterations. 
    while ($coap_root) {
        push @shared_echildren,
            map  { $_->get_coap_members({dive=>$dive}) }
            grep { !$_->get_attr('is_member') }
            $coap_root->get_children();
        $coap_root = $coap_root->_get_direct_coap_root($dive);
    }
    return @shared_echildren;
}

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

=cut

sub get_coap_members {
    my ( $self, $arg_ref ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ > 2;
    return $self if !$self->is_coap_root();
    my $direct_only = $arg_ref->{direct_only};
    my $dive = $arg_ref->{dive} || sub {0};
    if ( $dive eq 'AuxCP' ) { $dive = \&_is_auxCP; }
    my @members = ();

    my @queue = grep { $_->get_attr('is_member') } $self->get_children();
    while (@queue) {
        my $node = shift @queue;
        if ( $dive->($node) ) {
            push @queue, $node->get_children();
        }
        elsif ( !$direct_only && $node->is_coap_root() ) {
            push @queue, grep { $_->get_attr('is_member') } $node->get_children();
        }
        else {
            push @members, $node;
        }
    }
    return @members;
}


#----------- Effective children and parents -------------
#----------- Old implememntation

sub get_eff_children {
    my ( $self, $arg_ref ) = @_;
    Report::fatal("Incorrect number of arguments") if @_ > 2;
    my @nodes = map { $Treex::Core::Node::fsnode2tmt_node{$_} }
        PML_A2::GetEChildren( $self );
    return @nodes if !$arg_ref;
    return $self->_process_switches( $arg_ref, @nodes );
}

sub get_eff_parents {
    my ($self) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 1;

    my $node = $self;

    # getting the highest node representing the given node
    if ( $node->is_coap_member ) {
        while ( $node && $node->is_coap_member && $node->get_parent->is_coap_root ) {
            $node = $node->get_parent;
        }
    }
    $node && $node->get_parent or goto FALLBACK_get_eff_parents;

    # getting the parent
    $node = $node->get_parent;
    my @eff = $node->is_coap_root ? $node->get_transitive_coap_members : ($node);
    return @eff if @eff > 0;

    FALLBACK_get_eff_parents:
    if ( $self->get_parent ) {
        Report::warn "The node " . $self->get_attr('id') . " has no effective parent, using the topological one";
        return $self->get_parent;
    }
    else {
        Report::warn "The node " . $self->get_attr('id') . " has no effective nor topological parent, using the root";
        return $self->get_root;
    }
}

sub is_coap_member {
    my ($self) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 1;
    return (
        $self->get_attr('is_member')
            || ( ( $self->get_attr('afun') || "" ) =~ /^Aux[CP]$/ && grep { $_->is_coap_member } $self->get_children )
        )
        ? 1 : undef;
}

sub get_transitive_coap_members {    # analogy of PML_T::ExpandCoord
    my ($self) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 1;
    if ( $self->is_coap_root ) {
        return (
            map { $_->is_coap_root ? $_->get_transitive_coap_members : ($_) }
                grep { $_->is_coap_member } $self->get_children
        );
    }
    else {

        #Report::warn("The node ".$self->get_attr('id')." is not root of a coordination/apposition construction\n");
        return ($self);
    }
}

sub get_direct_coap_members {
    my ($self) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 1;
    if ( $self->is_coap_root ) {
        return ( grep { $_->is_coap_member } $self->get_children );
    }
    else {

        #Report::warn("The node ".$self->get_attr('id')." is not root of a coordination/apposition construction\n");
        return ($self);
    }
}

sub get_transitive_coap_root {    # analogy of PML_T::GetNearestNonMember
    my ($self) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 1;
    while ( $self->is_coap_member ) {
        $self = $self->get_parent;
    }
    return $self;
}

# linking to p-layer, moved from TectoMT/Node/SEnglishA.pm

sub get_terminal_pnode {
    my ($self) = @_;
    my $document = $self->get_document();
    if ( $self->get_attr('p/terminal.rf') ) {
        return $document->get_node_by_id( $self->get_attr('p/terminal.rf') );
    }
    else {
        Report::fatal('SEnglishA node pointing to no SEnglishP node');
    }
}

sub get_nonterminal_pnodes {
    my ($self) = @_;
    my $document = $self->get_document();
    if ( $self->get_attr('p/nonterminals.rf') ) {
        return grep {$_} map { $document->get_node_by_id($_) } @{ $self->get_attr('p/nonterminals.rf') }
;
    }
    else {
        return ();
    }
}

sub get_pnodes {
    my ($self) = @_;
    return ( $self->get_terminal_pnode, $self->get_nonterminal_pnodes );
}


# moved from Node/TCzechA.pm

sub reset_morphcat {
    my ($self) = @_;
    foreach my $category (
        qw(pos subpos gender number case possgender possnumber
        person tense grade negation voice reserve1 reserve2)
        )
    {
        my $old_value = $self->get_attr("morphcat/$category");
        if (!defined $old_value){
            $self->set_attr( "morphcat/$category", '.' );
        }
    }
}



# --------- funkce pro efektivni potomky a rodice by Jan Stepanek - prevzato z PML_A.inc a upraveno -------------

package PML_A2;

no warnings;

sub _FilterEChildren {    # node dive suff from
    my ( $node, $dive, $suff, $from ) = @_;
    my @sons;
    $node = $node->firstson;
    while ($node) {

        #    return @sons if $suff && @sons; # comment this line to get all members
        unless ( $node == $from ) {    # on the way up do not go back down again
            if (!$suff
                && $node->{afun} =~ /Coord|Apos/
                && !$node->{is_member}
                or $suff && $node->{afun} =~ /Coord|Apos/ && $node->{is_member}
                )
            {
                push @sons, _FilterEChildren( $node, $dive, 1, 0 )
            }
            elsif ( &$dive($node) and $node->firstson ) {
                push @sons, _FilterEChildren( $node, $dive, $suff, 0 );
            }
            elsif (
                ( $suff && $node->{is_member} )
                || ( !$suff && !$node->{is_member} )
                )
            {    # this we are looking for
                push @sons, $node;
            }
        }    # unless node == from
        $node = $node->rbrother;
    }
    @sons;
}    # _FilterEChildren

sub GetEChildren {    # node dive
    my ( $node, $dive ) = @_;
    my @sons;
    my $from;
    $dive = sub {0}
        unless defined($dive);
    push @sons, _FilterEChildren( $node, $dive, 0, 0 );
    if ( $node->{is_member} ) {
        my @oldsons = @sons;
        while ( $node->parent and ( $node->{afun} !~ /Coord|Apos|AuxS/ or $node->{is_member} ) ) {
            $from = $node;
            $node = $node->parent;
            push @sons, _FilterEChildren( $node, $dive, 0, $from );
        }
        if ( not $node->parent ) {
            print STDERR "Warning: PML_A2::GetEChildren Missing Coord/Apos: $node->{id}\n";
            @sons = @oldsons;
        }
    }
    return @sons;
}    # GetEChildren

1;

__END__

=head1 NAME

Treex::Core::Node::A

=head1 DESCRIPTION

Analytical node

=head1 METHODS

=over

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

=back 

=head1 COPYRIGHT

Copyright 2006-2009 Zdenek Zabokrtsky, Martin Popel.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
