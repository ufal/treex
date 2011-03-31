package Treex::Core::Node;
use Moose;
use MooseX::NonMoose;
use Treex::Core::Common;
use Cwd;
use Treex::PML;

extends 'Treex::PML::Node';

Readonly my $_SWITCHES_REGEX => qr/^(ordered|add_self|(preceding|following|first|last)_only)$/x;
my $CHECK_FOR_CYCLES = 1;

has _zone => (
    is       => 'rw',
    writer   => '_set_zone',
    reader   => '_get_zone',
    weak_ref => 1,
);

has id => (
    is      => 'rw',
    trigger => \&_index_my_id,
);

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    if ( not defined $arg_ref or not defined $arg_ref->{_called_from_core_} ) {
        log_fatal 'Because of node indexing, no nodes can be created outside of documents. '
            . 'You have to use $zone->create_tree(...) or $node->create_child() '
            . 'instead of Treex::Core::Node...->new().';
    }
    return;
}

sub _index_my_id {
    my $self = shift;
    pos_validated_list( \@_, { isa => 'Any', optional => 1 } );    #TODO
    $self->get_document->index_node_by_id( $self->id, $self );
    return;
}

# ---- access to attributes ----

sub _pml_attribute_hash {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return $self;
}

sub get_attr {
    my ( $self, $attr_name ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 2;

    #simple attributes can be accessed directly
    if ( $attr_name =~ /^[\w\.]+$/ ) {
        return $self->{$attr_name};
    }
    else {
        my $attr_hash = $self->_pml_attribute_hash();
        return $attr_hash->attr($attr_name);
    }
}

sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 3;
    if ( $attr_name eq 'id' ) {
        if ( not defined $attr_value or $attr_value eq '' ) {
            log_fatal 'Setting undefined or empty ID is not allowed';
        }
        $self->get_document->index_node_by_id( $attr_value, $self );
    }
    elsif ( ref($attr_value) eq 'ARRAY' ) {
        $attr_value = Treex::PML::List->new( @{$attr_value} );
    }

    #simple attributes can be accessed directly
    if ( $attr_name =~ /^[\w\.]+$/ ) {
        return $self->{$attr_name} = $attr_value;
    }
    else {
        return Treex::PML::Node::set_attr( $self, $attr_name, $attr_value );    # better to find superclass, but speed?
    }
}

sub get_deref_attr {
    my ( $self, $attr_name ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 2;
    my $attr_value = $self->_pml_attribute_hash()->attr($attr_name);

    return if !$attr_value;
    my $document = $self->get_document();
    return [ map { $document->get_node_by_id($_) } @{$attr_value} ]
        if ref($attr_value) eq 'Treex::PML::List';
    return $document->get_node_by_id($attr_value);
}

sub set_deref_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 3;
    if ( ref($attr_value) eq 'ARRAY' ) {
        my @list = map { $_->get_attr('id') } @{$attr_value};
        $attr_value = Treex::PML::List->new(@list);
    }
    else {
        $attr_value = $attr_value->get_attr('id');
    }

    # attr setting always through TectoMT set_attr, as it can be overidden (and it is in Node/N.pm)
    #return $fsnode{ ident $self}->set_attr( $attr_name, $attr_value );
    return $self->set_attr( $attr_name, $attr_value );
}

##-- begin proposal
# Example usage:
# TectoMT::Node::T methods get_lex_anode and get_aux_anodes could use:
# my $a_lex = $t_node->get_r_attr('a/lex.rf'); # returns the node or undef
# my @a_aux = $t_node->get_r_attr('a/aux.rf'); # returns the nodes or ()
sub get_r_attr {
    my ( $self, $attr_name ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 2;
    my $attr_value = $self->_pml_attribute_hash()->attr($attr_name);

    return if !$attr_value;
    my $document = $self->get_document();
    if (wantarray) {
        log_fatal("Attribute '$attr_name' is not a list, but get_r_attr() called in a list context.")
            if ref($attr_value) ne 'Treex::PML::List';
        return map { $document->get_node_by_id($_) } @{$attr_value};
    }

    log_fatal("Attribute $attr_name is a list, but get_r_attr() not called in a list context.")
        if ref($attr_value) eq 'Treex::PML::List';
    return $document->get_node_by_id($attr_value);
}

# Example usage:
# $t_node->set_r_attr('a/lex.rf', $a_lex);
# $t_node->set_r_attr('a/aux.rf', @a_aux);
sub set_r_attr {
    my ( $self, $attr_name, @attr_values ) = @_;
    log_fatal('Incorrect number of arguments') if @_ < 3;
    my $fs = $self->_pml_attribute_hash();

    # TODO $fs->type nefunguje - asi protoze se v konstruktorech nenastavuje typ
    if ( $fs->type($attr_name) eq 'Treex::PML::List' ) {
        my @list = map { $_->get_attr('id') } @attr_values;

        # TODO: overriden Node::N::set_attr is bypassed by this call
        return $fs->set_attr( $attr_name, Treex::PML::List->new(@list) );
    }
    log_fatal("Attribute '$attr_name' is not a list, but set_r_attr() called with @attr_values values.")
        if @attr_values > 1;

    # TODO: overriden Node::N::set_attr is bypassed by this call
    return $fs->set_attr( $attr_name, $attr_values[0]->get_attr('id') );
}

# ---------------------

sub get_bundle {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return $self->get_zone->get_bundle;
}

# reference to embedding zone is stored only with tree root, not with nodes
sub get_zone {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    my $zone;
    if ( $self->is_root ) {
        $zone = $self->_get_zone;
    }
    else {
        $zone = $self->get_root->_get_zone;    ## no critic (ProtectPrivateSubs)
    }

    log_fatal "a node can't reveal its zone" if !$zone;
    return $zone;

}

sub remove {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    if ( $self->is_root ) {
        log_fatal 'Tree root cannot be removed using $root->remove().'
            . ' Use $zone->remove_tree($layer) instead';
    }
    my $root     = $self->get_root();
    my $document = $self->get_document();

    # Remove the subtree from the document's indexing table
    foreach my $node ( $self, $self->get_descendants ) {
        if ( defined $node->id ) {
            $document->index_node_by_id( $node->id, undef );
        }
    }

    # Disconnect the node from its parent (& siblings) and delete all attributes
    # It actually does: $self->cut(); undef %$_ for ($self->descendants(), $self);
    $self->destroy;

    # TODO: order normalizing can be done in a more efficient way
    # (update just the following ords)
    $root->_normalize_node_ordering();

    # By reblessing we make sure that
    # all methods called on removed nodes will result in fatal errors.
    bless $self, 'Treex::Core::Node::Deleted';
    return;
}

sub get_pml_type_name {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return;
}

sub get_layer {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    if ( ref($self) =~ /Node::(\w)$/ ) {
        return lc($1);
    }
    else {
        log_fatal "Cannot recognize node's layer: $self";
    }
}

sub language {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return $self->get_zone()->language;
}

sub selector {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return $self->get_zone()->selector;
}

sub create_child {
    my $self = shift;

    #NOT VALIDATED INTENTIONALLY - passing args to to new (and it's also black magic, so I'm not touching it)

    # TODO:
    #my $new_node = ( ref $self )->new(@_);
    # Previous line is very strange and causes errors which are hard to debug.
    # Magically, it works on UFAL machines, but nowhere else - I don't know why.
    # Substituting the hash by hashref is a workaround,
    # but the black magic is still there.
    my $arg_ref;
    if ( scalar @_ == 1 && ref $_[0] eq 'HASH' ) {
        $arg_ref = $_[0];
    }
    elsif ( @_ % 2 ) {
        log_fatal "Odd number of elements for create_child";
    }
    else {
        $arg_ref = {@_};
    }

    # Structured attributes (e.g. morphcat/pos) must be handled separately
    # TODO: And also attributes which don't have accessors (those are not Moose attributes).
    # Note: mlayer_pos was not added to Treex::Core::Node::T because it goes
    # against the "tectogrammatical ideology" and we use it as a temporary hack.
    my %structured_attrs;
    foreach my $attr ( keys %{$arg_ref} ) {
        if ( $attr =~ m{/} || $attr eq 'mlayer_pos' ) {
            $structured_attrs{$attr} = delete $arg_ref->{$attr};
        }
    }

    $arg_ref->{_called_from_core_} = 1;
    my $new_node = ( ref $self )->new($arg_ref);
    $new_node->set_parent($self);

    my $new_id = $self->generate_new_id();
    $new_node->set_id($new_id);

    foreach my $attr ( keys %structured_attrs ) {
        $new_node->set_attr( $attr, $structured_attrs{$attr} );
    }

    my $type = $new_node->get_pml_type_name();
    return $new_node if !defined $type;
    my $fs_file = $self->get_bundle->get_document()->_pmldoc;
    $self->set_type_by_name( $fs_file->metaData('schema'), $type );
    return $new_node;
}

#************************************
#---- TREE NAVIGATION ------

sub get_document {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self   = shift;
    my $bundle = $self->get_bundle();
    log_fatal('Cannot call get_document on a node which is in no bundle') if not defined $bundle;
    return $self->get_bundle->get_document();
}

sub get_root {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return $self->root();
}

sub is_root {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return !$self->parent;
}

sub get_parent {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return $self->parent;
}

sub set_parent {
    my $self = shift;
    my ($parent) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Node' },
    );

    # TODO check for this (but set_parent is called also from create_child)
    #if ($self->get_document() != $parent->get_document()) {
    #    log_fatal("Cannot move a node from one document to another");
    #}

    if ( $self == $parent || $CHECK_FOR_CYCLES && $parent->is_descendant_of($self) ) {
        my $id   = $self->id;
        my $p_id = $parent->id;
        log_fatal("Attempt to set parent of $id to the node $p_id, which would lead to a cycle.");
    }

    # TODO: Too much FSlib (aka Treex::PML) here
    $self->cut();
    my $fsfile     = $parent->get_document()->_pmldoc;
    my @fschildren = $parent->children();
    if (@fschildren) {
        Treex::PML::PasteAfter( $self, $fschildren[-1] );
    }
    else {
        Treex::PML::Paste( $self, $parent, $fsfile->FS() );
    }

    return;
}

sub _check_switches {

    #This method may be replaced by subtype and checked as parameter
    my $self = shift;
    my ($arg_ref) = pos_validated_list(
        \@_,
        { isa => 'Maybe[HashRef]' },
    );

    # Check for role Ordered
    log_fatal('This type of node does not support ordering')
        if (
        ( $arg_ref->{ordered} || any { $arg_ref->{ $_ . '_only' } } qw(first last preceding following) )
        &&
        !$self->does('Treex::Core::Node::Ordered')
        );

    # Check switches for not allowed combinations
    log_fatal('Specified both preceding_only and following_only.')
        if $arg_ref->{preceding_only} && $arg_ref->{following_only};
    log_fatal('Specified both first_only and last_only.')
        if $arg_ref->{first_only} && $arg_ref->{last_only};

    # Check for explicit "ordered" when not needed (possible typo)
    log_warn('Specifying (first|last|preceding|following)_only implies ordered.')
        if $arg_ref->{ordered}
            && any { $arg_ref->{ $_ . '_only' } } qw(first last preceding following);

    # Check for unknown switches
    my $unknown = first { $_ !~ $_SWITCHES_REGEX } keys %{$arg_ref};
    log_warn("Unknown switch $unknown") if defined $unknown;

    return;
}

# Shared processing of switches: ordered, (preceding|following|first|last)_only
# for subs get_children, get_descendants and get_siblings.
# This is quite an uneffective implementation in case of e.g. first_only
sub _process_switches {
    my $self = shift;
    my ( $arg_ref, @nodes ) = pos_validated_list(
        \@_,
        { isa => 'Maybe[HashRef]' },
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1,
    );

    # Check for unknown switches and not allowed combinations
    $self->_check_switches($arg_ref);

    # Add this node if add_self
    if ( $arg_ref->{add_self} ) {
        push @nodes, $self;
    }

    # Sort nodes if needed
    if (( $arg_ref->{ordered} || any { $arg_ref->{ $_ . '_only' } } qw(first last preceding following) )
        && @nodes && defined $nodes[0]->ord
        )
    {
        @nodes = sort { $a->ord() <=> $b->ord() } @nodes;
    }

    # Leave preceding/following only if needed
    if ( $arg_ref->{preceding_only} ) {
        @nodes = grep { $_->ord() <= $self->ord } @nodes;
    }
    elsif ( $arg_ref->{following_only} ) {
        @nodes = grep { $_->ord() >= $self->ord } @nodes;
    }

    # first_only / last_only
    return $nodes[0]  if $arg_ref->{first_only};
    return $nodes[-1] if $arg_ref->{last_only};
    return @nodes;
}

sub get_children {
    my $self = shift;
    my ($arg_ref) = pos_validated_list(
        \@_,
        { isa => 'Maybe[HashRef]', optional => 1 },
    );

    my @children = $self->children();
    return @children if !$arg_ref;
    return $self->_process_switches( $arg_ref, @children );
}

sub get_descendants {
    my $self = shift;
    my ($arg_ref) = pos_validated_list(
        \@_,
        { isa => 'Maybe[HashRef]', optional => 1 },
    );

    my @descendants;
    if ( $arg_ref && $arg_ref->{except} ) {
        my $except_node = delete $arg_ref->{except};
        return () if $self == $except_node;
        @descendants = map {
            $_->get_descendants( { except => $except_node, add_self => 1 } )
        } $self->get_children();
    }
    else {
        @descendants = $self->descendants();
    }
    return @descendants if !$arg_ref;
    return $self->_process_switches( $arg_ref, @descendants );
}

sub get_siblings {
    my $self = shift;
    my ($arg_ref) = pos_validated_list(
        \@_,
        { isa => 'Maybe[HashRef]', optional => 1 },
    );
    my $parent = $self->get_parent();
    return () if !$parent;
    my @siblings = grep { $_ ne $self } $parent->get_children();
    return @siblings if !$arg_ref;
    return $self->_process_switches( $arg_ref, @siblings );
}

sub get_left_neighbor  { return $_[0]->get_siblings( { preceding_only => 1, last_only  => 1 } ); }
sub get_right_neighbor { return $_[0]->get_siblings( { following_only => 1, first_only => 1 } ); }

sub is_descendant_of {
    my $self = shift;
    my ($another_node) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Node' },
    );

    my $parent = $self->get_parent();
    while ($parent) {
        return 1 if $parent == $another_node;
        $parent = $parent->get_parent();
    }
    return 0;
}

#----------- alignment -------------

sub get_aligned_nodes {
    my ($self) = @_;
    my $links_rf = $self->get_attr('alignment');
    if ($links_rf) {
        my $document = $self->get_document;
        my @nodes    = map { $document->get_node_by_id( $_->{'counterpart.rf'} ) } @$links_rf;
        my @types    = map { $_->{'type'} } @$links_rf;
        return ( \@nodes, \@types );
    }
    return ( undef, undef );
}

sub is_aligned_to {
    my ( $self, $node, $type ) = @_;
    return grep { $_ eq $node } $self->get_aligned_nodes( $node, $type ) ? 1 : 0;
}

sub delete_aligned_node {
    my ( $self, $node, $type ) = @_;
    my $links_rf = $self->get_attr('alignment');
    my @links    = ();
    if ($links_rf) {
        @links = grep { $_->{'counterpart.rf'} ne $node->id || $_->{'type'} ne $type } @$links_rf;
    }
    $self->set_attr( 'alignment', \@links );
    return;
}

sub add_aligned_node {
    my ( $self, $node, $type ) = @_;
    my $links_rf = $self->get_attr('alignment');
    my %new_link = ( 'counterpart.rf' => $node->id, 'type' => $type );
    push( @$links_rf, \%new_link );
    $self->set_attr( 'alignment', $links_rf );
    return;
}

#************************************
#---- OTHER ------

sub get_depth {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self  = shift;
    my $depth = 0;
    while ( $self = $self->get_parent() ) {
        $depth++;
    }
    return $depth;
}

# This is called from $node->remove()
# so it must be defined in this class,
# but it is overriden in Treex::Core::Node::Ordered.
sub _normalize_node_ordering {
}

#*************************************
#---- DEPRECATED & QUESTIONABLE ------

sub disconnect {
    my $self = shift;
    log_debug( '$node->disconnect is deprecated, use $node->remove', 1 );
    return $self->remove();
}

sub get_ordering_value {
    my $self = shift;
    log_warn( '$node->get_ordering_value is deprecated, use $node->ord', 1 );
    return $self->ord;
}

sub set_ordering_value {
    my $self = shift;
    log_warn( '$node->set_ordering_value($ord) is deprecated, it should be private $node->_set_ord($n)', 1 );
    my ($val) = pos_validated_list(
        \@_,
        { isa => 'Num' },    #or isa => 'Int' ??, or Positive Int?
    );
    $self->_set_ord($val);
    return;
}

sub get_fposition {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    my $id   = $self->get_attr('id');

    my $fsfile  = $self->get_document->_get_pmldoc();    ## no critic (ProtectPrivateSubs)
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

sub generate_new_id {    #TODO move to Core::Document?
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    my $doc  = $self->get_document;

    my $latest_node_number = $doc->_latest_node_number;

    my $new_id;

    #$self->get_root->id =~ /(.+)root/;
    #my $id_base = $1 || "";
    my $id_base;
    if ( $self->get_root->id =~ /(.+)root/ ) {
        $id_base = $1;
    }
    else {
        $id_base = q();
    }

    while (1) {
        $latest_node_number++;
        $new_id = "${id_base}n$latest_node_number";
        last if not $doc->id_is_indexed($new_id);

    }

    $doc->_set_latest_node_number($latest_node_number);

    return $new_id;
}

sub add_to_listattr {
    my $self = shift;
    my ( $attr_name, $attr_value ) = pos_validated_list(
        \@_,
        { isa => 'Str' },
        { isa => 'Any' },
    );

    my $list = $self->attr($attr_name);
    log_fatal("Attribute $attr_name is not a list!")
        if !defined $list || ref($list) ne 'Treex::PML::List';
    my @new_list = @{$list};
    if ( ref($attr_value) eq 'ARRAY' ) {
        push @new_list, @{$attr_value};
    }
    else {
        push @new_list, $attr_value;
    }
    return $self->set_attr( $attr_name, Treex::PML::List->new(@new_list) );
}

# Get more attributes at once
sub get_attrs {
    my $self       = shift;
    my @attr_names = pos_validated_list(
        \@_,
        { isa => 'Any' },    #at least one parameter
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1,
    );

    my @attr_values;
    if ( ref $attr_names[-1] ) {
        my $arg_ref          = pop @attr_names;
        my $change_undefs_to = $arg_ref->{undefs};
        @attr_values = map {
            defined $self->get_attr($_) ? $self->get_attr($_) : $change_undefs_to
        } @attr_names;
    }
    else {
        @attr_values = map { $self->get_attr($_) } @attr_names;
    }

    return @attr_values;
}

# TODO: How to do this in an elegant way?
# Unless we find a better way, we must disable two perlcritics
package Treex::Core::Node::Removed;    ## no critic (ProhibitMultiplePackages)
use Treex::Core::Log;

sub AUTOLOAD {                         ## no critic (ProhibitAutoloading)
    our $AUTOLOAD;
    if ( $AUTOLOAD !~ /DESTROY$/ ) {
        log_fatal("You cannot call any methods on removed nodes, but have called $AUTOLOAD");
    }
}

package Treex::Core::Node;             ## no critic (ProhibitMultiplePackages)

__PACKAGE__->meta->make_immutable;

1;

__END__

=for Pod::Coverage BUILD disconnect get_ordering_value set_ordering_value get_r_attr set_r_attr


=encoding utf-8

=head1 NAME

Treex::Core::Node

=head1 DESCRIPTION

This class represents a Treex node.
Treex trees (contained in bundles) are formed by nodes and edges.
Attributes can be attached only to nodes. Edge's attributes must
be stored as the lower node's attributes.
Tree's attributes must be stored as attributes of the root node.

=head1 METHODS

=head2 Construction

=over 4

=item  my $new_node = $existing_node->create_child(lemma=>'house', tag=>'NN' });

Creates a new node as a child of an existing node. Some of its attribute
can be filled. Direct calls of node constructors (->new) should be avoided.


=back



=head2 Access to the containers

=over 4

=item my $bundle = $node->get_bundle();

Returns the L<TectoMT::Bundle|TectoMT::Bundle> object in which the node's tree is contained.

=item my $document = $node->get_document();

Returns the L<TectoMT::Document|TectoMT::Document> object in which the node's tree is contained.

=item get_layer

Return the layer of this node (I<a,t,n or p>).

=item get_zone

Return the zone (L<Treex::Core::BundleZone>) to which this node
(and the whole tree) belongs.

=item $lang_code = $node->language

shortcut for $lang_code = $node->get_zone()->language

=item $selector = $node->selector

shortcut for $selector = $node->get_zone()->selector

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

=item $node->remove();

Deletes a node and the a subtree rooted by the given node.
Node identifier is removed from the document indexing table.
The removed node cannot be further used.

=item my $root_node = $node->get_root();

Returns the root of the node's tree.

=item my $root_node = $node->is_root();

Returns true if the node has no parent.

=item $node1->is_descendant_of($node2);

Tests whether $node1 is among transitive descendants of $node2;

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

=head2 PML-related methods

=over 4

=item my $type = $node->get_pml_type_name;

=back


=head2 Access to alignment

=over

=item add_aligned_node

=item get_aligned_nodes

=item delete_aligned_node

=item is_aligned_to

=back

=head2 Other methods

=over 4

=item $node->generate_new_id();

Generate new (=so far unindexed) identifier (to be used when creating new nodes).
The new identifier is derived from the identifier of the root ($node->root), by adding
suffix x1 (or x2, if ...x1 has already been indexed, etc.) to the root's id.


=item my $levels = $node->get_depth();

Return the depth of the node. The root has depth = 0, its children have depth = 1 etc.

=back


=head2 DEPRECATED & QUESTIONABLE METHODS

=over

=item my $position = $node->get_fposition();

Return the node address, i.e. file name and node's position within the file, similarly
to TrEd's FPosition() (but the value is only returned, not printed).

=back


=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
