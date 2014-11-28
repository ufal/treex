package Treex::Core::TredView;

# planned to be used from contrib.mac of tred's extensions

use Moose;
use Treex::Core::Log;
use Treex::Core::TredView::TreeLayout;
use Treex::Core::TredView::Labels;
use Treex::Core::TredView::Styles;
use Treex::Core::TredView::Vallex;
use Treex::Core::Types;
use Scalar::Util qw(blessed refaddr);
use List::Util qw(first);
use Cache::LRU;

use Treex::Core::Config;
$Treex::Core::Config::running_in_tred = 1;

has 'grp'       => ( is => 'rw' );
has 'pml_doc'   => ( is => 'rw' );
has 'doc_cache' => (
    is  => 'ro',
    isa => 'Cache::LRU',
    default => sub { Cache::LRU->new(size => 20); }
);
has 'treex_doc' => ( is => 'rw' );
has 'tree_layout' => (
    is      => 'ro',
    isa     => 'Treex::Core::TredView::TreeLayout',
    default => sub { Treex::Core::TredView::TreeLayout->new() }
);

has 'labels' => (
    is     => 'ro',
    isa    => 'Treex::Core::TredView::Labels',
    writer => '_set_labels',
);

has '_styles' => (
    is     => 'ro',
    isa    => 'Treex::Core::TredView::Styles',
    writer => '_set_styles',
);

has 'vallex' => (
    is     => 'ro',
    isa    => 'Treex::Core::TredView::Vallex',
    writer => '_set_vallex',
);

has fast_loading => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'Do the precomputation lazily for each bundle',
);

has _displayed_nodes => (
    is      => 'rw',
    isa     => 'HashRef[Treex::Core::Node]',
    default => sub { {} }
);
has _ptb_index_map => (
    is      => 'rw',
    isa     => 'HashRef[Treex::Core::Node::P]',
    default => sub { {} }
);
has _ptb_coindex_map => (
    is      => 'rw',
    isa     => 'HashRef[Treex::Core::Node::P]',
    default => sub { {} }
);

has 'clause_collapsing' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'show_alignment'    => ( is => 'rw', isa => 'Bool', default => 1 );

has 'tree_type_to_wrap'    => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

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
    return ( 0, $node ) if !@lower;

    my $mid;
    if ( scalar( $node->children ) == 1 ) {
        $mid = int( ( $#lower + 1 ) / 2 - 1 );
    }
    else {
        $mid = int( ( $left + $right ) / 2 );
    }

    return ( $mid + 1 ), @lower[ 0 .. $mid ], $node, @lower[ ( $mid + 1 ) .. $#lower ];
}

sub _pmldoc_equals {
    my ($self, $fsfile) = @_;
    return ($self->pml_doc && $fsfile && refaddr($self->pml_doc) == refaddr($fsfile));
}

sub get_nodelist_hook {
    my ( $self, $fsfile, $treeNo, $currentNode ) = @_;

    #return if not $self->pml_doc();    # get_nodelist_hook is invoked also before file_opened_hook

    unless ($self->_pmldoc_equals($fsfile)) {
        $self->file_opened_hook($fsfile);
    }

    my $bundle = $fsfile->tree($treeNo);
    bless $bundle, 'Treex::Core::Bundle';    # TODO: how to make this automatically?
                                             # Otherwise (in certain circumstances) $bundle->get_all_zones
                                             # results in Can't locate object method "get_all_zones" via package "Treex::PML::Node" at /ha/work/people/popel/tectomt/treex/lib/Treex/Core/TredView.pm line 22

    my $layout = $self->tree_layout->get_layout();
    $self->{'_ptb_index_map'}   = {};
    $self->{'_ptb_coindex_map'} = {};
    my %nodes;

    foreach my $tree ( map { ref($_) eq 'Treex::Core::BundleZone' ? $_->get_all_trees : () } $bundle->get_all_zones ) {
        my $label = $self->tree_layout->get_tree_label($tree);
        my @nodes;
        if ( $tree->get_layer eq 'p' ) {
            @nodes = $self->_spread_nodes($tree);
            shift @nodes;
            foreach my $node (@nodes) {
                $self->{'_ptb_index_map'}->{ $node->{'index'} }     = $node if defined $node->{'index'};
                $self->{'_ptb_coindex_map'}->{ $node->{'coindex'} } = $node if defined $node->{'coindex'};
            }
        }

        elsif ( $self->tree_type_to_wrap->{$self->_tree_type_signature($tree)} ) {
            @nodes = $tree;
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
            my $val = $task[$i]{'left'} / $task[$i]{'total'};
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
            if ( $layout->[$col][$row] and $layout->[$col][$row]->{'visible'} ) {
                my $label     = $layout->[$col][$row]->{'label'};
                my %tree_info = ();
                $tree_info{'total'} = $tree_info{'left'} = scalar @{ $nodes{$label} };
                $tree_info{'label'} = $label;
                push @task, \%tree_info;
            }
        }

        while ( ( my $index = &$pick_next_tree(@task) ) >= 0 ) {
            push @nodes, shift @{ $nodes{ $task[$index]{'label'} } };
            $task[$index]{'left'}--;
        }
    }

    # only nodes having different clause number from their parents are
    # displayed if node-collapsing is switched on
    if ( ( $self->clause_collapsing || 0 ) != ( $bundle->{_is_collapsed} || 0 ) ) {
        $self->clause_collapsing( $bundle->{_is_collapsed} );
    }
    if ( $self->clause_collapsing ) {
        my %root;
        foreach my $node ( grep { $_->isa('Treex::Core::Node::A') } @nodes ) {
            if ( defined $node->clause_number ) {
                $root{$node} = $node->get_clause_root;
            }
        }
        my %hide;
        foreach my $node ( grep { $_->isa('Treex::Core::Node::A') } @nodes ) {
            my $parent = $node->get_parent;
            if ( defined $node->clause_number and $root{$node} ne $node ) {
                $hide{$node} = 1;
            }
        }
        @nodes = grep { !$hide{$_} } @nodes;
        foreach my $node ( grep { $_->isa('Treex::Core::Node::A') } @nodes ) {
            my $parent = $node->get_parent;
            if ( $parent and $hide{$parent} ) {
                $node->set_parent( $root{$parent} );
            }
        }
    }

    $self->{'_displayed_nodes'} = { map { $_->attr('id') => 1 } @nodes };

    unless ( $currentNode and ( first { $_ == $currentNode } @nodes ) ) {
        $currentNode = $nodes[0];
    }

    return [ \@nodes, $currentNode ];
}

sub recompute_visualization {
    my ( $self, $bundle ) = @_;
    $self->precompute_tree_depths($bundle);
    $self->precompute_tree_shifts($bundle);
    $self->precompute_visualization($bundle);
    $self->precompute_value_line($bundle);
    return;
}

sub file_opened_hook {
    my ($self, $fsfile) = @_;
    my $pmldoc = $fsfile || $self->grp()->{FSFile};

    return unless $pmldoc && $pmldoc->metaData('schema') &&
      $pmldoc->metaData('schema')->get_root_name() eq 'treex_document';

    return if $self->_pmldoc_equals($pmldoc);

    $self->pml_doc($pmldoc);

    my $treex_doc = $self->doc_cache->get(refaddr($self->pml_doc));
    unless ($treex_doc) {
        if ( defined $pmldoc->[13]->{_treex_core_document} ) { # if it comes from storable (i.e., already with moose)
            $treex_doc = $pmldoc->[13]->{_treex_core_document};

            # streex files do not have "wild_dump" filled, but we want to show this in ttred
            $treex_doc->_serialize_all_wild();
        } else {
            $treex_doc = Treex::Core::Document->new( { pmldoc => $pmldoc } );
        }
        $self->doc_cache->set(refaddr($self->pml_doc), $treex_doc);
    }

    $self->treex_doc($treex_doc);

    # labels, styles and vallex must be created again for each file
    $self->_set_labels( Treex::Core::TredView::Labels->new( _treex_doc => $treex_doc ) );
    $self->_set_styles( Treex::Core::TredView::Styles->new( _treex_doc => $treex_doc ) );
    $self->_set_vallex( Treex::Core::TredView::Vallex->new( _treex_doc => $treex_doc ) );

    foreach my $bundle ( $treex_doc->get_bundles() ) {

        # If we don't care about slow loading of the whole file,
        # we can precompute all bundles now, so browsing through bundles
        # will be a bit faster.
        if ( !$self->fast_loading && !$bundle->{_precomputed} ) {
            $self->precompute_tree_depths($bundle);
            $self->precompute_tree_shifts($bundle);
            $self->precompute_visualization($bundle);
            $bundle->{_precomputed} = 1;
        }

        # Root style cannot be precomputed lazily, because
        # root_style_hook is executed after reading the precomputed root style,
        # so there is no hook where to place the lazy precomputation.
        $bundle->{_precomputed_root_style} = $self->_styles->bundle_style($bundle);
    }
    return;
}

sub get_value_line_hook {
    my ( $self, $fsfile, $treeNo ) = @_;    # the unused argument stands for $fsfile
    #return if not $self->pml_doc();

    unless ($self->_pmldoc_equals($fsfile)) {
        $self->file_opened_hook($fsfile);
    }

    my $bundle = $self->pml_doc->tree($treeNo);
    if ( !$bundle->{_precomputed_value_line} ) {
        $self->precompute_value_line($bundle);
    }
    return $bundle->{_precomputed_value_line};
}

sub value_line_doubleclick_hook {
    my ( $self, @tags ) = @_;
    my %tags;
    @tags{@tags} = 1;

    my $bundle = $TredMacro::root;

    my $layout = $self->tree_layout->get_layout;
    my %ordering;
    my %visible;
    my $i     = 0;
    my $row   = 0;
    my $found = 1;

    while ($found) {
        $found = 0;
        for ( my $col = 0; $col < scalar @$layout; $col++ ) {
            if ( defined $layout->[$col][$row] ) {
                if ( $layout->[$col][$row]->{'visible'} ) {
                    $ordering{ $layout->[$col][$row]->{'label'} } = $i++;
                    $visible{ $layout->[$col][$row]->{'label'} }  = 1;
                }
                $found = 1;
            }
        }
        $row++;
    }
    my @trees = sort {
        $ordering{ $self->tree_layout->get_tree_label($a) } <=> $ordering{ $self->tree_layout->get_tree_label($b) }
        } grep {
        exists $visible{ $self->tree_layout->get_tree_label($_) }
        } $bundle->get_all_trees;

    for my $tree (@trees) {
        for my $node ( $tree->get_descendants ) {
            next if $node->get_layer eq 'p' and not $node->is_terminal;
            return $node if exists $tags{"$node"};
        }
    }

    return 'stop';
}

# --------------- PRECOMPUTING VISUALIZATION (node labels, styles, coreference links, groups...) ---

my @layers = map {lc} Treex::Core::Types::layers();

# To be run only once when the file is opened. Tree depths never change.
sub precompute_tree_depths {
    my ( $self, $bundle ) = @_;

    foreach my $zone ( $bundle->get_all_zones ) {
        foreach my $tree ( ref($zone) eq 'Treex::Core::BundleZone' ? $zone->get_all_trees : () ) {
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
    return;
}

sub node_release_hook {
    my ($self, $node, $target, $mod) = @_;
    my @roots = map { $_->get_root } $node, $target;
    my @zones = map { $_->get_zone } $node, $target;

    if ($self->show_alignment
        and
        $roots[0] != $roots[1] and $zones[0] != $zones[1]) {

        if ($node->is_aligned_to($target, 'alignment')) {
            $node->delete_aligned_node($target, 'alignment');
        } else {
            $node->add_aligned_node($target, 'alignment');
        }

        # TODO: Is there more treexy way to do it?
        TredMacro::Redraw();

        return 'stop';
    }
}

# Has to be run whenever the tree layout changes.
sub precompute_tree_shifts {
    my ( $self, $bundle ) = @_;

    my $layout = $self->tree_layout->get_layout($bundle);
    my %forest = ();

    foreach my $zone ( $bundle->get_all_zones ) {
        foreach my $tree ( ref($zone) eq 'Treex::Core::BundleZone' ? $zone->get_all_trees : () ) {
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
            if ( defined $layout->[$col][$row] ) {
                my $label = $layout->[$col][$row]->{'label'};
                my $depth = $forest{$label}{_tree_depth};
                push @trees, $label;
                $max_depth = $depth if $depth > $max_depth;
                $forest{$label}{'_shift_right'} = $col;
            }
        }

        for my $label (@trees) {
            $forest{$label}{'_shift_down'} = $cur_shift;
        }
        $cur_shift += $max_depth;
        $row++;
    }
    return;
}

sub precompute_visualization {
    my ( $self, $bundle ) = @_;

    $bundle->{_precomputed_node_style} = '#{Node-hide:1}';

    foreach my $zone ( $bundle->get_all_zones ) {
        foreach my $layer (@layers) {
            if ( ref($zone) eq 'Treex::Core::BundleZone' && $zone->has_tree($layer) ) {
                my $root   = $zone->get_tree($layer);
                my $limits = $self->labels->get_limits($layer);

                $root->{_precomputed_labels}     = $self->labels->root_labels($root);
                $root->{_precomputed_node_style} = $self->_styles->node_style($root);
                $root->{_precomputed_hint}       = '';

                if ( $root->get_zone->sentence ) {
                    $root->{_precomputed_hint} = 'sentence: ' . $root->get_zone->sentence;
                }

                foreach my $node ( $root->get_descendants ) {
                    $node->{_precomputed_node_style} = $self->_styles->node_style($node);
                    $node->{_precomputed_hint}       = $self->node_hint( $node, $layer );
                    $node->{_precomputed_buffer}     = $self->labels->node_labels( $node, $layer );
                    $self->labels->set_labels($node);

                    if ( !$limits ) {
                        for ( my $i = 0; $i < 3; $i++ ) {
                            $self->labels->set_limit( $layer, $i, scalar( @{ $node->{_precomputed_buffer}[$i] } ) - 1 );
                        }
                        $limits = 1;
                    }
                }
            }
        }
    }
    return;
}

sub get_clickable_sentence_for_a_zone {
    my ( $self, $zone, $alignment ) = @_;
    return if !$zone->has_atree();
    my %refs = ();

    if ( $zone->has_ttree() ) {
        for my $tnode ( $zone->get_ttree->get_descendants ) {
            for my $aux ( TredMacro::ListV( $tnode->attr('a/aux.rf') ) ) {
                push @{ $refs{$aux} }, $tnode;
                if ( exists $alignment->{ $tnode->get_attr('id') } ) {
                    push @{ $refs{$aux} }, @{ $alignment->{ $tnode->get_attr('id') } };
                }
            }
            if ( $tnode->attr('a/lex.rf') ) {
                push @{ $refs{ $tnode->attr('a/lex.rf') } }, $tnode;
                if ( exists $alignment->{ $tnode->get_attr('id') } ) {
                    push @{ $refs{ $tnode->attr('a/lex.rf') } }, @{ $alignment->{ $tnode->get_attr('id') } };
                }
            }
        }
    }

    my @anodes = $zone->get_atree->get_descendants( { ordered => 1 } );
    for my $anode (@anodes) {
        my $id = $anode->id;
        push @{ $refs{$id} }, $anode;
        if ( exists $alignment->{$id} ) {
            push @{ $refs{$id} }, @{ $alignment->{$id} };
        }
        if ( $anode->attr('p_terminal.rf') ) {
            my $pnode = $self->treex_doc->get_node_by_id( $anode->attr('p_terminal.rf') );
            push @{ $refs{$id} }, $pnode;
            while ( $pnode->parent ) {
                $pnode = $pnode->parent;
                push @{ $refs{$id} }, $pnode;
            }
        }
    }

    my @out;
    for my $anode (@anodes) {
        push @out, [ $anode->form, @{ $refs{ $anode->id } || [] } ];
        if ( $anode->clause_number ) {
            my $clr = $self->_styles->_colors->get_clause_color( $anode->clause_number );
            push @{ $out[-1] }, "-foreground => $clr";
        }
        if ( !$anode->no_space_after ) {
            push @out, [ ' ', 'space' ];
        }
    }

    push @out, [ "\n", 'newline' ];
    return \@out;
}

sub precompute_value_line {
    my ( $self, $bundle ) = @_;

    my %alignment = ();

    foreach my $zone ( $bundle->get_all_zones() ) {
        foreach my $layer (@layers) {
            if ( $zone->has_tree($layer) ) {
                my $root = $zone->get_tree($layer);
                foreach my $node ( $root, $root->get_descendants ) {
                    if ( exists $node->{'alignment'} ) {
                        foreach my $ref ( @{ $node->get_attr('alignment') } ) {
                            next if !defined $ref || ! defined $ref->{'counterpart.rf'};
                            push @{ $alignment{ $node->{id} } }, $self->treex_doc->get_node_by_id( $ref->{'counterpart.rf'} );
                            push @{ $alignment{ $ref->{'counterpart.rf'} } }, $node;
                        }
                    }
                }
            }
        }
    }

    my @out = ();
    foreach my $zone ( $bundle->get_all_zones() ) {
        push @out, ( [ '[' . $zone->get_label . ']', 'label' ], [ ' ', 'space' ] );
        if ( my $sentence = $self->get_clickable_sentence_for_a_zone( $zone, \%alignment ) ) {
            push @out, @$sentence;
        }
        elsif ( defined $zone->sentence ) {
            push @out, [ $zone->sentence . "\n", 'text' ];
        }
        else {
            push @out, [ "\n", 'newline' ]
        }
    }

    $bundle->{_precomputed_value_line} = \@out;
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
        push @lines, "Full lemma: " . ( $node->{lemma} ? $node->{lemma} : '' );
        push @lines, "Full tag: " . ( $node->{tag} ? $node->{tag} : '' );
    }

    # List all non-empty Interset features.
    if ( $node->does('Treex::Core::Node::Interset') ) {
        my @iset = $node->get_iset_pairs_list();
        for ( my $i = 0; $i <= $#iset; $i += 2 ) {
            push @lines, "$iset[$i]: $iset[$i+1]";
        }
    }

    return join "\n", @lines;
}

sub tnode_hint {
    my ( $self, $node ) = @_;
    my @lines = ();

    if ( ref $node->get_attr('gram') ) {
        foreach my $gram ( keys %{ $node->get_attr('gram') } ) {
            push @lines, "gram/$gram : " . ( $node->get_attr( 'gram/' . $gram ) || '' );
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
    return;
}

sub pnode_hint {
    my ( $self, $node ) = @_;
    my @lines = ();

    if ( $node->is_terminal ) {
        push @lines, map { "$_: " . ( defined $node->{$_} ? $node->{$_} : '' ) } qw(lemma tag form);
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

    # P-layer indexes and coindexes
    if ( $node->get_layer eq 'p' ) {
        my $coindex;
        if ( $node->attr('form') and $node->attr('form') =~ m/-(\d+)$/ ) {
            $coindex = $1;
        }
        elsif ( $node->attr('coindex') ) {
            $coindex = $node->attr('coindex');
        }

        if ($coindex) {
            my $target_node;
            if ( exists $self->{'_ptb_index_map'}->{$coindex} ) {
                $target_node = $self->{'_ptb_index_map'}->{$coindex};
            }
            elsif ( $node->is_terminal and exists $self->{'_ptb_coindex_map'}->{$coindex} ) {
                $target_node = $self->{'_ptb_coindex_map'}->{$coindex};
            }

            if ($target_node) {
                push @target_ids,  $target_node->{'id'};
                push @arrow_types, 'coindex';
            }
        }
    }

    # alignment
    if ( $self->show_alignment and my $links = $node->attr('alignment') ) {
        foreach my $link (@$links) {
            push @target_ids, $link->{'counterpart.rf'};
            push @arrow_types, $link->{'type'};
        }
    }

    $self->_styles->draw_arrows( $node, $styles, \%line, \@target_ids, \@arrow_types, );

    # TODO: Would it be possible to move this code to the "_precomputed_node_style" attr?
    my %n = TredMacro::GetStyles( $styles, 'Node' );
    TredMacro::AddStyle( $styles, 'Node', -tag => ( $n{-tag} || '' ) . '#' . $node->{id} );

    my $xadj = $node->root->{'_shift_right'} * 50;
    if (ref($node)
        =~ m/^Treex::Core::Node/
        and $node->get_layer eq 'p'
        and not $node->is_root and scalar $node->parent->children == 1
        )
    {
        $xadj += 15;
    }
    TredMacro::AddStyle( $styles, 'Node', -xadj => $xadj ) if $xadj;

    return;
}

sub root_style_hook {
    my ( $self, $bundle, $styles ) = @_;

    # Sometimes TrEd calls this on e.g. t-nodes (after node_click_hook)
    return if !$bundle->isa('Treex::Core::Bundle');

    return if $bundle->{_precomputed};
    $self->precompute_tree_depths($bundle);
    $self->precompute_tree_shifts($bundle);
    $self->precompute_visualization($bundle);
    $bundle->{_precomputed} = 1;
    return;
}

# ---- END OF PRECOMPUTING VISUALIZATION ------

sub conf_dialog {
    my $self = shift;
    if ( $self->tree_layout->conf_dialog() ) {
        foreach my $bundle ( $self->treex_doc->get_bundles() ) {
            if ( !$self->fast_loading ) {
                $bundle->{_precomputed_root_style} = $self->_styles->bundle_style($bundle);
                $self->precompute_tree_shifts($bundle);
                $self->precompute_visualization($bundle);
                $bundle->{_precomputed} = 1;
            }
            else {
                $bundle->{_precomputed} = 0;
            }
        }
    }
    return;
}

sub _divide_clause_string {
    my ( $self, $anode ) = @_;
    if ( !$anode->clause_number ) {
        return [ $anode->form,, ];
    }
    my @forms = map { $_->form } $anode->get_clause_nodes;
    my $forms_per_line = int( @forms / 3 );
    return [
        ( join ' ', @forms[ 0 .. $forms_per_line ] ),
        ( join ' ', @forms[ $forms_per_line + 1 .. 2 * $forms_per_line ] ),
        ( join ' ', @forms[ 2 * $forms_per_line + 1 .. $#forms ] ),
    ];
}

sub toggle_clause_collapsing {
    my ( $self, $bundle ) = @_;
    $self->clause_collapsing( not $self->clause_collapsing );
    $bundle->{_is_collapsed} = $self->clause_collapsing;
    print "Toggle: " . $self->clause_collapsing . "\n";

    # fold clauses - display word from the clause instead of node labels

    foreach my $zone ( $bundle->get_all_zones ) {
        if ( $zone->has_tree('a') ) {
            my $aroot = $zone->get_atree;
            foreach my $anode ( $aroot->get_descendants ) {

                # fold clauses - display word from the clause instead of node labels
                if ( $self->clause_collapsing ) {
                    $anode->{_parent_backup}             = $anode->get_parent;
                    $anode->{_precomputed_labels_backup} = $anode->{_precomputed_labels};
                    $anode->{_precomputed_labels}        = $self->_divide_clause_string($anode);
                }

                # unfold clauses - return to full attribute labes
                else {
                    $anode->{_precomputed_labels} = $anode->{_precomputed_labels_backup};
                    $anode->set_parent( $anode->{_parent_backup} ) if $anode->{_parent_backup};
                }
            }
        }
    }
    return;
}

sub toggle_alignment {
    my $self = shift;
    $self->show_alignment( not $self->show_alignment );
    return;
}

sub toggle_tree_wrapping {
    my ( $self, $node ) = @_;
    my $signature = $self->_tree_type_signature($node);
    $self->tree_type_to_wrap->{$signature} = not $self->tree_type_to_wrap->{$signature};
    print "Toggle wrapping of trees of type: $signature\n";
    return;
}

sub _tree_type_signature {
    my ( $self, $node) = @_;
    my $zone = $node->get_root->get_zone;
    return join "-", ( ref($node), $zone->language, $zone->selector()||'');
}

use Treex::Core::TredView::AnnotationCommand;
sub run_annotation_command {
    my ( $self, $command, $node ) = @_;
    Treex::Core::TredView::AnnotationCommand::run( $command, $node );
    $self->recompute_visualization($node->get_bundle);
    return;
}



my $HIGHLIGHT_STYLE = '#{Line-decoration:shape=oval;coords=-20,-10,20,10;outline=#ff0000;width=3;dash=5,5 }';
my $HIGHLIGHT_TEXT = '-background => #ffbbaa';
my @highlighted = ();
sub node_click_hook {
    my ( $self, $node, $modifier, $xevent ) = @_;
    my $ali_id = eval {$node->wild->{ali_root}};
    if ($ali_id){
        # remove all highlighting
        foreach my $n (@highlighted){
            $n->{_precomputed_node_style} =~ s/\Q$HIGHLIGHT_STYLE\E//;
        }
        @highlighted = ();
        # add new highlighted nodes (a minimal treelet consistent with alignment)
        my $al_node = $self->treex_doc->get_node_by_id($ali_id);
        my @queue = ($node, $al_node);
        while (@queue){
            my $n = shift @queue;
            push @highlighted, $n;
            push @queue, grep {!$_->wild->{ali_root}} $n->get_children();
        }
        foreach my $n (@highlighted){
            $n->{_precomputed_node_style} .= $HIGHLIGHT_STYLE;
        }
        # highlight also the relevant words in the text window above trees
        my $bundle = $node->get_bundle();
        my %h; $h{$_}=1 for (@highlighted);
        foreach my $token (@{$bundle->{_precomputed_value_line}}){
            pop @$token if $token->[-1] eq $HIGHLIGHT_TEXT;
            push @$token, $HIGHLIGHT_TEXT if $h{$token->[1]};
        }
        TredMacro::Redraw();
    }
    return;
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
editing the treex files.

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

=item toggle_clause_collapsing

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Josef Toman <toman@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
