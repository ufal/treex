package Treex::Core::Node::T;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Node';

# t-layer attributes
has [
    qw( is_member clause_number is_clause_head
        nodetype t_lemma functor subfunctor formeme tfa
        is_dsp_root sentmod is_parenthesis is_passive
        is_relclause_head is_name_of_person voice
        t_lemma_origin formeme_origin
        )
] => ( is => 'rw' );

sub get_pml_type_name {
    my ($self) = @_;
    return $self->is_root() ? 't-root.type' : 't-node.type';
}

#----------- Effective children and parents -------------

# the node is a root of a coordination/apposition construction
sub is_coap_root {    # analogy of PML_T::IsCoord
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    return ( $self->functor || '' ) =~ /^(CONJ|CONFR|DISJ|GRAD|ADVS|CSQ|REAS|CONTRA|APPS|OPER)$/;
}

sub get_echildren {
    my ( $self, $arg_ref ) = @_;
    log_fatal('Incorrect number of arguments') if @_ > 2;
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
    log_fatal('Incorrect number of arguments') if @_ > 2;
    my $dive = ( delete $arg_ref->{dive} ) || sub {0};
    if ( $dive eq 'AuxCP' ) { $dive = \&_is_auxCP; }
    $self->_can_apply_eff($dive) or return $self->get_parent();

    # 0) Check if there is a topological parent.
    # Otherwise, there is no chance getting effective parents.
    if ( !$self->get_parent() ) {
        my $id = $self->get_attr('id');
        log_warn("The node $id has no effective nor topological parent, using the root");
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
    my @eff = $node->get_coap_members( { dive => $dive } );
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
    log_warn("$method_name called on $error ($id). Fallback to topological one.");
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
    my ( $self, $dive ) = @_;
    my @members = ();
    my @queue   = $self->get_children();
    while (@queue) {
        my $node = shift @queue;
        if ( $dive->($node) ) {
            push @queue, $node->get_children();
        }
        elsif ( $node->is_coap_root() ) {
            push @members, $node->get_coap_members( { dive => $dive } );

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
            map { $_->get_coap_members( { dive => $dive } ) }
            grep { !$_->get_attr('is_member') }
            $coap_root->get_children();
        $coap_root = $coap_root->_get_direct_coap_root($dive);
    }
    return @shared_echildren;
}

sub get_coap_members {
    my ( $self, $arg_ref ) = @_;
    log_fatal('Incorrect number of arguments') if @_ > 2;
    return $self                               if !$self->is_coap_root();
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

#----------- a-layer nodes -------------

sub get_lex_anode {
    my ($self)   = @_;
    my $lex_rf   = $self->get_attr('a/lex.rf');
    my $document = $self->get_document();
    return $document->get_node_by_id($lex_rf) if $lex_rf;
    return;
}

sub set_lex_anode {
    my ( $self, $lex_anode ) = @_;
    my $new_id = defined $lex_anode ? $lex_anode->get_attr('id') : undef;
    $self->set_attr( 'a/lex.rf', $new_id );
    return;
}

sub get_aligned_nodes {
    my ($self) = @_;
    my $links_rf = $self->get_attr('align/links');
    if ($links_rf) {
        my $document = $self->get_document;
        return map { $document->get_node_by_id( $_->{'counterpart.rf'} ) } @$links_rf;
    }
    else {
        return ();
    }
}

# Named entity node corresponding to this
sub get_n_node {
    my ($self) = @_;
    my $lex_anode = $self->get_lex_anode() or return;
    return $lex_anode->n_node();
}

sub get_aux_anodes {
    my ( $self, $arg_ref ) = @_;
    ##my @nodes  = $self->get_r_attr('a/aux.rf');
    my $doc    = $self->get_document();
    my $aux_rf = $self->get_attr('a/aux.rf');
    my @nodes  = $aux_rf ? ( map { $doc->get_node_by_id($_) } @{$aux_rf} ) : ();
    return @nodes if !$arg_ref;
    log_fatal('Switches preceding_only and following_only cannot be used with get_aux_anodes (t-nodes vs. a-nodes).')
        if $arg_ref->{preceding_only} || $arg_ref->{following_only};
    return $self->_process_switches( $arg_ref, @nodes );
}

sub set_aux_anodes {
    my $self       = shift;
    my @aux_anodes = @_;
    $self->set_attr( 'a/aux.rf', [ map { $_->get_attr('id') } @aux_anodes ] );
}

sub add_aux_anodes {
    my $self = shift;
    my @prev = $self->get_aux_anodes();
    $self->set_aux_anodes( @prev, @_ );
}

sub get_anodes {
    my ( $self, $arg_ref ) = @_;
    my $lex_anode = $self->get_lex_anode();
    my @nodes = ( ( defined $lex_anode ? ($lex_anode) : () ), $self->get_aux_anodes() );
    return @nodes if !$arg_ref;
    log_fatal('Switches preceding_only and following_only cannot be used with get_anodes (t-nodes vs. a-nodes).')
        if $arg_ref->{preceding_only} || $arg_ref->{following_only};
    return $self->_process_switches( $arg_ref, @nodes );
}

sub get_transitive_coap_members {    # analogy of PML_T::ExpandCoord
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    if ( $self->is_coap_root ) {
        return (
            map { $_->is_coap_root ? $_->get_transitive_coap_members : ($_) }
                grep { $_->is_member } $self->get_children
        );
    }
    else {

        #log_warn("The node ".$self->get_attr('id')." is not root of a coordination/apposition construction\n");
        return ($self);
    }
}

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

sub get_transitive_coap_root {    # analogy of PML_T::GetNearestNonMember
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    while ( $self->is_coap_member ) {
        $self = $self->get_parent;
    }
    return $self;
}

sub src_tnode {
    my ($self) = @_;
    my $source_node_id = $self->get_attr('src_tnode.rf') or return;
    return $self->get_document->get_node_by_id($source_node_id);
}

sub set_src_tnode {
    my ( $self, $source_node ) = @_;
    $self->set_attr( 'src_tnode.rf', $source_node->id );
}

# Deprecated
sub get_source_tnode {
    my $self = shift;
    return $self->src_tnode;
}

sub set_source_tnode {
    my $self = shift;
    return $self->set_src_tnode(@_);
}

1;

__END__

=head1 NAME

Treex::Core::Node::T

=head1 DESCRIPTION

Tectogrammatical node


=head1 METHODS

=over

=item get_n_node()
If this t-node is a part of a named entity,
this method returns the corresponding n-node (L<Treex::Core::Node::N>).
If this node is a part of more than one named entities,
only the most nested one is returned.
For example: "Bank of China"
 $n_node_for_china = $t_node_china->get_n_node();
 print $n_node_for_china->get_attr('normalized_name'); # China
 $n_node_for_bank_of_china = $n_node_for_china->get_parent();
 print $n_node_for_bank_of_china->get_attr('normalized_name'); # Bank of China 

=back 

=head1 COPYRIGHT

Copyright 2006-2009 Zdenek Zabokrtsky, Martin Popel.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
