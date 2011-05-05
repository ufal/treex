package Treex::Core::TredView::Labels;

use Moose;
use Treex::Core::Log;

has '_label_variants' => (
    is => 'rw',
    isa => 'HashRef[ArrayRef[Int]]',
    builder => '_build_label_variants'
);
has '_treex_doc' => (
    is => 'ro',
    isa => 'Treex::Core::Document',
    weak_ref => 1,
    required => 1
);
has '_colors' => (
    is => 'ro',
    isa => 'Treex::Core::TredView::Colors',
    default => sub { Treex::Core::TredView::Colors->new() }
);

sub _build_label_variants {
    return {
        'p' => [ 0, 0, 0 ],
        'a' => [ 0, 0, 0 ],
        't' => [ 0, 0, 0 ],
        'n' => [ 0, 0, 0 ]
    }
}

sub _get_label_variant {
    my $self = shift;
    my ( $obj, $line ) = @_;

    if (ref $obj and not exists $obj->{_label_variants}) {
        $obj = $obj->get_layer;
    }
    
    if (ref $obj) {
        # $obj is a single node
        return $obj->{_label_variants}->[ $line ];
    } else {
        # $obj is the name of a layer
        return $self->{_label_variants}->{ $obj }->[ $line ];
    }
}

# a) $obj is a node => rotating label variant of the given node
# b) $obj is the name of a layer => rotating label variant of all nodes on the given layer
sub _rotate_label_variant {
    my ( $self, $obj, $line ) = @_;
    my $layer;
    my $current;
    my $new;
    
    if (ref $obj) {
        $layer = $obj->get_layer;
        if (not exists $obj->{_label_variants}) {
            for (my $i = 0; $i < 3; $i++) {
                $obj->{_label_variants}->[$i] = $self->_get_label_variant($layer, $i);
            }
        }
        $current = $obj->{_label_variants}->[ $line ];
    } else {
        $layer = $obj;
        $current = $self->_get_label_variant( $obj, $line );
    }
    my $limit = $self->_label_variants->{ $layer.'_limit' }->[ $line ];
    $new = $current >= $limit ? 0 : $current + 1;
    
    return if $current == $new;
    
    if (ref $obj) {
        $obj->{_label_variants}->[ $line ] = $new
    } else {
        $self->{_label_variants}->{ $layer }->[ $line ] = $new
    }

    return 1;
}

sub _identify_and_bless_node {
    my $self = shift;
    my $node = $TredMacro::this;
    
    my $layer;
    if ( $node->type->get_structure_name =~ /(\S)-(root|node|nonterminal|terminal)/ ) {
        $layer = $1;
    } else {
        return;
    }
    bless $node, 'Treex::Core::Node::'.uc($layer);
    
    return $node;
}

sub set_labels {
    my ($self, $node) = @_;
    
    my $buf = $node->{_precomputed_buffer};
    for (my $i = 0; $i < 3; $i++) {
        $node->{_precomputed_labels}->[$i] = $buf->[$i]->[ $self->_get_label_variant($node, $i) ];
    }
}

sub shift_labels {
    my ($self, $line, $mode) = @_;
    my $node = $self->_identify_and_bless_node;
    return if $node->is_root and $mode eq 'node';
    
    my $layer = $node->get_layer;
    my @nodes;
    if ($mode eq 'node') {
        return unless $self->_rotate_label_variant($node, $line);
        @nodes = ( $node );
    } else {
        return unless $self->_rotate_label_variant($layer, $line);
        foreach my $bundle ( $self->_treex_doc->get_bundles ) {
            foreach my $zone ( $bundle->get_all_zones ) {
                if ( $zone->has_tree($layer) ) {
                    push @nodes, $zone->get_tree($layer)->get_descendants;
                }
            }
        }
        @nodes = grep { not exists $_->{_label_variants} } @nodes;
    }

    for my $node (@nodes) {
        $self->set_labels($node);
    }
}

sub reset_labels {
    my ($self, $mode) = @_;
    my $node = $self->_identify_and_bless_node;
    return if $node->is_root;
    
    my @nodes;
    if ($mode eq 'node') {
        @nodes = ( $node );
    } else {
        @nodes = $node->get_root->get_descendants;
    }

    for $node (@nodes) {
        delete $node->{_label_variants};
        $self->set_labels($node);
    }
}

sub set_limit {
    my ($self, $layer, $line, $limit) = @_;
    $self->_label_variants->{$layer.'_limit'}->[$line] = $limit;
}

sub root_labels {
    my ( $self, $root ) = @_;

    if ($root->get_layer eq 'p') {
        my $buf = $self->_pnode_labels($root);
        return [ $buf->[0]->[0], $buf->[1]->[0], $buf->[2]->[0] ];
    } else {
        return [
            $root->get_layer . "-tree",
            "zone=" . $root->get_zone->get_label,
            ''
        ];
    }
}

sub node_labels {
    my ($self, $node) = @_;
    my $layer = $node->get_layer;
    my %subs;
    
    $subs{t} = \&_tnode_labels;
    $subs{a} = \&_anode_labels;
    $subs{n} = \&_nnode_labels;
    $subs{p} = \&_pnode_labels;
    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }($self, $node);
    } else {
        log_fatal "Undefined or unknown layer: $layer";
    }
}

sub _anode_labels {
    my ( $self, $node ) = @_;

    my $line1 = '';
    my $par = 0;
    my $n = $node;
    while ( (not $par) and $n ) {
        $par = 1 if $n->{is_parenthesis_root};
        $n = $n->parent;
    }
    $line1 = $self->_colors->get('parenthesis', 1) if $par;
    $line1 .= $node->{form};

    my $line2 = $node->{afun} ? $self->_colors->get('afun', 1).$node->{afun} : $self->_colors->get('error', 1).'!!';
    if ($node->{is_member}) {
        my $n = $node->parent;
        $n = $n->parent while $n and $n->{afun} =~ m/^Aux[CP]$/;
        if ($n->{afun} =~ m/^(Ap)os|(Co)ord/) {
            $line2 .= '_'.$self->_colors->get('member', 1).($1 ? $1 : $2);
        }
    }
    
    my $line3_1 = $node->{tag};
    my $line3_2 = $node->{lemma};
    if ( $node->language eq 'cs' ) {
        $line3_1 = substr( $line3_1, 0, 2 );
        $line3_2 =~ s/(.)(?:-[1-9][0-9]*)?(?:(?:`|_[:;,^]).*)?$/$1/;
    }

    return [
        [ $line1 ],
        [ $line2 ],
        [ $line3_1, $line3_2 ]
    ];
}

sub _tnode_labels {
    my ( $self, $node ) = @_;

    my $line1 = $node->{t_lemma};
    $line1 = $self->_colors->get('parenthesis', 1) . $line1 if $node->{is_parenthesis};
    $line1 .= $self->_colors->get('sentmod', 1).'.'.$node->{sentmod} if $node->{sentmod};
    
    foreach my $type ('compl', 'coref_text', 'coref_gram') {
        if (defined $node->{$type.'.rf'}) {
            foreach my $ref (TredMacro::ListV($node->{$type.'.rf'})) {
                my $ref_node = $self->_treex_doc->get_node_by_id( $ref );
                if ( $node->get_bundle->get_position() != $ref_node->get_bundle->get_position() ) {
                    $line1 .= ' '.$self->_colors->get($type, 1).$ref_node->{t_lemma};
                }
            }
        }
    }

    my $line2 = $node->{functor};
    $line2 .= $self->_colors->get('subfunctor', 1).'.'.$node->{subfunctor} if $node->{subfunctor};
    $line2 .= $self->_colors->get('subfunctor', 1).'.state' if $node->{is_state};
    $line2 .= $self->_colors->get('subfunctor', 1).'.dsp_root' if $node->{is_dsp_root};
    $line2 .= $self->_colors->get('member', 1).'.member' if $node->{is_member};

    my @a_nodes = ();
    my $line3_1 = '';
    if (defined $node->attr('a/aux.rf')) {
        @a_nodes = TredMacro::ListV($node->attr('a/aux.rf'));
        @a_nodes = map { $self->_treex_doc->get_node_by_id($_) } @a_nodes;
        @a_nodes = map { { form => $_->{form}, ord => $_->{ord}, type => 'aux' } } @a_nodes;
    }
    if (defined $node->attr('a/lex.rf')) {
        my $a_node = $self->_treex_doc->get_node_by_id($node->attr('a/lex.rf'));
        push @a_nodes, { form => $a_node->{form}, ord => $a_node->{ord}, type => 'lex' };
    }
    if (@a_nodes) {
        @a_nodes = sort { $a->{ord} <=> $b->{ord} } @a_nodes;
        @a_nodes = map { ($_->{type} eq 'lex' ? $self->_colors->get('lex', 1) : $self->_colors->get('aux', 1)).$_->{form} } @a_nodes;
        $line3_1 = join " ", @a_nodes;
    }

    my $line3_2 = $self->_colors->get('nodetype', 1).$node->{nodetype};
    $line3_2 .= $self->_colors->get('sempos', 1).'.'.$node->attr('gram/sempos') if $node->attr('gram/sempos');
    
    return [
        [ $line1 ],
        [ $line2 ],
        [ $line3_1, $line3_2 ]
    ];
}

sub _nnode_labels {
    my ( $self, $node ) = @_;
    return [
        [ $node->{normalized_name} ],
        [ $node->{ne_type} ],
        []
    ];
}

sub _pnode_labels {
    my ( $self, $node ) = @_;

    my $terminal = $node->get_pml_type_name eq 'p-terminal.type' ? 1 : 0;
    
    my $line1 = '';
    my $line2 = '';
    if ($terminal) {
        $line1 = $node->{form};
        $line2 = $node->{tag};
        $line2 = '-' if $line2 eq '-NONE-';
    } else {
        $line1 = $self->_colors->get('phrase', 1).$node->{phrase}.'#{black}'.join('', map "-$_", TredMacro::ListV($node->{functions}));
    }

    return [
        [ $line1 ],
        [ $line2 ],
        [ '' ]
    ];
}

1;

__END__

=head1 NAME

Treex::Core::TredView::Labels - Labels of tree nodes in Tred

=head1 DESCRIPTION

This packages provides labels for the nodes displayed in Tred and related
functionality.

=head1 METHODS

=head2 Public methods

=over 4

=item set_labels

=item shift_labels

=item reset_labels

=item set_limit

=item root_labels

=item node_labels

=back

=head2 Private methods

=item _build_label_variants

=item _get_label_variant

=item _rotate_label_variant

=item _identify_and_bless_node

=item _anode_labels

=item _tnode_labels

=item _nnode_labels

=item _pnode_labels

=over 4

=head1 AUTHOR

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

