package Treex::Core::Node;

use namespace::autoclean;

use Moose;
use MooseX::NonMoose;
use Treex::Core::Common;
use Cwd;
use Scalar::Util qw(refaddr);
use Treex::PML;

extends 'Treex::PML::Node';
with 'Treex::Core::WildAttr';

# overloading does not work with namespace::autoclean
# see https://rt.cpan.org/Public/Bug/Display.html?id=50938
# We may want to use https://metacpan.org/module/namespace::sweep instead.
#
# use overload
#     '""' => 'to_string',
#     '==' => 'equals',
#     '!=' => '_not_equals',
#     'eq' => 'equals',      # deprecated
#     'ne' => '_not_equals', # deprecated
#     'bool' => sub{1},
#
#     # We can A) let Magic Autogeneration to build "derived" overloadings,
#     # or B) we can disable this feature (via fallback=>0)
#     # and define only the needed overloadings
#     # (so all other overloadings will result in fatal errors).
#     # See perldoc overload.
#     # I decided for A, but uncommenting the following lines can catch some misuses.
#     #'!'  => sub{0},
#     #'.' => sub{$_[2] ? $_[1] . $_[0]->to_string : $_[0]->to_string . $_[1]},
#     #fallback => 0,
# ;
# # TODO: '<' => 'precedes' (or better '<=>' => ...)
# # 'eq' => sub {log_warn 'You should use ==' && return $_[0]==$_[1]} # similarly for 'ne'

Readonly my $_SWITCHES_REGEX => qr/^(ordered|add_self|(preceding|following|first|last)_only)$/x;
my $CHECK_FOR_CYCLES = 1;

our $LOG_NEW = 0;
our $LOG_EDITS = 0;
# tip: you can use Util::Eval doc='$Treex::Core::Node::LOG_EDITS=1;' in your scenario
# Note that most attributes are not set by set_attr. See TODO below.

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

    if (( not defined $arg_ref or not defined $arg_ref->{_called_from_core_} )
        and not $Treex::Core::Config::running_in_tred
        )
    {
        log_fatal 'Because of node indexing, no nodes can be created outside of documents. '
            . 'You have to use $zone->create_tree(...) or $node->create_child() '
            . 'instead of Treex::Core::Node...->new().';
    }
    return;
}

sub to_string {
    my ($self) = @_;
    return $self->id // 'node_without_id(addr=' . refaddr($self) . ')';
}

# Since we have overloaded stringification, we must overload == as well,
# so you can use "if ($nodeA ==  $nodeB){...}".
sub equals {
    my ($self, $node) = @_;
    #return ref($node) && $node->id eq $self->id;
    return ref($node) && refaddr($node) == refaddr($self);
}

sub _not_equals {
    my ($self, $node) = @_;
    return !$self->equals($node);
}

sub _index_my_id {
    my $self = shift;
    $self->get_document->index_node_by_id( $self->id, $self );
    return;
}

sub _caller_signature {
    my $level = 1;
    my ($package, $filename, $line) = caller;
    while ($package =~ /^Treex::Core/){
        ($package, $filename, $line) = caller $level++;
    }
    $package =~ s/^Treex::Block:://;
    return "$package#$line";
}

# ---- access to attributes ----

# unlike attr (implemented in Treex::PML::Instance::get_data)
# get_attr implements only "plain" and "nested hash" attribute names,
# i.e. no XPath-like expressions (a/aux.rf[3]) are allowed.
# This results in much faster code.
sub get_attr {
    my ( $self, $attr_name ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 2;
    my $val = $self;
    for my $step ( split /\//, $attr_name ) {
        if ( !defined $val ) {
            log_fatal "Attribute '$attr_name' contains strange symbols."
                . " For XPath like constructs (e.g. 'a/aux.rf[3]') use the 'attr' method."
                if $attr_name =~ /[^-\w\/.]/;
        }
        $val = $val->{$step};
    }
    return $val;
}

use Treex::PML::Factory;

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

    if ($attr_name =~ /\.rf$/){
        my $document = $self->get_document();

        # Delete previous back references
        my $old_value = $self->get_attr($attr_name);
        if ($old_value) {
            if ( ref $old_value eq 'Treex::PML::List' && @$old_value ) {
                $document->remove_backref( $attr_name, $self->id, $old_value );
            }
            else {
                $document->remove_backref( $attr_name, $self->id, [$old_value] );
            }
        }

        # Set new back references
        my $ids = ref($attr_value) eq 'Treex::PML::List' ? $attr_value : [$attr_value];
        $document->index_backref( $attr_name, $self->id, $ids );
    }
    elsif ($attr_name eq 'alignment'){
        my $document = $self->get_document();
        if ($self->{alignment}){
            my @old_ids = map { $_->{'counterpart.rf'} } @{$self->{alignment}};
            $document->remove_backref( 'alignment', $self->id, \@old_ids );
        }
        if ($attr_value && @$attr_value){
            my @new_ids = map { $_->{'counterpart.rf'} } @$attr_value;
            $document->index_backref( $attr_name, $self->id, \@new_ids );
        }
    }

    # TODO: most attributes are set by Moose setters,
    # e.g. $anode->set_form("Hi") does not call set_attr.
    # We would need to redefine all the setter to fill wild->{edited_by}.
    if ($LOG_EDITS){
        my $signature = $self->wild->{edited_by};
        if ($signature) {$signature .= "\n";}
        else {$signature = '';}
        my $a_value = $attr_value // 'undef';
        $signature .= "$attr_name=$a_value ". $self->_caller_signature();
        $self->wild->{edited_by} = $signature;
    }

    #simple attributes can be accessed directly
    return $self->{$attr_name} = $attr_value if $attr_name =~ /^[\w\.]+$/ || $attr_name eq '#name';
    log_fatal "Attribute '$attr_name' contains strange symbols."
        . " No XPath like constructs (e.g. 'a/aux.rf[3]') are allowed."
        if $attr_name =~ /[^-\w\/.]/;

    my $val = $self;
    my @steps = split /\//, $attr_name;
    while (1) {
        my $step = shift @steps;
        if (@steps) {
            if ( !defined( $val->{$step} ) ) {
                $val->{$step} = Treex::PML::Factory->createStructure();
            }
            $val = $val->{$step};
        }
        else {
            return $val->{$step} = $attr_value;
        }
    }
    return;
}

sub get_deref_attr {
    my ( $self, $attr_name ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 2;
    my $attr_value = $self->get_attr($attr_name);

    return if !$attr_value;
    my $document = $self->get_document();
    return [ map { $document->get_node_by_id($_) } @{$attr_value} ]
        if ref($attr_value) eq 'Treex::PML::List';
    return $document->get_node_by_id($attr_value);
}

sub set_deref_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 3;

    # If $attr_value is an array of nodes
    if ( ref($attr_value) eq 'ARRAY' ) {
        my @list = map { $_->id } @{$attr_value};
        $attr_value = Treex::PML::List->new(@list);
    }

    # If $attr_value is just one node
    else {
        $attr_value = $attr_value->id;
    }

    # Set the new reference(s)
    $self->set_attr( $attr_name, $attr_value );
    return;
}

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

    log_fatal "a node (" . $self->id . ") can't reveal its zone" if !$zone;
    return $zone;

}

sub remove {
    my ($self, $arg_ref) = @_;
    if ( $self->is_root ) {
        log_fatal 'Tree root cannot be removed using $root->remove().'
            . ' Use $zone->remove_tree($layer) instead';
    }
    my $root     = $self->get_root();
    my $document = $self->get_document();
    
    my @children = $self->get_children();
    if (@children){
        my $what_to_do = 'remove';
        if ($arg_ref && $arg_ref->{children}){
            $what_to_do = $arg_ref->{children};
        }
        if ($what_to_do =~ /^rehang/){
            foreach my $child (@children){
                $child->set_parent($self->get_parent);
            }
        }
        if ($what_to_do =~ /warn$/){
            log_warn $self->get_address . " is being removed by remove({children=>$what_to_do}), but it has (unexpected) children";
        }
    }

    # Remove the subtree from the document's indexing table
    my @to_remove = ( $self, $self->get_descendants );
    foreach my $node ( @to_remove) {
        if ( defined $node->id ) {
            $document->_remove_references_to_node( $node );
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
    foreach my $node (@to_remove){
        bless $node, 'Treex::Core::Node::Deleted';
    }
    return;
}

# Return all nodes that have a reference of the given type (e.g. 'alignment', 'a/lex.rf') to this node
sub get_referencing_nodes {
    my ( $self, $type, $lang, $sel ) = @_;
    my $doc  = $self->get_document;
    my $refs = $doc->get_references_to_id( $self->id );
    return if ( !$refs || !$refs->{$type} );
    if ((defined $lang) && (defined $sel)) {
    	my @ref_filtered_by_tree;
    	if ($sel eq q() ) {
    		@ref_filtered_by_tree = grep { /(a|t)\_tree\-$lang\-.+/; }@{ $refs->{$type} };    		
    	}
    	else {
    		@ref_filtered_by_tree = grep { /(a|t)\_tree\-$lang\_$sel\-.+/; }@{ $refs->{$type} };
    	}
		return map { $doc->get_node_by_id($_) } @ref_filtered_by_tree;
    }
    return map { $doc->get_node_by_id($_) } @{ $refs->{$type} };
}

# Remove a reference of the given type to the given node. This will not remove a reverse reference from document
# index, since it is itself called when removing reverse references; use the API methods for the individual
# references if you want to keep reverse references up-to-date.
sub remove_reference {
    my ( $self, $type, $id ) = @_;

    if ( $type eq 'alignment' ) {    # handle alignment links separately

        my $links = $self->get_attr('alignment');

        if ($links) {
            my $document = $self->get_document;
            $self->set_attr( 'alignment', [ grep { $_->{'counterpart.rf'} ne $id } @{$links} ] );
        }
    }
    else {
        my $attr = $self->get_attr($type);
        log_fatal "undefined attr $type (id=$id)" if !defined $attr;

        if ( $attr eq $id || scalar( @{$attr} ) <= 1 ) {                # single-value attributes
            $self->set_attr( $type, undef );
        }
        else {
            $attr->delete_value($id);                                   # TODO : will it be always a Treex::PML::List? Looks like it works.
        }
    }
    return;
}


sub fix_pml_type {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    if ( not $self->type() ) {
        my $type = $self->get_pml_type_name();
        if ( not $type ) {
            log_warn "No PML type recognized for node $self";
            return;
        }
        my $fs_file = $self->get_document()->_pmldoc;
        $self->set_type_by_name( $fs_file->metaData('schema'), $type );
    }
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
        if ( $attr =~ m{/} || $attr eq 'mlayer_pos' || $attr eq '#name') {
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

#    my $type = $new_node->get_pml_type_name();
#    return $new_node if !defined $type;
#    my $fs_file = $self->get_bundle->get_document()->_pmldoc;
#    $self->set_type_by_name( $fs_file->metaData('schema'), $type );

    $new_node->fix_pml_type();

    # Remember which module (Treex block) and line number in its source code are responsible for creating this node.
    if ($LOG_NEW){
        $new_node->wild->{created_by} = $self->_caller_signature();
    }

    return $new_node;
}

#************************************
#---- TREE NAVIGATION ------

sub get_document {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self   = shift;
    my $bundle = $self->get_bundle();
    log_fatal('Cannot call get_document on a node which is in no bundle') if !defined $bundle;
    return $bundle->get_document();
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

sub is_leaf {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    return not $self->firstson;
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

    # We cannot detach a node by setting an undefined parent. The if statement below will die.
    # Let's inform the user where the bad call is.
    log_fatal( 'Cannot attach the node ' . $self->id . ' to an undefined parent' ) if ( !defined($parent) );
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
sub dominates {
    my $self = shift;
    my $another_node = shift;
    return $another_node->is_descendant_of($self);
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

sub get_aligned_nodes_by_tree {
    my ($self, $lang, $selector) = @_;
    my @nodes = ();
    my @types = ();
    my $links_rf = $self->get_attr('alignment');
    if ($links_rf) {
        my $document = $self->get_document;
        foreach my $l_rf (@{$links_rf}) {
        	if ($l_rf->{'counterpart.rf'} =~ /^(a|t)_tree-$lang(_$selector)?-.+$/) {
        		my $n = $document->get_node_by_id( $l_rf->{'counterpart.rf'} );
        		my $t = $l_rf->{'type'};
        		push @nodes, $n;
        		push @types, $t;
        	}
        }
        return ( \@nodes, \@types ) if 	scalar(@nodes) > 0 ;	
    }
    return ( undef, undef );
}

sub get_aligned_nodes_of_type {
    my ( $self, $type_regex, $lang, $selector ) = @_;
    my @nodes;
    my ( $n_rf, $t_rf );
    if ((defined $lang) && (defined $selector)) {
    	( $n_rf, $t_rf ) = $self->get_aligned_nodes_by_tree($lang, $selector);
    }
    else {
    	( $n_rf, $t_rf ) = $self->get_aligned_nodes();	
    }    
    return if !$n_rf;
    my $iterator = List::MoreUtils::each_arrayref( $n_rf, $t_rf );
    while ( my ( $node, $type ) = $iterator->() ) {
        if ( $type =~ /$type_regex/ ) {
            push @nodes, $node;
        }
    }
    return @nodes;
}

sub is_aligned_to {
    my ( $self, $node, $type ) = @_;
    log_fatal 'Incorrect number of parameters' if @_ != 3;
    return ((any { $_ eq $node } $self->get_aligned_nodes_of_type( $type )) ? 1 : 0);
}

sub delete_aligned_node {
    my ( $self, $node, $type ) = @_;
    my $links_rf = $self->get_attr('alignment');
    my @links    = ();
    if ($links_rf) {
        @links = grep {
            $_->{'counterpart.rf'} ne $node->id
                || ( defined($type) && defined( $_->{'type'} ) && $_->{'type'} ne $type )
            }
            @$links_rf;
    }
    $self->set_attr( 'alignment', \@links );
    return;
}

sub add_aligned_node {
    my ( $self, $node, $type ) = @_;
    my $links_rf = $self->get_attr('alignment');
    my %new_link = ( 'counterpart.rf' => $node->id, 'type' => $type // ''); #/ so we have no undefs
    push( @$links_rf, \%new_link );
    $self->set_attr( 'alignment', $links_rf );
    return;
}

# remove invalid alignment links (leading to unindexed nodes)
sub update_aligned_nodes {
    my ($self)   = @_;
    my $doc      = $self->get_document();
    my $links_rf = $self->get_attr('alignment');
    my @new_links;

    foreach my $link ( @{$links_rf} ) {
        push @new_links, $link if ( $doc->id_is_indexed( $link->{'counterpart.rf'} ) );
    }
    $self->set_attr( 'alignment', \@new_links );
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

sub get_address {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self     = shift;
    my $id       = $self->id;
    my $bundle   = $self->get_bundle();
    my $doc      = $bundle->get_document();
    my $file     = $doc->loaded_from || ( $doc->full_filename . '.treex' );
    my $position = $bundle->get_position() + 1;

    #my $filename = Cwd::abs_path($file);
    return "$file##$position.$id";
}

# Empty DESTROY method is a hack to get rid of the "Deep recursion warning"
# in Treex::PML::Node::DESTROY and MooseX::NonMoose::Meta::Role::Class::_check_superclass_destructor.
# Without this hack, you get the warning after creating a node with 99 or more children.
# Deep recursion on subroutine "Class::MOP::Method::execute" at .../5.12.2/MooseX/NonMoose/Meta/Role/Class.pm line 183.
sub DESTROY {
}

#*************************************
#---- DEPRECATED & QUESTIONABLE ------

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
        last if !$doc->id_is_indexed($new_id);

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

# Return all attributes of the given node (sub)type that contain references
sub _get_reference_attrs {
    my ($self) = @_;
    return ();
}

# Return IDs of all nodes to which there are reference links from this node (must be overridden in
# the respective node types)
sub _get_referenced_ids {
    my ($self) = @_;
    my $ret = {};

    # handle alignment separately
    my $links_rf = $self->get_attr('alignment');
    $ret->{alignment} = [ map { $_->{'counterpart.rf'} } @{$links_rf} ] if ($links_rf);

    # all other references
    foreach my $ref_attr ( $self->_get_reference_attrs() ) {
        my $val = $self->get_attr($ref_attr) or next;
        if ( !ref $val ) {    # single-valued
            $ret->{$ref_attr} = [$val];
        }
        else {
            $ret->{$ref_attr} = $val;
        }
    }
    return $ret;
}


# ---------------------

# changing the functionality of Treex::PML::Node's following() so that it traverses all
# nodes in all trees in all zones (needed for search in TrEd)

sub following {
    my ( $self ) = @_;

    my $pml_following =  Treex::PML::Node::following(@_);

    if ( $pml_following ) {
        return $pml_following;
    }

    else {
        my $bundle =  ( ref($self) eq 'Treex::Core::Bundle' ) ? $self : $self->get_bundle;

        my @all_trees = map {
            ref($_) ne 'Treex::PML::Struct'
            ? $_->get_all_trees
            : ()
        } $bundle->get_all_zones;

        if ( ref($self) eq 'Treex::Core::Bundle' ) {
            return $all_trees[0];
        }

        else {
            my $my_root = $self->get_root;
            foreach my $index ( 0..$#all_trees ) {
                if ( $all_trees[$index] eq $my_root ) {
                    return $all_trees[$index+1];
                }
            }
            log_fatal "Node belongs to no tree: this should never happen";
        }
    }
}

# This is copied from Treex::PML::Node.
# Using Treex::PML::Node::following is faster than recursion
# and it does not cause "deep recursion" warnings.
sub descendants {
  my $self = $_[0];
  my @kin = ();
  my $desc = $self->Treex::PML::Node::following($self);
  while ($desc) {
    push @kin, $desc;
    $desc = $desc->Treex::PML::Node::following($self);
  }
  return @kin;
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

##-- begin proposal
# Example usage:
# Treex::Core::Node::T methods get_lex_anode and get_aux_anodes could use:
# my $a_lex = $t_node->get_r_attr('a/lex.rf'); # returns the node or undef
# my @a_aux = $t_node->get_r_attr('a/aux.rf'); # returns the nodes or ()
sub get_r_attr {
    my ( $self, $attr_name ) = @_;
    log_fatal('Incorrect number of arguments') if @_ != 2;
    my $attr_value = $self->get_attr($attr_name);

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
    my $fs = $self;

    # TODO $fs->type nefunguje - asi protoze se v konstruktorech nenastavuje typ
    if ( $fs->type($attr_name) eq 'Treex::PML::List' ) {
        my @list = map { $_->id } @attr_values;

        # TODO: overriden Node::N::set_attr is bypassed by this call
        return $fs->set_attr( $attr_name, Treex::PML::List->new(@list) );
    }
    log_fatal("Attribute '$attr_name' is not a list, but set_r_attr() called with @attr_values values.")
        if @attr_values > 1;

    # TODO: overriden Node::N::set_attr is bypassed by this call
    return $fs->set_attr( $attr_name, $attr_values[0]->id );
}



=for Pod::Coverage BUILD


=encoding utf-8

=head1 NAME

Treex::Core::Node - smallest unit that holds information in Treex

=head1 DESCRIPTION

This class represents a Treex node.
Treex trees (contained in bundles) are formed by nodes and edges.
Attributes can be attached only to nodes. Edge's attributes must
be stored as the lower node's attributes.
Tree's attributes must be stored as attributes of the root node.

=head1 METHODS

=head2 Construction

=over 4

=item  my $new_node = $existing_node->create_child({lemma=>'house', tag=>'NN' });

Creates a new node as a child of an existing node. Some of its attribute
can be filled. Direct calls of node constructors (C<< ->new >>) should be avoided.


=back



=head2 Access to the containers

=over 4

=item my $bundle = $node->get_bundle();

Returns the L<Treex::Core::Bundle> object in which the node's tree is contained.

=item my $document = $node->get_document();

Returns the L<Treex::Core::Document> object in which the node's tree is contained.

=item get_layer

Return the layer of this node (I<a>, I<t>, I<n> or I<p>).

=item get_zone

Return the zone (L<Treex::Core::BundleZone>) to which this node
(and the whole tree) belongs.

=item $lang_code = $node->language

shortcut for C<< $lang_code = $node->get_zone()->language >>

=item $selector = $node->selector

shortcut for C<< $selector = $node->get_zone()->selector >>

=back


=head2 Access to attributes

=over 4

=item my $value = $node->get_attr($name);

Returns the value of the node attribute of the given name.

=item my $node->set_attr($name,$value);

Sets the given attribute of the node with the given value.
If the attribute name is C<id>, then the document's indexing table
is updated. If value of the type C<List> is to be filled,
then C<$value> must be a reference to the array of values.

=item my $node2 = $node1->get_deref_attr($name);

If value of the given attribute is reference (or list of references),
it returns the appropriate node (or a reference to the list of nodes).

=item my $node1->set_deref_attr($name, $node2);

Sets the given attribute with C<id> (list of C<id>s) of the given node (list of nodes).

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

Returns the parent node, or C<undef> if there is none (if C<$node> itself is the root)

=item $node->set_parent($parent_node);

Makes C<$node> a child of C<$parent_node>.

=item $node->remove({children=>remove});

Deletes a node.
Node identifier is removed from the document indexing table.
The removed node cannot be further used.

Optional argument C<children> in C<$arg_ref> can specify
what to do with children (and all descendants,
i.e. the subtree rooted by the given node) if present:
C<remove>, C<remove_warn>, C<rehang>, C<rehang_warn>.
The default is C<remove> -- remove recursively.
C<rehang> means reattach the children of C<$node> to the parent of C<$node>.
The C<_warn> variants will in addition produce a warning.

=item my $root_node = $node->get_root();

Returns the root of the node's tree.

=item $node->is_root();

Returns C<true> if the node has no parent.

=item $node->is_leaf();

Returns C<true> if the node has no children.

=item $node1->is_descendant_of($node2);

Tests whether C<$node1> is among transitive descendants of C<$node2>;

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

Currently there are 6 switches:

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

C<first_only> and C<last_only> switches makes the method return just one item -
a scalar, even if combined with the C<add_self> switch.

=item *

Specifying C<(first|last|preceding|following)_only> implies C<ordered>,
so explicit addition of C<ordered> gives a warning.

=item *

Specifying both C<preceding_only> and C<following_only> gives an error
(same for combining C<first_only> and C<last_only>).

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

=over

=item my $type = $node->get_pml_type_name;

=item $node->fix_pml_type();

If a node has no PML type, then its type is detected (according
to the node's location) and filled by the PML interface.

=back


=head2 Access to alignment

=over

=item $node->add_aligned_node($target, $type)

Aligns $target node to $node. The prior existence of the link is not checked.

=item my ($nodes_rf, $types_rf) = $node->get_aligned_nodes()

Returns an array containing two array references. The first array contains the nodes aligned to this node, the second array contains types of the links.

=item my @nodes = $node->get_aligned_nodes_of_type($regex_constraint_on_type)

Returns a list of nodes aligned to the $node by the specified alignment type.

=item $node->delete_aligned_node($target, $type)

All alignments of the $target to $node are deleted, if their types equal $type.

=item my $is_aligned = $node->is_aligned_to($target, $regex_constraint_on_type)

Returns 1 if the nodes are aligned, 0 otherwise.

=item $node->update_aligned_nodes()

Removes all alignment links leading to nodes which have been deleted.

=back

=head2 References (alignment and other references depending on node subtype)

=over

=item my @refnodes = $node->get_referencing_nodes($ref_type);

Returns an array of nodes referencing this node with the given reference type (e.g. 'alignment', 'a/lex.rf' etc.).

=back

=head2 Other methods

=over 4

=item $node->generate_new_id();

Generate new (= so far unindexed) identifier (to be used when creating new
nodes). The new identifier is derived from the identifier of the root
(C<< $node->root >>), by adding suffix C<x1> (or C<x2>, if C<...x1> has already
been indexed, etc.) to the root's C<id>.

=item my $levels = $node->get_depth();

Return the depth of the node. The root has depth = 0, its children have depth = 1 etc.

=item my $address = $node->get_address();

Return the node address, i.e. file name and node's position within the file,
similarly to TrEd's C<FPosition()> (but the value is only returned, not  printed).

=item $node->equals($another_node)

This is the internal implementation of overloaded C<==> operator,
which checks whether C<$node == $another_node> (the object instance must be identical).

=item my $string = $node->to_string()

This is the internal implementation of overloaded stringification,
so you can use e.g. C<print "There is a node $node.">.
It returns the id (C<$node->id>), but the behavior may be overridden in subclasses.
See L<overload> pragma for details about overloading operators in Perl.

=back


=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Daniel Zeman <zeman@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
