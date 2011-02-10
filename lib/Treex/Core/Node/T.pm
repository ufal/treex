package Treex::Core::Node::T;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Node';

sub ordering_attribute {'ord'}

sub get_pml_type_name {
    my ($self) = @_;
    return $self->is_root() ? 't-root.type' : 't-node.type';
}

sub get_lex_anode {
    my ($self) = @_;
    my $lex_rf = $self->get_attr('a/lex.rf');
    my $document = $self->get_document();
    return $document->get_node_by_id( $lex_rf) if $lex_rf;
    return;
}

sub set_lex_anode {
    my ($self, $lex_anode) = @_;
    my $new_id = defined $lex_anode ? $lex_anode->get_attr('id') : undef;
    $self->set_attr('a/lex.rf', $new_id);
    return;
}


sub get_aligned_nodes {
    my ($self) = @_;
    my $links_rf = $self->get_attr('align/links');
    if ($links_rf) {
        my $document = $self->get_document;
        return map {$document->get_node_by_id($_->{'counterpart.rf'})} @$links_rf;
    }
    else {
        return ();
    }
}


# Named entity node corresponding to this
sub get_n_node {
    my ($self) = @_;
    my $lex_anode = $self->get_lex_anode() or return;
    return $lex_anode->get_n_node();
}

sub get_aux_anodes {
    my ( $self, $arg_ref ) = @_;
    ##my @nodes  = $self->get_r_attr('a/aux.rf');
    my $doc    = $self->get_document();
    my $aux_rf = $self->get_attr('a/aux.rf');
    my @nodes  = $aux_rf ? ( map { $doc->get_node_by_id($_) } @{$aux_rf} ) : ();
    return @nodes if !$arg_ref;
    log_fatal('Switches preceding_only and following_only can not be used with get_anodes (t-nodes vs. a-nodes).')
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
    log_fatal('Switches preceding_only and following_only can not be used with get_anodes (t-nodes vs. a-nodes).')
        if $arg_ref->{preceding_only} || $arg_ref->{following_only};
    return $self->_process_switches( $arg_ref, @nodes );
}

sub get_eff_children {
    my ( $self, $arg_ref ) = @_;
    my @nodes = map { $Treex::Core::Node::fsnode2tmt_node{$_} } PML_T2::GetEChildren( $self->get_tied_fsnode() );
    return @nodes if !$arg_ref;
    return $self->_process_switches( $arg_ref, @nodes );
}

# the same as get_eff_children(), but returns (in the list of lists) the effective children grouped according their transitive_coap_root
sub get_grouped_eff_children {
    my ($self) = @_;
    @_ == 1 or log_fatal("Incorrect number of arguments");

    my %coap_root2eff_ch = ();
    map { push @{ $coap_root2eff_ch{ $_->get_transitive_coap_root->get_attr('id') } }, $_ } $self->get_eff_children;
    return map { $coap_root2eff_ch{$_} } keys %coap_root2eff_ch;
}

sub get_eff_parents {
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;

    my $node = $self;

    # getting the highest node representing the given node
    if ( $node->is_coap_member ) {
        while ( $node && ( !$node->is_coap_root || $node->is_coap_member ) ) {
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
        log_warn "The node " . $self->get_attr('id') . " has no effective parent, using the topological one";
        return $self->get_parent;
    }
    else {
        log_warn "The node " . $self->get_attr('id') . " has no effective nor topological parent, using the root";
        return $self->get_root;
    }
}

# the node is a root of a coordination/apposition construction
sub is_coap_root {    # analogy of PML_T::IsCoord
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    return defined $self->get_attr('functor') && $self->get_attr('functor') =~ /^(CONJ|CONFR|DISJ|GRAD|ADVS|CSQ|REAS|CONTRA|APPS|OPER)$/;
}

sub is_coap_member {
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    return $self->get_attr('is_member');
}

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

# moved from Node::TCzechT
sub get_source_tnode {
    my ($self) = @_;
    my $source_node_id = $self->get_attr('source/head.rf');
    if ( defined $source_node_id and $source_node_id ne "" ) {    # divny!!! kde se tam kurna bere ta mezera?
        my $source_node = $self->get_document->get_node_by_id($source_node_id);
        if ( defined $source_node ) {
            return $source_node;
        }
        else {
            return;
        }
    }
    else {
        return;
    }
}

# moved from Node::TCzechT
sub set_source_tnode {
    my ( $self, $source_node ) = @_;
    $self->set_attr( 'source/head.rf', $source_node->get_attr('id') );
}



# --------- funkce pro efektivni potomky a rodice by Jan Stepanek - prevzato z PML_T.inc a upraveno -------------

package PML_T2;

my $recursion;

sub _FilterEChildren {    # node suff from
    my ( $node, $suff, $from ) = ( shift, shift, shift );
    my @sons;
    $node = $node->firstson;
    while ($node) {

        #    return @sons if $suff && @sons; #uncomment this line to get only first occurence
        unless ( $node == $from ) {    # on the way up do not go back down again
            if (( $suff && $node->{is_member} )
                || ( !$suff && !$node->{is_member} )
                )
            {                          # this we are looking for
                push @sons, $node unless IsCoord($node);
            }
            push @sons, _FilterEChildren( $node, 1, 0 )
                if (
                !$suff
                && IsCoord($node)
                && !$node->{is_member}
                )
                or (
                $suff
                && IsCoord($node)
                && $node->{is_member}
                );
        }    # unless node == from
        $node = $node->rbrother;
    }
    @sons;
}    # _FilterEChildren

sub GetEChildren {    # node
    my $node = shift;
    return () if IsCoord($node);
    my @sons;
    my $init_node = $node;    # for error message
    my $from;
    push @sons, _FilterEChildren( $node, 0, 0 );
    if ( $node->{is_member} ) {
        my @oldsons = @sons;
        while (
            $node
            and ( !$node->{nodetype} || $node->{nodetype} ne 'root' )
            and ( $node->{is_member} || !IsCoord($node) )
            )
        {
            $from = $node;
            $node = $node->parent;
            push @sons, _FilterEChildren( $node, 0, $from ) if $node;
        }
        if ( $node->{nodetype} && $node->{nodetype} eq 'root' ) {

            #      stderr("Error: Missing coordination head: $init_node->{id} $node->{id} ",ThisAddressNTRED($node),"\n");
            log_warn("Error: Missing coordination head: $init_node->{id} $node->{id} \n");
            @sons = @oldsons;
        }
    }
    @sons;
}    # GetEChildren

sub IsCoord {
    my $node = shift;
    return 0 unless $node;
    return ( defined( $node->{functor} ) and $node->{functor} =~ /CONJ|CONFR|DISJ|GRAD|ADVS|CSQ|REAS|CONTRA|APPS|OPER/ );
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
