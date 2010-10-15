package Treex::Core::Node;

our $VERSION = '0.1';

use Moose;
use MooseX::NonMoose;
use MooseX::FollowPBP;
use Report;

use Scalar::Util qw( weaken );
use List::MoreUtils qw(any);
use List::Util qw(first);
use Readonly;

Readonly my $_SWITCHES_REGEX => qr/^(ordered|add_self|(preceding|following|first|last)_only)$/x;
my $CHECK_FOR_CYCLES = 1;

use Cwd;
use Treex::PML;


extends 'Treex::PML::Node';

with 'Treex::Core::TectoMTStyleAccessors';

has bundle => (
    is => 'ro',
    reader => 'get_bundle',
    writer => '_set_bundle',
);

has id => (
    is => 'rw',
    trigger => \&_index_my_id,
);

sub _index_my_id {
    my $self = shift;
    $self->get_document->index_node_by_id($self->get_id,$self);
}

sub _pml_attribute_hash {
    my $self = shift;
    return $self;
}


sub disconnect {
    my ( $self, $arg_ref ) = @_;

    #TODO: There is actally no get_treelet_nodes() method
    #So this step 0 is probably never called and could be safely removed?
    # beware: phase 0 should be check for the case of disconecting a non-childfree node

    # 0. update ords if requested
    if ( $arg_ref->{update_ords} ) {
        my $my_ord  = $self->get_ordering_value();
        my @treelet = $self->get_treelet_nodes();
        my $my_mass = scalar @treelet;
        my @bag     = grep { $_->get_ordering_value() > $my_ord } $self->get_root->get_descendants();

        # ords after me
        foreach (@bag) {
            $_->set_ordering_value( $_->get_ordering_value() - $my_mass );
        }
    }

    if ( $self->is_root ) {
        Report::fatal "Tree root cannot be disconnected from its parent";
    } else {

        # removing the nodes to be disconnected from the document's indexing table
        foreach my $node ( $self, $self->get_descendants ) {
            my $id = $self->get_attr('id');
            if ( defined $id ) {
                my $document = $node->get_document;
                $document->index_node_by_id( $id, undef );
            }

        }

        $self->cut;

    }

    #    print STDERR "$self disconnected now!\n";
    return;
}


sub get_pml_type_name {
    return undef;
}

sub create_child {
    my $self     = shift;
    my $new_node = ( ref $self )->new(@_);
    $new_node->set_parent($self);

    my $new_id = $self->generate_new_id();
    $new_node->set_id(  $new_id );
#    $self->get_document->index_node_by_id($new_id, $new_node);

    my $type = $new_node->get_pml_type_name();
    return $new_node if !defined $type;
    my $fs_file = $self->get_bundle->get_document()->_get_pmldoc;
    $self->set_type_by_name( $fs_file->metaData('schema'), $type );
    return $new_node;
}
##-- end proposal

sub add_to_listattr {
    my ( $self, $attr_name, $attr_value ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 3;
    my $list = $self->attr($attr_name);
    Report::fatal("Attribute $attr_name is not a list!")
          if !defined $list || ref($list) ne 'Treex::PML::List';
    my @new_list = @{$list};
    if ( ref($attr_value) eq 'ARRAY' ) {
        push @new_list, @{$attr_value};
    } else {
        push @new_list, $attr_value;
    }
    return $self->set_attr( $attr_name, Treex::PML::List->new(@new_list) );
}

# Get more attributes at once
sub get_attrs {
    my ( $self, @attr_names ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ < 2;
    my @attr_values;
    if ( ref $attr_names[-1] ) {
        my $arg_ref          = pop @attr_names;
        my $change_undefs_to = $arg_ref->{undefs};
        @attr_values = map {
            defined $self->get_attr($_) ? $self->get_attr($_) : $change_undefs_to
        } @attr_names;
    } else {
        @attr_values = map { $self->get_attr($_) } @attr_names;
    }

    return @attr_values;
}

# ------------------------

#************************************
#---- TREE NAVIGATION ------

sub get_document {
    my ($self) = @_;
    my $bundle = $self->get_bundle();
    Report::fatal('Cannot call get_document on a node which is in no bundle') if not defined $bundle;
    return $self->get_bundle->get_document();
}

sub get_root {
    my ($self) = @_;
    return $self->root();
}

sub is_root {
    my ($self) = @_;
    return ( not $self->get_parent() );
}

sub get_parent {
    my ($self) = @_;
    return $self->parent;
}

sub set_parent {
    my ( $self, $parent ) = @_;
#    UNIVERSAL::isa( $parent, 'TectoMT::Node' ) or Report::fatal("Node's parent must be a TectoMT::Node (it is $parent)");

    if ( $self == $parent || $CHECK_FOR_CYCLES && $parent->is_descendant_of($self) ) {
        my $id   = $self->get_attr('id');
        my $p_id = $parent->get_attr('id');
        Report::fatal("Attempt to set parent of $id to the node $p_id, which would lead to a cycle.");
    }

    $self->_set_bundle( $parent->get_bundle() );
    my $fsself   = $self;
    my $fsparent = $parent;
    if ( $fsself->parent() ) {
        Treex::PML::Cut($fsself);
    }

    my $fsfile     = $self->get_document()->_get_pmldoc;
    my @fschildren = $fsparent->children();
    if (@fschildren) {
        Treex::PML::PasteAfter( $fsself, $fschildren[-1] );
    } else {
        Treex::PML::Paste( $fsself, $fsparent, $fsfile->FS() );
    }

    # vyresit prevesovani uzlu z dokumentu do dokumentu (pokud to povolime) !!!

    return;
}

sub _check_switches  {
    my ( $self, $arg_ref ) = @_;

    # Check switches for not allowed combinations
    Report::fatal('Specified both preceding_only and following_only.')
          if $arg_ref->{preceding_only} && $arg_ref->{following_only};
    Report::fatal('Specified both first_only and last_only.')
          if $arg_ref->{first_only} && $arg_ref->{last_only};

    # Check for explicit "ordered" when not needed (possible typo)
    Report::warn('Specifying (first|last|preceding|following)_only implies ordered.')
          if $arg_ref->{ordered}
              && any { $arg_ref->{ $_ . '_only' } } qw(first last preceding following);

    # Check for unknown switches
    my $unknown = first { $_ !~ $_SWITCHES_REGEX } keys %{$arg_ref};
    Report::warn("Unknown switch $unknown") if defined $unknown;

    return;
}

# Shared processing of switches: ordered, (preceding|following|first|last)_only
# for subs get_children, get_descendants and get_siblings.
# This is quite an uneffective implementation in case of e.g. first_only
sub _process_switches  {
    my ( $self, $arg_ref, @nodes ) = @_;

    # Check for unknown switches and not allowed combinations
    $self->_check_switches($arg_ref);

    # Add this node if add_self
    if ( $arg_ref->{add_self} ) {
        push @nodes, $self;
    }

    # Sort nodes if needed
    if (( $arg_ref->{ordered} || any { $arg_ref->{ $_ . '_only' } } qw(first last preceding following) )
            && @nodes && $nodes[0]->ordering_attribute()
        ) {
        @nodes = sort { $a->get_ordering_value() <=> $b->get_ordering_value() } @nodes;
    }

    # Leave preceding/following only if needed
    my $my_ord = $self->get_ordering_value();
    if ( $arg_ref->{preceding_only} ) {
        @nodes = grep { $_->get_ordering_value() <= $my_ord } @nodes;
    } elsif ( $arg_ref->{following_only} ) {
        @nodes = grep { $_->get_ordering_value() >= $my_ord } @nodes;
    }

    # first_only / last_only
    return $nodes[0]  if $arg_ref->{first_only};
    return $nodes[-1] if $arg_ref->{last_only};
    return @nodes;
}

sub get_children {
    my ( $self, $arg_ref ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ > 2;
    my @children = $self->children();
    return @children if !$arg_ref;
    return $self->_process_switches( $arg_ref, @children );
}

sub get_descendants {
    my ( $self, $arg_ref ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ > 2;
    my @descendants;
    if ( $arg_ref && $arg_ref->{except} ) {
        my $except_node = delete $arg_ref->{except};
        return () if $self == $except_node;
        @descendants = map {
            $_->get_descendants( { except => $except_node, add_self => 1 } )
        } $self->get_children();
    } else {
        @descendants = $self->descendants();
    }
    return @descendants if !$arg_ref;
    return $self->_process_switches( $arg_ref, @descendants );
}

sub get_siblings {
    my ( $self, $arg_ref ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ > 2;
    my $parent = $self->get_parent();
    return if !$parent;
    my @siblings = grep { $_ ne $self } $parent->get_children();
    return @siblings if !$arg_ref;
    return $self->_process_switches( $arg_ref, @siblings );
}

sub get_left_neighbor  { return $_[0]->get_siblings( { preceding_only => 1, last_only  => 1 } ); }
sub get_right_neighbor { return $_[0]->get_siblings( { following_only => 1, first_only => 1 } ); }

sub is_descendant_of {
    my ( $self, $another_node ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 2;
    my $parent = $self->get_parent();
    while ($parent) {
        return 1 if $parent == $another_node;
        $parent = $parent->get_parent();
    }
    return 0;
}

#*********************************************
#---- NODE ORDERING ------

sub get_ordering_value {
    my ($self) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    return $self->get_attr( $self->ordering_attribute() );
}

sub set_ordering_value {
    my ( $self, $val ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 2;
    $self->set_attr( $self->ordering_attribute(), $val );
    return;
}

sub precedes {
    my ( $self, $another_node ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 2;
    return $self->get_ordering_value() < $another_node->get_ordering_value();
}

# Methods get_next_node and get_prev_node are implemented
# so they can handle deprecated fractional ords.
# When no "fract-ords" will be used in the whole TectoMT
# this could be reimplemented a bit more effectively.
sub get_next_node {
    my ($self) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my $my_ord = $self->get_ordering_value();
    Report::fatal('Undefined ordering value') if !defined $my_ord;

    # Find closest higher ord
    my ( $next_node, $next_ord ) = ( undef, undef );
    foreach my $node ( $self->get_root()->get_descendants() ) {
        my $ord = $node->get_ordering_value();
        next if $ord <= $my_ord;
        next if defined $next_ord && $ord > $next_ord;
        ( $next_node, $next_ord ) = ( $node, $ord );
    }
    return $next_node;
}

sub get_prev_node {
    my ($self) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my $my_ord = $self->get_ordering_value();
    Report::fatal('Undefined ordering value') if !defined $my_ord;

    # Find closest lower ord
    my ( $prev_node, $prev_ord ) = ( undef, undef );
    foreach my $node ( $self->get_root()->get_descendants() ) {
        my $ord = $node->get_ordering_value();
        next if $ord >= $my_ord;
        next if defined $prev_ord && $ord < $prev_ord;
        ( $prev_node, $prev_ord ) = ( $node, $ord );
    }
    return $prev_node;
}

# TODO this method normalize_node_ordering should be removed.
# Also all block as XAnylang1X_to_XAnylang2X::Normalize_ordering
# or *::Recompute_ordering should be deleted.
# If you allways use $node->shift_* methods, you won't need any normalization.
sub normalize_node_ordering {
    my ($self) = @_;
    Report::fatal('Incorrect number of arguments')                             if @_ != 1;
    Report::fatal('Ordering normalization can be applied only on root nodes!') if $self->get_parent();
    my $new_ord = 0;
    foreach my $node ( $self->get_descendants( { ordered => 1, add_self => 1 } ) ) {
        $node->set_attr( $self->ordering_attribute, $new_ord );
        $new_ord++
    }
    return;
}

sub _check_shifting_method_args  {
    my ( $self, $reference_node, $arg_ref ) = @_;
    my @c     = caller 1;
    my $stack = "$c[3] called from $c[1], line $c[2]";
    Report::fatal( 'Incorrect number of arguments for ' . $stack ) if @_ < 2 || @_ > 3;
    Report::fatal( 'Undefined reference node for ' . $stack ) if !$reference_node;
    Report::fatal( 'Reference node must be from the same tree. In ' . $stack )
          if $reference_node->get_root() != $self->get_root();

    Report::fatal '$reference_node is a descendant of $self.'
          . ' Maybe you have forgotten {without_children=>1}. ' . "\n" . $stack
              if !$arg_ref->{without_children} && $reference_node->is_descendant_of($self);

    return if !defined $arg_ref;

    Report::fatal(
        'Second argument for shifting methods can be only options hash reference. In ' . $stack
    ) if ref $arg_ref ne 'HASH';
    my $unknown = first { $_ ne 'without_children' } keys %{$arg_ref};
    Report::warn("Unknown switch '$unknown' for $stack") if defined $unknown;
    return;
}

sub shift_after_node {
    my ( $self, $reference_node, $arg_ref ) = @_;
    return if $self == $reference_node;
    _check_shifting_method_args(@_);
    return $self->_shift_to_node( $reference_node, 1, $arg_ref->{without_children} ) if $arg_ref;
    return $self->_shift_to_node( $reference_node, 1, 0 );
}

sub shift_before_node {
    my ( $self, $reference_node, $arg_ref ) = @_;
    return if $self == $reference_node;
    _check_shifting_method_args(@_);
    return $self->_shift_to_node( $reference_node, 0, $arg_ref->{without_children} ) if $arg_ref;
    return $self->_shift_to_node( $reference_node, 0, 0 );
}

sub shift_after_subtree {
    my ( $self, $reference_node, $arg_ref ) = @_;
    _check_shifting_method_args(@_);

    my $last_node = $reference_node->get_descendants( { except => $self, last_only => 1, add_self => 1 } );
    return $self->_shift_to_node( $last_node, 1, $arg_ref->{without_children} ) if $arg_ref;
    return $self->_shift_to_node( $last_node, 1, 0 );
}

sub shift_before_subtree {
    my ( $self, $reference_node, $arg_ref ) = @_;
    _check_shifting_method_args(@_);

    my $first_node = $reference_node->get_descendants( { except => $self, first_only => 1, add_self => 1 } );
    return $self->_shift_to_node( $first_node, 0, $arg_ref->{without_children} ) if $arg_ref;
    return $self->_shift_to_node( $first_node, 0, 0 );
}

# This method does the real work for all shift_* methods.
# However, due to unfriendly name and arguments it's not public.
sub _shift_to_node  {
    my ( $self, $reference_node, $after, $without_children ) = @_;
    my @all_nodes = $self->get_root()->get_descendants();

    # Make sure that ord of all nodes is defined
    #my $maximal_ord = @all_nodes; -this does not work, since there may be gaps in ordering
    my $maximal_ord = 10000;
    foreach my $d (@all_nodes) {
        if ( !defined $d->get_ordering_value() ) {
            $d->set_ordering_value( $maximal_ord++ );
        }
    }

    # Which nodes are to be moved?
    # $self only (the {without_children=>1} switch)
    # or $self and all its descendants (the default)?
    my @nodes_to_move;
    if ($without_children) {
        @nodes_to_move = ($self);
    } else {
        @nodes_to_move = $self->get_descendants( { ordered => 1, add_self => 1 } );
    }

    # Let's make a hash, so we can easily recognize which nodes are to be moved.
    my %is_moving = map { $_ => 1 } @nodes_to_move;

    # Recompute ord of all nodes.
    # The technical root has ord=0 and the first node will have ord=1.
    my $counter = 1;
    @all_nodes = sort { $a->get_ordering_value() <=> $b->get_ordering_value() } @all_nodes;
    foreach my $node (@all_nodes) {

        # We skip nodes that are being moved.
        # Their ord is recomuted elsewhere (look 8 lines down).
        next if $is_moving{$node};

        # If moving "after" a reference node
        # then ord of the $node can be recomputed now
        # even if it is actually the $reference_node.
        if ($after) {
            $node->set_ordering_value( $counter++ );
        }

        # Now we insert (i.e. recompute ord of) all nodes which are being moved.
        # The nodes are inserted in the original order.
        if ( $node == $reference_node ) {
            foreach my $moving_node (@nodes_to_move) {
                $moving_node->set_ordering_value( $counter++ );
            }
        }

        # If moving "before" a node, then now it is the right moment
        # for recomputing ord of the $node
        if ( !$after ) {
            $node->set_ordering_value( $counter++ );
        }
    }
    return;
}

#************************************
#---- OTHER ------

sub get_depth {
    my ($self) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my $depth = 0;
    while ( $self = $self->get_parent() ) {
        $depth++;
    }
    return $depth;
}

sub get_fposition {
    my ($self) = @_;
    my $id = $self->get_attr('id');

    my $fsfile  = $self->get_document->_get_pmldoc();
    my $fs_root = $self->get_bundle;

    my $bundle_number = 1;
  TREES:
    foreach my $t ( $fsfile->trees() ) {
        last TREES if $t == $fs_root;
        $bundle_number++;
    }

    my $filename = Cwd::abs_path( $self->get_document->get_fsfile_name() );
    return "$filename##$bundle_number.$id";
}

sub generate_new_id {
    my ($self) = @_;

    Report::fatal('Incorrect number of arguments') if @_ != 1;

    my $doc = $self->get_document;

    my $latest_node_number = $doc->_get_latest_node_number;

    my $new_id;
    $self->get_root->get_id =~ /(.+)root/;
    my $id_base = $1 || "";

    while (1) {
        $latest_node_number++;
        $new_id = "${id_base}n$latest_node_number";
        last if not $doc->id_is_indexed($new_id);

    }

    $doc->_set_latest_node_number($latest_node_number);

    return $new_id;
}

sub is_coap_root {
    Report::fatal('Method TectoMT::Node::is_coap_root is virtual, it must be overriden.');
}

#**************************************
# clause nodes methods proposal
# TODO zdokumentovat, pokud se na techto metodach shodneme
# Prvni dve metody pouzivaji jen clause_number, treti jen is_clause_head.
# Neco se vyuziva na a-rovine, neco na t-rovine.
# ZZ navrhoval implementovat to jiz zde, v Node.pm, tak to zkousim (MP).
sub get_clause_root {
    my ($self) = @_;
    my $my_number = $self->get_attr('clause_number');
    Report::warn( 'Attribut clause_number not defined in ' . $self->get_attr('id') )
          if !defined $my_number;
    return $self if !$my_number;

    my $highest = $self;
    my $parent  = $self->get_parent();
    while ( $parent && ( $parent->get_attr('clause_number') || 0 ) == $my_number ) {
        $highest = $parent;
        $parent  = $parent->get_parent();
    }
    if ( $parent && !$highest->get_attr('is_member') && $parent->is_coap_root() ) {
        my $eff_parent = first { $_->get_attr('is_member') && ( $_->get_attr('clause_number') || 0 ) == $my_number } $parent->get_children();
        return $eff_parent if $eff_parent;
    }
    return $highest;
}

# Clauses may by split in more subtrees ("Peter eats and drinks.")
sub get_clause_nodes {
    my ($self) = @_;
    my $root = $self->get_root();
    my @descendants = $root->get_descendants( { ordered => 1 } );
    my $my_number = $self->get_attr('clause_number');
    return grep { $_->get_attr('clause_number') == $my_number } @descendants;
}

# TODO: same purpose as get_clause_root but instead of clause_number uses is_clause_head
sub get_clause_head {
    my ($self) = @_;
    my $node = $self;
    while ( !$node->get_attr('is_clause_head') && $node->get_parent() ) {
        $node = $node->get_parent();
    }
    return $node;
}

# taky by mohlo byt neco jako $node->get_descendants({within_clause=>1});
sub get_clause_descendants {
    my ($self) = @_;
    my @clause_children = grep { !$_->get_attr('is_clause_head') } $self->get_children();
    return ( @clause_children, map { $_->get_clause_descendants() } @clause_children );
}

#************************************
#---- TO BE REMOVED ------

sub _deprecated  {
    my $instead     = shift;
    my $method_name = ( caller 1 )[3];
    my $message     = "Method '$method_name' is deprecated and will be removed.";
    if ($instead) {
        $message .= " Use '$instead' instead.";
    }
    Report::warn($message);

    # and once again to print the stack
    Report::debug($message);
    return;
}

#TODO: There is actally no get_treelet_nodes() method
#So next 4 methods are probably never called and could be safely removed?

# shifting among one parent's children, node and its subtree is moved
# projective tree assumed
sub shift_left {
    my ($self) = @_;
    _deprecated('$node->shift_*');
    my $parent = $self->get_parent();
    Report::fatal('Cannot shift node without a parent') if !$parent;
    my $my_ord        = $self->get_ordering_value();
    my $left_neighbor = $self->get_left_neighbor();
    my @my_treelet    = $self->get_treelet_nodes();
    my @left_treelet;

    # parent can stand in the way
    if (( !defined $left_neighbor || $left_neighbor->get_ordering_value() < $parent->get_ordering_value() )
            && $parent->get_ordering_value() < $my_ord
        ) {
        @left_treelet = ($parent);
    } else {
        Report::fatal('Cannot shift left without a left neighbor') if !$left_neighbor;
        @left_treelet = ( $left_neighbor, $left_neighbor->get_descendants );

        # TODO: looks like useless sort?
        @left_treelet = sort { $a->get_ordering_value <=> $b->get_ordering_value } @left_treelet;
    }

    my $my_mass   = scalar @my_treelet;
    my $left_mass = scalar @left_treelet;

    # ords in my treelet
    foreach (@my_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() - $left_mass );
    }

    # ords after me
    foreach (@left_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() + $my_mass );
    }
    return;
}

# shifting among one parent's children, node and its subtree is moved
# projective tree assumed
sub shift_right {
    my ($self) = @_;
    _deprecated('$node->shift_*');
    my $parent = $self->get_parent;
    Report::fatal('Cannot shift node without a parent') if !$parent;
    my $my_ord         = $self->get_ordering_value;
    my $right_neighbor = $self->get_right_neighbor();
    my @my_treelet     = $self->get_treelet_nodes();
    my @right_treelet;

    # parent can stand in the way
    if (( !defined $right_neighbor || $parent->get_ordering_value() < $right_neighbor->get_ordering_value() )
            && $my_ord < $parent->get_ordering_value()
        ) {
        @right_treelet = ($parent);
    } else {
        Report::fatal('Cannot shift left without a left neighbor') if !$right_neighbor;
        @right_treelet = ( $right_neighbor, $right_neighbor->get_descendants );
        @right_treelet = sort { $a->get_ordering_value <=> $b->get_ordering_value } @right_treelet;
    }

    my $my_mass    = scalar @my_treelet;
    my $right_mass = scalar @right_treelet;

    # ords in my treelet
    foreach (@my_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() + $right_mass );
    }

    # ords before me
    foreach (@right_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() - $my_mass );
    }
    return;
}

sub shift_to_leftmost {
    my ($self) = @_;
    _deprecated('$node->shift_*');
    my $parent = $self->get_parent;
    Report::fatal('Cannot shift node without a parent') if !$parent;
    my @my_treelet                 = $self->get_treelet_nodes();
    my @my_ordered_treelet         = sort { $a->get_ordering_value <=> $b->get_ordering_value } @my_treelet;
    my $my_leftmost_descendant_ord = $my_ordered_treelet[0]->get_ordering_value();
    my @left_treelet               = grep { $_->get_ordering_value() < $my_leftmost_descendant_ord } $parent->get_treelet_nodes();

    my $my_mass   = scalar @my_treelet;
    my $left_mass = scalar @left_treelet;

    # ords in my treelet
    foreach (@my_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() - $left_mass );
    }

    # ords after me
    foreach (@left_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() + $my_mass );
    }
    return;
}

sub non_projective_shift_to_leftmost_of {
    my ( $self, $ref_parent ) = @_;
    _deprecated('$node->shift_*');
    my @my_treelet                 = $self->get_treelet_nodes();
    my @my_ordered_treelet         = sort { $a->get_ordering_value <=> $b->get_ordering_value } @my_treelet;
    my $my_leftmost_descendant_ord = $my_ordered_treelet[0]->get_ordering_value();
    my @left_partial_treelet       = grep { $_->get_ordering_value() < $my_leftmost_descendant_ord } $ref_parent->get_treelet_nodes();

    my $my_mass   = scalar @my_treelet;
    my $left_mass = scalar @left_partial_treelet;

    #print STDERR "<> my_mass:$my_mass left_mass:$left_mass\n";
    #print STDERR join(' ', map { $_->get_m_lemma().'.'.$_->get_ordering_value() } $self->get_root->get_ordered_descendants())."\n";

    # ords in my treelet
    foreach (@my_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() - $left_mass );
    }

    # ords after me
    foreach (@left_partial_treelet) {
        $_->set_ordering_value( $_->get_ordering_value() + $my_mass );
    }
    return;
}

# umozni misto $node->get_attr('functor') psat jen $node->geta_functor; #  opsano z Conway str. 396
sub AUTOMETHOD {
    my ( $self, $obj_id, @other_args ) = @_;
    my $subroutine_name = $_; # predavani nazvu volane procedury - specialita AUTOMETHOD

    my ( $mode, $name ) = $subroutine_name =~ m/\A ([gs]eta)_(.*) \z/xms
        or return;

    _deprecated('$node->get_attr()');
    $name =~ s/__/\//g;

    if ( $mode eq 'geta' ) {
        return sub { return $self->get_attr( $name, @other_args ); }
    } else {                    # mode eq seta
        return sub { return $self->set_attr( $name, @other_args ); }
    }
}

sub get_self_and_descendants {
    my ($self) = @_;
    _deprecated('$node->get_descendants({add_self=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    return ( $self, $self->get_descendants() );
}

sub get_ordered_children {
    my ($self) = @_;
    _deprecated('$node->get_children({ordered=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    return ( sort { $a->get_ordering_value <=> $b->get_ordering_value } $self->get_children );
}

sub get_first_child {
    my ($self) = @_;
    _deprecated('$node->get_children({first_only=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my ($son) = $self->get_ordered_children;
    return $son;
}

sub get_ordered_descendants {
    my ($self) = @_;
    _deprecated('$node->get_descendants({ordered=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    return ( sort { $a->get_ordering_value <=> $b->get_ordering_value } $self->get_descendants );
}

sub get_ordered_self_and_descendants {
    my ($self) = @_;
    _deprecated('$node->get_descendants({ordered=>1, add_self=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    return ( sort { $a->get_ordering_value <=> $b->get_ordering_value } ( $self, $self->get_descendants ) );
}

sub get_left_children {
    my ($self) = @_;
    _deprecated('$node->get_children({preceding_only=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my $my_ordering_value = $self->get_ordering_value;
    return ( grep { $_->get_ordering_value < $my_ordering_value } $self->get_ordered_children );
}

sub get_right_children {
    my ($self) = @_;
    _deprecated('$node->get_children({following_only=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my $my_ordering_value = $self->get_ordering_value;
    return ( grep { $_->get_ordering_value > $my_ordering_value } $self->get_ordered_children );
}

sub get_leftmost_child {
    my ($self) = @_;
    _deprecated('$node->get_children({first_only=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my @children = $self->get_ordered_children;
    return $children[0];
}

sub get_rightmost_child {
    my ($self) = @_;
    _deprecated('$node->get_children({last_only=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my @children = $self->get_ordered_children;
    return $children[-1];
}

sub get_ordered_siblings {
    my ($self) = @_;
    _deprecated('$node->get_siblings({ordered=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    return ( sort { $a->get_ordering_value <=> $b->get_ordering_value } $self->get_siblings );
}

sub get_left_siblings {
    my ($self) = @_;
    _deprecated('$node->get_siblings({preceding_only=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my $my_ordering_value = $self->get_ordering_value;
    return ( grep { $_->get_ordering_value < $my_ordering_value } $self->get_ordered_siblings )
}

sub get_right_siblings {
    my ($self) = @_;
    _deprecated('$node->get_siblings({following_only=>1})');
    Report::fatal('Incorrect number of arguments') if @_ != 1;
    my $my_ordering_value = $self->get_ordering_value;
    return ( grep { $_->get_ordering_value > $my_ordering_value } $self->get_ordered_siblings )
}



__PACKAGE__->meta->make_immutable;

1;


__END__


=head1 NAME

Treex::Core::Node

=head1 DESCRIPTION

This class represents a TectoMT node.
TectoMT trees (contained in bundles) are formed by nodes and edges.
Attributes can be attached only to nodes. Edge's attributes must
be stored as the lower node's attributes.
Tree's attributes must be stored as attributes of the root node.

=head1 METHODS

=head2 Construction

=over 4

=item  my $new_node = $existing_node->create_child( { 'attributes' => {'lemma'=>'house','tag'=>'NN' });

Creates a new node as a child of an existing node. Some of its attribute
can be filled. Direct calls of node constructors (->new) should be avoided.


=back



=head2 Access to the containers

=over 4

=item my $bundle = $node->get_bundle();

Returns the L<TectoMT::Bundle|TectoMT::Bundle> object in which the node's tree is contained.

=item my $document = $node->get_document();

Returns the L<TectoMT::Document|TectoMT::Document> object in which the node's tree is contained.

=back


=head2 Access to attributes

=over 4

=item my $value = $node->get_attr($name);

Returns the value of the node attribute of the given name.

=item my $node->set_attr($name,$value);

Sets the given attribute of the node with the given value.
If the attribute name is 'id', then the document's indexing table
is updated. If value of the type List is to be filled,
then $value must be a reference to the array of values.

=item my $node2 = $node1->get_deref_attr($name);

If value of the given attribute is reference (or list of references),
it returns the appropriate node (or a reference to the list of nodes).

=item my $node1->set_deref_attr($name, $node2);

Sets the given attribute with ID (list of IDs) of the given node (list of nodes).

=item my $node->add_to_listattr($name, $value);

If the given attribute is list, the given value is appended to it.

=item my $node->get_attrs(qw(name_of_attr1 name_of_attr2 ...));

Get more attributes at once.
If the last argument is C<{undefs=E<gt>$value}>, all undefs are substituted
by a C<$value> (typically the value is an empty string).

=back




=head2 Access to tree topology

=over 4

=item my $parent_node = $node->get_parent();

Returns the parent node, or undef if there is none (if $node itself is the root)

=item $node->set_parent($parent_node);

Makes $node a child of $parent_node.

=item $node->disconnect();

Disconnecting a node (or a subtree rooted by the given node)
from its parent. Underlying fs-node representation is disconnected too.
Node identifier is removed from the document indexing table.
The disconnected node cannot be further used.

=item my $root_node = $node->get_root();

Returns the root of the node's tree.

=item my $root_node = $node->is_root();

Returns true if the node has no parent.

=back

Next three methods (for access to children / descendants / siblings)
have an optional argument C<$arg_ref> for specifying switches.
By adding some switches, you can modify the behavior of these methods.
See L<"Switches"> for examples.

=over

=item my @child_nodes = $node->get_children($arg_ref);

Returns an array of child nodes.

=item my @descendant_nodes = $node->get_descendants($arg_ref);

Returns an array of descendant nodes ('transitive children').

=item my @sibling_nodes = $node->get_siblings($arg_ref);

Returns an array of nodes sharing the parent with the current node.

=back

=head3 Switches

Actually there are 6 switches:

=over

=item * ordered

=item * preceding_only, following_only

=item * first_only, last_only

=item * add_self

=back

=head4 Examples of usage

Names of variables in the examples suppose a language with left-to-right script.

 my @ordered_descendants       = $node->get_descendants({ordered=>1});
 my @self_and_left_children    = $node->get_children({preceding_only=>1, add_self=>1});
 my @ordered_self_and_children = $node->get_children({ordered=>1, add_self=>1});
 my $leftmost_child            = $node->get_children({first_only=>1});
 my @ordered_siblings          = $node->get_siblings({ordered=>1});
 my $left_neighbor             = $node->get_siblings({preceding_only=>1, last_only=>1});
 my $right_neighbor            = $node->get_siblings({following_only=>1, first_only=>1});
 my $leftmost_sibling_or_self  = $node->get_siblings({add_self=>1, first_only=>1});

=head4 Restrictions

=over

=item *

B<first_only> and B<last_only> switches makes the method return just one item - a scalar,
even if combined with the B<add_self> switch.

=item *

Specifying B<(first|last|preceding|following)_only> implies B<ordered>,
so explicit addition of B<ordered> gives a warning.

=item *

Specifying both B<preceding_only> and B<following_only> gives an error
(same for combining B<first_only> and B<last_only>).

=back

=head4 Shortcuts

There are shortcuts for comfort of those who use B<left-to-right> scripts:

=over

=item my $left_neighbor_node = $node->get_left_neighbor();

Returns the rightmost node from the set of left siblings (the nearest left sibling).
Actually, this is shortcut for C<$node-E<gt>get_siblings({preceding_only=E<gt>1, last_only=E<gt>1})>.

=item my $right_neighbor_node = $node->get_right_neighbor();

Returns the leftmost node from the set of right siblings (the nearest right sibling).
Actually, this is shortcut for C<$node-E<gt>get_siblings({following_only=E<gt>1, first_only=E<gt>1})>.

=back

=head2 Access to nodes ordering

=over 4

=item my $attrname = $node->get_ordering_attribute();

Returns the name of the ordering attribute ('ord' by default).
This method is supposed to be redefined in derived classes
(to return e.g. 'deepord' for tectogrammatical layer nodes).
All methods following in this section make use of this method.

=item my $ord = $node->get_ordering_value();

Returns the ordering value of the given node.
(In this class, i.e. the value of 'ord' attribute.)

=item $rootnode->normalize_node_ordering();

The values of the ordering attribute of all nodes in the tree
(possibly containing negative or fractional numbers) are normalized.
The node ordering is preserved, but only integer values are used now
(starting from 0 for the root, with increment 1).
This method can be called only on tree roots (nodes without parent),
otherwise fatal error is invoked.
BEWARE: This method is only needed when there are some fractional values
of the ordering atttribute in a tree. If possible, use methods from the next
section (L<Reordering nodes|"Reordering nodes">) instead of do-it-yourself
reordering that involves fractional ords.

=item my $boolean = $node->precedes($another_node);

Does this node precedes C<$another_node>?

=item my $following_node = $node->get_next_node();

Return the closest following node (according to the ordering attribute)
or C<undef> if C<$node> is the last one in the tree.

=item my $preceding_node = $node->get_prev_node();

Return the closest preceding node (according to the ordering attribute)
or C<undef> if C<$node> is the first one in the tree.

=back



=head2 Reordering nodes

Next four methods for changing the order of nodes
(typically the word order defined by the attribute C<ord>)
have an optional argument C<$arg_ref> for specifying switches.
Actually there is only one switch - B<without_children>
which is by default set to 0.
It means that the default behavior is to shift the node
with all its descendants.
Only if you want to leave the position of the descendants unchanged
and shift just the node, use e.g.

 $node->shift_after_node($reference_node, {without_children=>1});

Shifting involves only changing the ordering attribute of nodes.
There is no rehanging (changing parents). The node which is
going to be shifted must be already added to the tree
and the reference node must be in the same tree.

For languages with left-to-right script: B<after> means "to the right of"
and B<before> means "to the left of".

=over

=item $node->shift_after_node($reference_node);

Shifts (changes the ord of) the node just behind the reference node.

=item $node->shift_after_subtree($reference_node);

Shifts (changes the ord of) the node behind the subtree of the reference node.

=item $node->shift_before_node($reference_node);

Shifts (changes the ord of) the node just in front of the reference node.

=item $node->shift_before_subtree($reference_node);

Shifts (changes the ord of) the node in front of the subtree of the reference node.

=back





=head2 Other methods

=over 4

=item $node->generate_new_id();

Generate new (=so far unindexed) identifier (to be used when creating new nodes).
The new identifier is derived from the identifier of the root ($node->root), by adding
suffix x1 (or x2, if ...x1 has already been indexed, etc.) to the root's id.

=item my $position = $node->get_fposition();

Return the node address, i.e. file name and node's position within the file, similarly
to TrEd's FPosition() (but the value is only returned, not printed).

=item my $levels = $node->get_depth();

Return the depth of the node. The root has depth = 0, its children have depth = 1 etc.

=back


=head2 DEPRECATED METHODS

Instead of C<$node-E<gt>geta_xy()>, use C<$node-E<gt>get_attr('xy')>
(the shortcut notation did not come into the use of TectoMT programmers).

Instead of methods with I<ordered>, I<left>, I<right> in names,
use appropriate L<switches|"Switches"> (for access to children / descendants / siblings)
or L<shifting methods|"Reordering nodes"> (for shifting / reordering).


=over

=item my $value = $node->geta_ATTRNAME();

Generic set of faster-to-write attribute-getter methods, such as $node->geta_functor()
equivalent to $node->get_attr('functor'), or $node->geta_gram__number() equivalent to
$node->get_attr('gram/number'). In the case of structured attributes, '/' in the attribute name
is to be substituted with '__' (double underscore).

=item  $node->seta_ATTRNAME($name,$value);

Generic set of faster-to-write attribute-setter methods, such as $node->seta_functor('ACT')
equivalent to $node->set_attr('functor','ACT'), or $node->seta_gram__number('pl') equivalent to
$node->get_attr('gram/number','pl'). In the case of structured attributes, '/' in the attribute name
is to be substituted with '__' (double underscore).

=item my @child_nodes = $node->get_ordered_children();

Returns array of descendants sorted using the get_ordering_value method.

=item my @left_child_nodes = $node->get_left_children();

Returns array of sorted descendants with the ordering value
smaller than that of the given node.

=item my @right_child_nodes = $node->get_right_children();

Returns array of sorted descendants with the ordering value
bigger than that of the given node.

=item my $leftmost_child_node = $node->get_leftmost_child();

Returns the child node with the smallest ordering value.

=item my $rightmost_child_node = $node->get_rightmost_child();

Returns the child node with the biggest ordering value.

=item my @sibling_nodes = $node->get_ordered_siblings();

Returns an array of sibling nodes (nodes sharing their parent with
the current node), ordered according to get_ordering_value.

=item my @left_sibling_nodes = $node->get_left_siblings();

Returns an array (ordered according to get_ordering_value) of sibling nodes with
ordering values smaller than that of the current node.

=item my @right_sibling_nodes = $node->get_right_siblings();

Returns an array (ordered according to get_ordering_value) of sibling nodes with
ordering values bigger than that of the current node.

=item $node->shift_left();

Node and its subtree is moved among its siblings. Projective tree is assumed.

=item $node->shift_right();

Node and its subtree is moved among its siblings. Projective tree is assumed.

=back

=head1 COPYRIGHT

Copyright 2006-2009 Zdenek Zabokrtsky, Martin Popel.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
