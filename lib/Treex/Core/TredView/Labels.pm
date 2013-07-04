package Treex::Core::TredView::Labels;

use Moose;
use Treex::Core::TredView::Common;
use Treex::Core::Log;

has '_label_variants' => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[Int]]',
    builder => '_build_label_variants'
);
has '_treex_doc' => (
    is       => 'ro',
    isa      => 'Treex::Core::Document',
    weak_ref => 1,
    required => 1
);
has '_colors' => (
    is      => 'ro',
    isa     => 'Treex::Core::TredView::Colors',
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

    if ( ref $obj and not exists $obj->{_label_variants} ) {
        $obj = $obj->get_layer;
    }

    if ( ref $obj ) {

        # $obj is a single node
        return $obj->{_label_variants}[$line];
    }
    else {

        # $obj is the name of a layer
        return $self->{_label_variants}{$obj}[$line];
    }
}

# a) $obj is a node => rotating label variant of the given node
# b) $obj is the name of a layer => rotating label variant of all nodes on the given layer
sub _rotate_label_variant {
    my ( $self, $obj, $line ) = @_;
    my $layer;
    my $current;
    my $new;

    if ( ref $obj ) {
        $layer = $obj->get_layer;
        if ( not exists $obj->{_label_variants} ) {
            for ( my $i = 0; $i < 3; $i++ ) {
                $obj->{_label_variants}[$i] = $self->_get_label_variant( $layer, $i );
            }
        }
        $current = $obj->{_label_variants}[$line];
    }
    else {
        $layer = $obj;
        $current = $self->_get_label_variant( $obj, $line );
    }
    my $limit = $self->_label_variants->{ $layer . '_limit' }[$line];
    $new = $current >= $limit ? 0 : $current + 1;

    return if $current == $new;

    if ( ref $obj ) {
        $obj->{_label_variants}[$line] = $new
    }
    else {
        $self->{_label_variants}{$layer}[$line] = $new
    }

    return 1;
}

sub set_labels {
    my ( $self, $node ) = @_;

    my $buf = $node->{_precomputed_buffer};
    for ( my $i = 0; $i < 3; $i++ ) {
        $node->{_precomputed_labels}[$i] = $buf->[$i][ $self->_get_label_variant( $node, $i ) ];
    }
    return;
}

sub shift_labels {
    my ( $self, $line, $mode ) = @_;
    my $node = Treex::Core::TredView::Common::cur_node();
    return if $node->is_root and $mode eq 'node';

    my $layer = $node->get_layer;
    my @nodes;
    if ( $mode eq 'node' ) {
        return if !$self->_rotate_label_variant( $node, $line );
        @nodes = ($node);
    }
    else {
        return if !$self->_rotate_label_variant( $layer, $line );
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
    return;
}

sub reset_labels {
    my ( $self, $mode ) = @_;
    my $node = Treex::Core::TredView::Common::cur_node();
    return if $node->is_root;

    my @nodes;
    if ( $mode eq 'node' ) {
        @nodes = ($node);
    }
    else {
        @nodes = $node->get_root->get_descendants;
    }

    for my $n (@nodes) {
        delete $n->{_label_variants};
        $self->set_labels($n);
    }
    return;
}

sub set_limit {
    my ( $self, $layer, $line, $limit ) = @_;
    return $self->_label_variants->{ $layer . '_limit' }[$line] = $limit;
}

sub get_limits {
    my ( $self, $layer ) = @_;
    return $self->_label_variants->{ $layer . '_limit' };
}

sub root_labels {
    my ( $self, $root ) = @_;

    if ( $root->get_layer eq 'p' ) {
        my $buf = $self->_pnode_labels($root);
        return [ $buf->[0][0], $buf->[1][0], $buf->[2][0] ];
    }
    else {
        return [
            $root->get_layer . "-tree",
            "zone=" . $root->get_zone->get_label,
            ''
        ];
    }
}

sub node_labels {
    my ( $self, $node ) = @_;
    my $layer = $node->get_layer;
    my %subs;

    $subs{t} = \&_tnode_labels;
    $subs{a} = \&_anode_labels;
    $subs{n} = \&_nnode_labels;
    $subs{p} = \&_pnode_labels;
    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }( $self, $node );
    }
    else {
        log_fatal "Undefined or unknown layer: $layer";
    }
}

sub _anode_labels {
    my ( $self, $node ) = @_;

    my $line1 = '';
    my $par   = 0;
    my $n     = $node;
    while ( ( not $par ) and $n ) {
        if ( $n->{is_parenthesis_root} ) {
            $par = 1;
        }
        $n = $n->parent;
    }
    if ($par) {
        $line1 = $self->_colors->get( 'parenthesis', 1 );
    }
    if ( defined($node->form) ){
        $line1 .= $node->form;
    }
    elsif ( defined($node->lemma) ){
        $line1 .= $self->_colors->get( 'error', 1 ) . $node->lemma;
    }

    my $edge_label = $node->afun || $node->conll_deprel;
    my $color = $edge_label && $edge_label ne 'NR' ? $self->_colors->get( 'afun', 1 ) : $self->_colors->get( 'error', 1 );
    my $line2 = $color . ( $edge_label || '!!' );
    if ( $node->is_member ) {
        my $parent = $node->parent;
        while ( $parent && ( ( $parent->afun || '' ) =~ m/^Aux[CP]$/ ) )    #skip AuxCP
        {
            $parent = $parent->parent;
        }
        if ( $parent->afun =~ m/^(Ap)os|(Co)ord/ ) {
            $line2 .= '_' . $self->_colors->get( 'member', 1 ) . ( $1 ? $1 : $2 );
        }
    }
    if ( $node->gloss ) {
        $line2 .= ' ' . $self->_colors->get( 'gloss', 1 ) . $node->gloss;
    }

    my $line3_1 = $node->tag ? $node->tag : '';
    my $line3_2 = $node->lemma ? $node->lemma : '';

    # DZ: This hack tries to distinguish Dan's CoNLL trees from Pepa's PEDT trees
    #     so that Czech tags don't get crippled in the former.
    # if ( $node->language eq 'cs' ) {
    if ( $node->language eq 'cs' && !$node->conll_cpos ) {
        $line3_1 =  $self->_shorten_czech_tag( $line3_1 );
        $line3_2 =~ s/(.)(?:-[1-9][0-9]*)?(?:(?:`|_[:;,^]).*)?$/$1/;
    }

    $line3_1 = $self->_colors->get( 'tag', 1 ) . $line3_1;

    return [
        [$line1],
        [$line2],
        [ $line3_1, $line3_2 ]
    ];
}

sub _shorten_czech_tag {
    my ($self, $tag) = @_;
     
    # nouns, adjectives, pronouns, declinable numerals: gender, number, case
    if ($tag =~ m/^(N|C[adhjklnrwyz\?]|P|A)/){ 
        $tag = substr( $tag, 0, 2 ) . $self->_colors->get( 'tag_feat', 1 ) . substr( $tag, 2, 3 );
    }
    # prepositions: just case
    elsif ($tag =~ m/^R/ ){
        $tag = substr( $tag, 0, 2 ) . $self->_colors->get( 'tag_feat', 1 ) . substr( $tag, 4, 1 );
    }
    # verbs (except infinitives, conditionals): gender, number, person, tense, voice
    elsif ($tag =~ m/^V[^cf]/ ){
        $tag = substr( $tag, 0, 2)  . $self->_colors->get( 'tag_feat', 1 ) 
            . substr( $tag, 2, 2 ) . substr( $tag, 7, 2 ) . substr( $tag, 11, 1 );
    }
    else {
        $tag = substr( $tag, 0, 2 );
    }
    return $tag;
}

sub _tnode_labels {
    my ( $self, $node ) = @_;

    my $line1 = $node->t_lemma;
    if ( $node->is_parenthesis ) {
        $line1 = $self->_colors->get( 'parenthesis', 1 ) . $line1;
    }
    if ( $node->sentmod ) {
        $line1 .= $self->_colors->get( 'sentmod', 1 ) . '.' . $node->sentmod;
    }

    foreach my $type ( 'compl', 'coref_text', 'coref_gram' ) {
        if ( defined $node->{ $type . '.rf' } ) {
            foreach my $ref ( TredMacro::ListV( $node->{ $type . '.rf' } ) ) {
                my $ref_node = $self->_treex_doc->get_node_by_id($ref);
                if ( $node->get_bundle->get_position() != $ref_node->get_bundle->get_position() ) {
                    $line1 .= ' ' . $self->_colors->get( $type, 1 ) . $ref_node->{t_lemma};
                }
            }
        }
    }

    my $line2 = $node->{functor};
    $line2 .= $self->_colors->get( 'subfunctor', 1 ) . '.' . $node->{subfunctor} if $node->{subfunctor};
    $line2 .= $self->_colors->get( 'subfunctor', 1 ) . '.state'                  if $node->{is_state};
    $line2 .= $self->_colors->get( 'subfunctor', 1 ) . '.dsp_root'               if $node->{is_dsp_root};
    $line2 .= $self->_colors->get( 'member',     1 ) . '.member'                 if $node->{is_member};
    $line2 .= $self->_colors->get( 'formeme',    1 ) . ' ' . $node->formeme      if $node->formeme;

    my @a_nodes = ();
    my $line3_1 = '';
    if ( defined $node->attr('a/aux.rf') ) {
        @a_nodes = TredMacro::ListV( $node->attr('a/aux.rf') );
        @a_nodes = map { $self->_treex_doc->get_node_by_id($_) } @a_nodes;
        @a_nodes = map { { form => $_->{form}, ord => $_->{ord}, type => 'aux' } } @a_nodes;
    }
    if ( defined $node->attr('a/lex.rf') ) {
        my $a_node = $self->_treex_doc->get_node_by_id( $node->attr('a/lex.rf') );
        push @a_nodes, { form => $a_node->{form}, ord => $a_node->{ord}, type => 'lex' };
    }
    if (@a_nodes) {
        @a_nodes = sort { $a->{ord} <=> $b->{ord} } @a_nodes;
        @a_nodes = map { ( $_->{type} eq 'lex' ? $self->_colors->get( 'lex', 1 ) : $self->_colors->get( 'aux', 1 ) ) . ( $_->{form} // '' ) } @a_nodes; #/
        $line3_1 = join " ", @a_nodes;
    }

    my $line3_2 = $self->_colors->get( 'nodetype', 1 ) . ($node->{nodetype} || '');
    $line3_2 .= $self->_colors->get( 'sempos', 1 ) . '.' . $node->attr('gram/sempos') if $node->attr('gram/sempos');

    return [
        [$line1],
        [$line2],
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

#    my $terminal = $node->get_pml_type_name eq 'p-terminal.type' ? 1 : 0;

    my $line1 = '';
    my $line2 = '';
    my $edgelabel = $node->edgelabel() ? '/'.$node->edgelabel() : '';
#    print "$node is_leaf ".$node->is_leaf."\n";
    if ( $node->is_leaf ) {
        $line1 = $node->{form};
        $line2 = $node->{tag}.$edgelabel;
        $line2 = '-' if $line2 eq '-NONE-';
    }
    else {
        my $phrase = $node->{phrase} ? $node->{phrase} : '';
        $line1 = $self->_colors->get( 'phrase', 1 ) . $phrase.$edgelabel . '#{black}' . join( '', map {"-$_"} TredMacro::ListV( $node->{functions} ) );
    }

    return [
        [$line1],
        [$line2],
        ['']
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

=over 4

=item _build_label_variants

=item _get_label_variant

=item _rotate_label_variant

=item _anode_labels

=item _tnode_labels

=item _nnode_labels

=item _pnode_labels

=back

=head1 AUTHOR

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
