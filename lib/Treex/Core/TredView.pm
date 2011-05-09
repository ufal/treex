package Treex::Core::TredView;

# planned to be used from contrib.mac of tred's extensions

use Moose;
use Treex::Core::Log;
use Treex::Core::TredView::TreeLayout;
use Treex::Core::TredView::Labels;
use Treex::Core::TredView::Styles;
use List::Util qw(first);

has 'grp'       => ( is => 'rw' );
has 'pml_doc'   => ( is => 'rw' );
has 'treex_doc' => ( is => 'rw' );
has 'tree_layout' => (
    is      => 'ro',
    isa     => 'Treex::Core::TredView::TreeLayout',
    default => sub { Treex::Core::TredView::TreeLayout->new() }
);
has 'labels' => (
    is      => 'ro',
    isa     => 'Treex::Core::TredView::Labels',
    builder => '_build_labels',
    lazy    => 1
);
has '_styles' => (
    is      => 'ro',
    isa     => 'Treex::Core::TredView::Styles',
    builder => '_build_styles',
    lazy    => 1
);

sub _build_labels {
    my $self = shift;
    return Treex::Core::TredView::Labels->new( _treex_doc => $self->treex_doc );
}

sub _build_styles {
    my $self = shift;
    return Treex::Core::TredView::Styles->new( _treex_doc => $self->treex_doc );
}

sub _spread_nodes {
    my ( $self, $node ) = @_;

    my ( $left, $right, $gap, $pos ) = ( -1, 0, 0, 0 );
    my ( @buf, @lower );
    for my $child ( $node->children ) {
        ( $pos, @buf ) = $self->_spread_nodes($child);
        if ( $left < 0 ) {
            $left = $pos;
        }
        $right += $gap;
        $gap = scalar(@buf);
        push @lower, @buf;
    }
    $right += $pos;
    return ( 0, $node ) unless @lower;

    my $mid;
    if ( scalar( $node->children ) == 1 ) {
        $mid = int( ( $#lower + 1 ) / 2 - 1 );
    }
    else {
        $mid = int( ( $left + $right ) / 2 );
    }

    return ( $mid + 1 ), @lower[ 0 .. $mid ], $node, @lower[ ( $mid + 1 ) .. $#lower ];
}

sub get_nodelist_hook {
    my ( $self, $fsfile, $treeNo, $currentNode ) = @_;

    return if not $self->pml_doc();    # get_nodelist_hook is invoked also before file_opened_hook

    my $bundle = $fsfile->tree($treeNo);
    bless $bundle, 'Treex::Core::Bundle';    # TODO: how to make this automatically?
                                             # Otherwise (in certain circumstances) $bundle->get_all_zones
                                             # results in Can't locate object method "get_all_zones" via package "Treex::PML::Node" at /ha/work/people/popel/tectomt/treex/lib/Treex/Core/TredView.pm line 22

    my $layout = $self->tree_layout->get_layout();
    my %nodes;

    foreach my $tree ( map { $_->get_all_trees } $bundle->get_all_zones ) {
        my $label = $self->tree_layout->get_tree_label($tree);
        my @nodes;
        if ( $tree->get_layer eq 'p' ) {
            ( my $foo, @nodes ) = $self->_spread_nodes($tree);
        }
        elsif ( $tree->does('Treex::Core::Node::Ordered') ) {
            @nodes = $tree->get_descendants( { add_self => 1, ordered => 1 } );
        }
        else {
            @nodes = $tree->get_descendants( { add_self => 1 } );
        }
        $nodes{$label} = \@nodes;
    }

    my $pick_next_tree = sub {
        my @task      = @_;
        my $max       = 0;
        my $max_index = -1;

        for ( my $i = 0; $i < scalar @task; $i++ ) {
            my $val = $task[$i]->{'left'} / $task[$i]->{'total'};
            if ( $val > $max ) {
                $max       = $val;
                $max_index = $i;
            }
        }

        return $max_index;
    };

    my @nodes = ($bundle);

    for ( my $col = 0; $col < scalar @$layout; $col++ ) {
        my @task = ();
        for ( my $row = 0; $row < scalar @{ $layout->[$col] }; $row++ ) {
            if ( $layout->[$col]->[$row] ) {
                my $label     = $layout->[$col]->[$row];
                my %tree_info = ();
                $tree_info{'total'} = $tree_info{'left'} = scalar @{ $nodes{$label} };
                $tree_info{'label'} = $label;
                push @task, \%tree_info;
            }
        }

        while ( ( my $index = &$pick_next_tree(@task) ) >= 0 ) {
            push @nodes, shift @{ $nodes{ $task[$index]->{'label'} } };
            $task[$index]->{'left'}--;
        }
    }

    if ( not( first { $_ == $currentNode } @nodes ) ) {
        $currentNode = $nodes[0];
    }
    return [ \@nodes, $currentNode ];
}

sub file_opened_hook {
    my ($self) = @_;
    my $pmldoc = $self->grp()->{FSFile};

    $self->pml_doc($pmldoc);
    my $treex_doc = Treex::Core::Document->new( { pmldoc => $pmldoc } );
    $self->treex_doc($treex_doc);
    $self->precompute_tree_depths();
    $self->precompute_tree_shifts();
    $self->precompute_visualization();
    return;
}

sub get_value_line_hook {
    my ( $self, undef, $treeNo ) = @_;    # the unused argument stands for $fsfile
    return if not $self->pml_doc();

    my $bundle = $self->pml_doc->tree($treeNo);

    my @out = ();
    my @t_trees = map { $_->get_ttree() } grep { $_->has_ttree() } $bundle->get_all_zones();

    for my $t_tree (@t_trees) {
        push @out, ( [ '[' . $t_tree->get_zone->get_label . ']', 'label' ], [ ' ', 'space' ] );

        my $a_tree = $bundle->get_tree( $t_tree->language, 'a', $t_tree->selector );

        my %refs = ();
        for my $node ( $t_tree->get_descendants ) {
            for my $aux ( TredMacro::ListV( $node->attr('a/aux.rf') ) ) {
                push @{ $refs{$aux} }, $node;
            }
            push @{ $refs{ $node->attr('a/lex.rf') } }, $node if $node->attr('a/lex.rf');
        }

        my @a_nodes = $a_tree->get_descendants( { ordered => 1 } );

        for my $node (@a_nodes) {
            my $id = $node->id;
            push @{ $refs{$id} }, $node;
            if ( $node->attr('p/terminal.rf') ) {
                my $p_node = $self->treex_doc->get_node_by_id( $node->attr('p/terminal.rf') );
                push @{ $refs{$id} }, $p_node;
                while ( $p_node->parent ) {
                    $p_node = $p_node->parent;
                    push @{ $refs{$id} }, $p_node;
                }
            }
        }

        for ( my $i = 0; $i <= $#a_nodes; $i++ ) {
            push @out, [ $a_nodes[$i]->form, @{ $refs{ $a_nodes[$i]->id } || [] }, 'anode:' . $a_nodes[$i]->id ];
            if ( !$a_nodes[$i]->no_space_after ) {
                push @out, [ ' ', 'space' ];
            }
        }

        push @out, [ "\n", 'newline' ];
    }

    return \@out;
}

sub value_line_doubleclick_hook {
    my ( $self, @tags ) = @_;
    my %tags;
    @tags{@tags} = 1;

    my $bundle = $TredMacro::root;

    my $layout = $self->tree_layout->get_layout;
    my %ordering;
    my $i     = 0;
    my $row   = 0;
    my $found = 1;

    while ($found) {
        $found = 0;
        for ( my $col = 0; $col < scalar @$layout; $col++ ) {
            if ( $layout->[$col]->[$row] ) {
                $ordering{ $layout->[$col]->[$row] } = $i++;
                $found = 1;
            }
        }
        $row++;
    }
    my @trees = sort { $ordering{ $self->tree_layout->get_tree_label($a) } <=> $ordering{ $self->tree_layout->get_tree_label($b) } } $bundle->get_all_trees;

    for my $tree (@trees) {
        for my $node ( $tree->get_descendants ) {
            next if $node->get_layer eq 'p' and $node->get_pml_type_name =~ m/nonterminal/;
            return $node if exists $tags{"$node"};
        }
    }

    return 'stop';
}

# --------------- PRECOMPUTING VISUALIZATION (node labels, styles, coreference links, groups...) ---

my @layers = qw(a t p n);

# To be run only once when the file is opened. Tree depths never change.
sub precompute_tree_depths {
    my ($self) = @_;
    foreach my $bundle ( $self->treex_doc->get_bundles ) {
        foreach my $zone ( $bundle->get_all_zones ) {
            foreach my $tree ( $zone->get_all_trees ) {
                my $max_depth = 1;
                my @front = ( 1, $tree );

                while (@front) {
                    my $cur_depth = shift @front;
                    my $node      = shift @front;
                    $max_depth = $cur_depth if $cur_depth > $max_depth;
                    for my $child ( $node->get_children ) {
                        push @front, $cur_depth + 1, $child;
                        $child->{_depth} = $cur_depth + 1 if $child->get_layer eq 'p';
                    }
                }

                $tree->{_tree_depth} = $max_depth;
            }
        }
    }
}

# Has to be run whenever the tree layout changes.
sub precompute_tree_shifts {
    my ($self) = @_;

    foreach my $bundle ( $self->treex_doc->get_bundles ) {
        my $layout = $self->tree_layout->get_layout($bundle);
        my %forest = ();

        foreach my $zone ( $bundle->get_all_zones ) {
            foreach my $tree ( $zone->get_all_trees ) {
                $forest{ $self->tree_layout->get_tree_label($tree) } = $tree;
            }
        }

        my @trees     = ('foo');
        my $row       = 0;
        my $cur_shift = 0;
        while (@trees) {
            my $max_depth = 0;
            @trees = ();
            for ( my $col = 0; $col < scalar @$layout; $col++ ) {
                if ( my $label = $layout->[$col]->[$row] ) {
                    my $depth = $forest{$label}->{_tree_depth};
                    push @trees, $label;
                    $max_depth = $depth if $depth > $max_depth;
                    $forest{$label}->{'_shift_right'} = $col;
                }
            }

            for my $label (@trees) {
                $forest{$label}->{'_shift_down'} = $cur_shift;
            }
            $cur_shift += $max_depth;
            $row++;
        }
    }
}

sub precompute_visualization {
    my ($self) = @_;
    my %limits;

    foreach my $bundle ( $self->treex_doc->get_bundles ) {

        $bundle->{_precomputed_root_style} = $self->_styles->bundle_style($bundle);
        $bundle->{_precomputed_node_style} = '#{Node-hide:1}';

        foreach my $zone ( $bundle->get_all_zones ) {

            foreach my $layer (@layers) {
                if ( $zone->has_tree($layer) ) {
                    my $root = $zone->get_tree($layer);

                    $root->{_precomputed_labels}     = $self->labels->root_labels($root);
                    $root->{_precomputed_node_style} = $self->_styles->node_style($root);
                    $root->{_precomputed_hint}       = '';

                    foreach my $node ( $root->get_descendants ) {
                        $node->{_precomputed_node_style} = $self->_styles->node_style($node);
                        $node->{_precomputed_hint}       = $self->node_hint( $node, $layer );
                        $node->{_precomputed_buffer}     = $self->labels->node_labels( $node, $layer );
                        $self->labels->set_labels($node);

                        if ( not defined $limits{$layer} ) {
                            for ( my $i = 0; $i < 3; $i++ ) {
                                $limits{$layer}->[$i] = scalar( @{ $node->{_precomputed_buffer}->[$i] } ) - 1;
                            }
                        }
                    }
                }
            }
        }
    }

    for my $layer ( 'p', 'a', 't', 'n' ) {
        for ( my $i = 0; $i < 3; $i++ ) {
            $self->labels->set_limit( $layer, $i, $limits{$layer}->[$i] );
        }
    }

    return;
}

# ---- info displayed when mouse stops over a node - "hint" (should return a string, that may contain newlines) ---

sub node_hint {    # silly code just to avoid the need for eval
    my $layer = pop @_;
    my %subs;
    $subs{t} = \&tnode_hint;
    $subs{a} = \&anode_hint;
    $subs{n} = \&nnode_hint;
    $subs{p} = \&pnode_hint;

    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }(@_);
    }
    else {
        log_fatal "Undefined or unknown layer: $layer";
    }

    return;
}

sub anode_hint {
    my ( $self, $node ) = @_;
    my @lines = ();

    push @lines, "Parenthesis root" if $node->{is_parenthesis_root};
    if ( $node->language eq 'cs' ) {
        push @lines, "Full lemma: " . $node->{lemma};
        push @lines, "Full tag: " . $node->{tag};
    }

    return join "\n", @lines;
}

sub tnode_hint {
    my ( $self, $node ) = @_;
    my @lines = ();

    if ( ref $node->get_attr('gram') ) {
        foreach my $gram ( keys %{ $node->get_attr('gram') } ) {
            push @lines, "gram/$gram : " . $node->get_attr( 'gram/' . $gram );
        }
    }

    push @lines, "Direct speech root" if $node->get_attr('is_dsp_root');
    push @lines, "Parenthesis"        if $node->get_attr('is_parenthesis');
    push @lines, "Name of person"     if $node->get_attr('is_name_of_person');
    push @lines, "Name"               if $node->get_attr('is_name');
    push @lines, "State"              if $node->get_attr('is_state');
    push @lines, "Quotation : " . join ", ", map { $_->{type} } TredMacro::ListV( $node->get_attr('quot') ) if $node->get_attr('quot');

    return join "\n", @lines;
}

sub nnode_hint {
    my ( $self, $node ) = @_;
    return undef;
}

sub pnode_hint {
    my ( $self, $node ) = @_;

    my @lines = ();
    my $terminal = $node->get_pml_type_name eq 'p-terminal.type' ? 1 : 0;

    if ($terminal) {
        push @lines, "lemma: " . $node->{lemma};
        push @lines, "tag: " . $node->{tag};
        push @lines, "form: " . $node->{form};
    }
    else {
        push @lines, "phrase: " . $node->{phrase};
        push @lines, "functions: " . join( ', ', TredMacro::ListV( $node->{functions} ) );
    }

    return join "\n", @lines;
}

# --- arrows ----

# copied from TectoMT_TredMacros.mak
sub node_style_hook {
    my ( $self, $node, $styles ) = @_;

    return if ref($node) eq 'Treex::Core::Bundle';

    my %line = TredMacro::GetStyles( $styles, 'Line' );
    my @target_ids;
    my @arrow_types;

    foreach my $ref_attr ( 'coref_gram', 'coref_text', 'compl' ) {
        if ( defined $node->attr( $ref_attr . '.rf' ) ) {
            foreach my $target_id ( @{ $node->attr( $ref_attr . '.rf' ) } ) {
                push @target_ids,  $target_id;
                push @arrow_types, $ref_attr;
            }
        }
    }

    # alignment
    if ( my $links = $node->attr('alignment') ) {
        foreach my $link (@$links) {
            push @target_ids,  $link->{'counterpart.rf'};
            push @arrow_types, 'alignment';
        }
    }

    $self->_styles->draw_arrows( $node, $styles, \%line, \@target_ids, \@arrow_types, );

    my %n = TredMacro::GetStyles( $styles, 'Node' );
    TredMacro::AddStyle( $styles, 'Node', -tag => ( $n{-tag} || '' ) . '&' . $node->{id} );

    my $xadj = $node->root->{'_shift_right'} * 50;
    if (ref($node) =~ m/^Treex::Core::Node/
        and $node->get_layer eq 'p'
        and not $node->is_root and scalar $node->parent->children == 1
        )
    {
        $xadj += 15;
    }
    TredMacro::AddStyle( $styles, 'Node', -xadj => $xadj ) if $xadj;

    return;
}

# ---- END OF PRECOMPUTING VISUALIZATION ------

sub conf_dialog {
    my $self = shift;
    if ( $self->tree_layout->conf_dialog() ) {
        $self->precompute_tree_shifts();
        $self->precompute_visualization();
    }
}

1;

__END__

=for Pod::Coverage precompute_visualization

=head1 NAME

Treex::Core::TredView - visualization of Treex files in TrEd

=head1 DESCRIPTION

This module is used only in an extension of the Tree editor TrEd
developed for displaying .treex files. The TrEd extension is contained
in the same distribution as this module. The extension itself
is very thin. It only creates an instance of C<Treex::Core::TredView>
and then forwards calls of hooks (subroutines with predefined
names called by TrEd at certain events) to this instance.

This module defines what information (especially which node attributes)
should be displayed below nodes in the individual types of trees
and what visual style (e.g. node and edge color, node size, edge
thickness) should be used for them.

The TrEd visualization is precomputed statically after a file is loaded,
therefore the extension can be currently used only for browsing, not for
editting the treex files.

=head1 METHODS


=head2 Methods called from the TrEd extension

Methods called directly from the hooks in the TrEd extension:

=over 4

=item file_opened_hook

Building L<Treex::Core::Document> structure on the top of
L<Treex::PML::Document> structure which was provided by TrEd.

=item get_nodelist_hook

=item get_value_line_hook

=item value_line_doubleclick_hook

=item node_style_hook

=item conf_dialog

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

