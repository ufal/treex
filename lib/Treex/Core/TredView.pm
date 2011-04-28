package Treex::Core::TredView;

# planned to be used from contrib.mac of tred's extensions

use Moose;
use Treex::Core::Log;
use Treex::Core::TredView::TreeLayout;

has 'grp'       => ( is => 'rw' );
has 'pml_doc'   => ( is => 'rw' );
has 'treex_doc' => ( is => 'rw' );
has 'tree_layout' => (
    is => 'ro',
    isa => 'Treex::Core::TredView::TreeLayout',
    default => sub { Treex::Core::TredView::TreeLayout->new() }
);
has '_label_variants' => (
    is => 'rw',
    isa => 'HashRef[ArrayRef[Int]]',
    builder => '_build_label_variants'
);

use List::Util qw(first);

sub _build_label_variants {
    return {
        'p' => [ 0, 0, 0 ],
        'a' => [ 0, 0, 0 ],
        't' => [ 0, 0, 0 ]
    }
}

sub _get_label_variant {
    my ( $self ) = shift;
    my ( $obj, $line ) = @_;

    if (ref $obj and not exists $obj->{_label_variants}) {
        $obj = $obj->get_layer;
    }
    
    if (ref $obj) {
        # $obj is a single node
        return $obj->{_label_variants}->[ $line ];
    } else {
        # $obj is the name of a layer
        return $self->_label_variants->{ $obj }->[ $line ];
    }
}

# $obj is a node => rotating label variant of the single given node
# $obj is the name of a layer => rotating label variant of all nodes on the given layer
sub _rotate_label_variant {
    my ( $self ) = shift;
    my ( $obj, $line ) = @_;
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
        $self->_label_variants->{ $layer }->[ $line ] = $new
    }

    return 1;
}

sub _spread_nodes {
    my ( $self, $node ) = @_;

    my ( $left, $right, $gap, $pos ) = ( -1, 0, 0, 0 );
    my ( @buf, @lower );
    for my $child ( $node->children ) {
        ( $pos, @buf ) = $self->_spread_nodes( $child );
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
    if ( scalar($node->children) == 1 ) {
        $mid = int ( ($#lower + 1) / 2 - 1 );
    } else {
        $mid = int ( ($left + $right) / 2 );
    }

    return ($mid + 1), @lower[0..$mid], $node, @lower[($mid+1)..$#lower];
}

sub get_nodelist_hook {
    my ( $self, $fsfile, $treeNo, $currentNode ) = @_;

    return if not $self->pml_doc(); # get_nodelist_hook is invoked also before file_opened_hook

    my $bundle = $fsfile->tree($treeNo);
    bless $bundle, 'Treex::Core::Bundle'; # TODO: how to make this automatically?
                                          # Otherwise (in certain circumstances) $bundle->get_all_zones
                                          # results in Can't locate object method "get_all_zones" via package "Treex::PML::Node" at /ha/work/people/popel/tectomt/treex/lib/Treex/Core/TredView.pm line 22

    my $layout = $self->tree_layout->get_layout();
    my %nodes;
        
    foreach my $tree ( map { $_->get_all_trees } $bundle->get_all_zones ) {
        my $label = $self->tree_layout->get_tree_label($tree);
        my @nodes;
        if ( $tree->get_layer eq 'p' ) {
            (my $foo, @nodes) = $self->_spread_nodes( $tree );
        } elsif ( $tree->does('Treex::Core::Node::Ordered') ) {
            @nodes = $tree->get_descendants( { add_self => 1, ordered => 1 } );
        } else {
            @nodes = $tree->get_descendants( { add_self => 1 } );
        }
        $nodes{$label} = \@nodes;
    }

    my $pick_next_tree = sub {
        my @task = @_;
        my $max = 0;
        my $max_index = -1;

        for ( my $i = 0; $i < scalar @task; $i++ ) {
            my $val = $task[$i]->{'left'} / $task[$i]->{'total'};
            if ( $val > $max ) {
                $max = $val;
                $max_index = $i;
            }
        }

        return $max_index;
    };
        
    my @nodes = ( $bundle );
        
    for ( my $col = 0; $col < scalar @$layout; $col++ ) {
        my @task = ();
        for ( my $row = 0; $row < scalar @{$layout->[$col]}; $row++ ) {
            if ( $layout->[$col]->[$row] ) {
                my $label = $layout->[$col]->[$row];
                my %tree_info = ();
                $tree_info{'total'} = $tree_info{'left'} = scalar @{$nodes{$label}};
                $tree_info{'label'} = $label;
                push @task, \%tree_info;
            }
        }

        while ( ( my $index = &$pick_next_tree( @task ) ) >= 0 ) {
            push @nodes, shift @{$nodes{$task[$index]->{'label'}}};
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
    my ( $self, undef, $treeNo ) = @_; # the unused argument stands for $fsfile
    return if not $self->pml_doc();

    my $bundle = $self->pml_doc->tree($treeNo);
    return join "\n", map { "[" . $_->get_label . "] " . $_->get_attr('sentence') } grep { defined $_->get_attr('sentence') } $bundle->get_all_zones;
}

# --------------- PRECOMPUTING VISUALIZATION (node labels, styles, coreference links, groups...) ---

my @layers = qw(a t p n);
my %tree_depths = ();
my %tree_shifts = ();

# To be run only once when the file is opened. Tree depths never change.
sub precompute_tree_depths {
    my ($self) = @_;
    foreach my $bundle ( $self->treex_doc->get_bundles ) {
        foreach my $zone ( $bundle->get_all_zones ) {
            foreach my $tree ( $zone->get_all_trees ) {
                my $max_depth = 1;
                my @front = ( 1, $tree );

                while ( @front ) {
                    my $cur_depth = shift @front;
                    my $node = shift @front;
                    $max_depth = $cur_depth if $cur_depth > $max_depth;
                    for my $child ( $node->get_children ) {
                        push @front, $cur_depth + 1, $child;
                        $child->{_depth} = $cur_depth + 1 if $child->get_layer eq 'p';
                    }
                }

                $tree_depths{$tree->get_attr('id')} = $max_depth;
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
                $forest{ $self->tree_layout->get_tree_label( $tree ) } = $tree->get_attr('id');
            }
        }

        my @trees = ( 'foo' );
        my $row = 0;
        my $cur_shift = 0;
        while ( @trees ) {
            my $max_depth = 0;
            @trees = ();
            for ( my $col = 0; $col < scalar @$layout; $col++ ) {
                if ( my $label = $layout->[$col]->[$row] ) {
                    my $depth = $tree_depths{ $forest{$label} };
                    push @trees, $label;
                    $max_depth = $depth if $depth > $max_depth; 
                    $tree_shifts{ $forest{$label} }{'right'} = $col;
                }
            }

            for my $label ( @trees ) {
                $tree_shifts{ $forest{$label} }{'down'} = $cur_shift;
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

        $bundle->{_precomputed_root_style} = $self->bundle_root_style($bundle);
        $bundle->{_precomputed_labels}     = $self->bundle_root_labels($bundle);
        $bundle->{_precomputed_node_style} = '#{Node-hide:1}';

        foreach my $zone ( $bundle->get_all_zones ) {

            foreach my $layer (@layers) {
                if ( $zone->has_tree($layer) ) {
                    my $root = $zone->get_tree($layer);

                    $root->{_precomputed_labels} = $self->tree_root_labels($root);
                    $root->{_precomputed_node_style} = $self->node_style( $root );
                    $root->{_precomputed_hint} = '';

                    foreach my $node ( $root->get_descendants ) {
                        $node->{_precomputed_node_style} = $self->node_style( $node );
                        $node->{_precomputed_hint} = $self->node_hint( $node, $layer );
                        $node->{_precomputed_buffer} = $self->nonroot_node_labels( $node, $layer );
                        $self->_set_labels($node);

                        if (not defined $limits{$layer}) {
                            for (my $i = 0; $i < 3; $i++) {
                                $limits{$layer}->[$i] = scalar(@{$node->{_precomputed_buffer}->[$i]}) - 1;
                            }
                        }
                    }
                }
            }
        }
    }

    for my $layer ('p', 'a', 't') {
        for (my $i = 0; $i < 3; $i++) {
            $self->_label_variants->{$layer.'_limit'}->[$i] = $limits{$layer}->[$i];
        }
    }

    return;
}

# ---- info displayed below nodes (should return a reference to a three-element array) ---

sub bundle_root_labels {
    my ( $self, $bundle ) = @_;
    return [
        'bundle',
        'id=' . $bundle->get_id(),
        ''
    ];
}

sub tree_root_labels {
    my ( $self, $root ) = @_;

    if ($root->get_layer eq 'p') {
        my $buf = $self->nonroot_pnode_labels($root);
        return [ $buf->[0]->[0], $buf->[1]->[0], $buf->[2]->[0] ];
    } else {
        return [
            $root->get_layer . "-tree",
            "zone=" . $root->get_zone->get_label,
            ''
        ];
    }
}

sub nonroot_node_labels { # silly code just to avoid the need for eval
    my $layer = pop @_;
    my %subs;
    $subs{t} = \&nonroot_tnode_labels;
    $subs{a} = \&nonroot_anode_labels;
    $subs{n} = \&nonroot_nnode_labels;
    $subs{p} = \&nonroot_pnode_labels;
    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }(@_);
    } else {
        log_fatal "Undefined or unknown layer: $layer";
    }

    return;
}

sub nonroot_anode_labels {
    my ( $self, $node ) = @_;

    my $line1 = '';
    my $par = 0;
    my $n = $node;
    while ( (not $par) and $n ) {
        $par = 1 if $n->{is_parenthesis_root};
        $n = $n->parent;
    }
    $line1 = '#{customparenthesis}' if $par;
    $line1 .= $node->{form};

    my $line2 = $node->{afun} ? '#{customafun}'.$node->{afun} : '#{customerror}!!';
    if ($node->{is_member}) {
        my $n = $node->parent;
        $n = $n->parent while $n and $n->{afun} =~ m/^Aux[CP]$/;
        if ($n->{afun} =~ m/^(Ap)os|(Co)ord/) {
            $line2 .= '_#{customcoappa}'.($1 ? $1 : $2);
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

sub nonroot_tnode_labels {
    my ( $self, $node ) = @_;

    my $line1 = $node->{t_lemma};
    $line1 = '#{customparenthesis}' . $line1 if $node->{is_parenthesis};
    $line1 .= '#{customdetail}.'.$node->{sentmod} if $node->{sentmod};
    
    my %colors = (
        'compl' => 'green',
        'coref_text' => 'blue',
        'coref_gram' => 'red'
    );

    foreach my $type ('compl', 'coref_text', 'coref_gram') {
        if (defined $node->{$type.'.rf'}) {
            foreach my $ref (TredMacro::ListV($node->{$type.'.rf'})) {
                my $ref_node = $self->treex_doc->get_node_by_id( $ref );
                if ( $node->get_bundle->get_position() != $ref_node->get_bundle->get_position() ) {
                    $line1 .= ' #{'.$colors{$type}.'}'.$ref_node->{t_lemma};
                }
            }
        }
    }

    my $line2 = $node->{functor};
    $line2 .= '#{customsubfunc}.'.$node->{subfunctor} if $node->{subfunctor};
    $line2 .= '#{customsubfunc}.state' if $node->{is_state};
    $line2 .= '#{customsubfunc}.dsp_root' if $node->{is_dsp_root};
    $line2 .= '#{customcoappa}.member' if $node->{is_member};

    my @a_nodes = ();
    my $line3_1 = '';
    if (defined $node->attr('a/aux.rf')) {
        @a_nodes = TredMacro::ListV($node->attr('a/aux.rf'));
        @a_nodes = map { $self->treex_doc->get_node_by_id($_) } @a_nodes;
        @a_nodes = map { { form => $_->{form}, ord => $_->{ord}, type => 'aux' } } @a_nodes;
    }
    if (defined $node->attr('a/lex.rf')) {
        my $a_node = $self->treex_doc->get_node_by_id($node->attr('a/lex.rf'));
        push @a_nodes, { form => $a_node->{form}, ord => $a_node->{ord}, type => 'lex' };
    }
    if (@a_nodes) {
        @a_nodes = sort { $a->{ord} <=> $b->{ord} } @a_nodes;
        @a_nodes = map { ($_->{type} eq 'lex' ? '#{darkgreen}' : '#{darkorange}').$_->{form} } @a_nodes;
        $line3_1 = join " ", @a_nodes;
    }

    my $line3_2 = '#{customnodetype}'.$node->{nodetype};
    $line3_2 .= '#{customcomplex}.'.$node->attr('gram/sempos') if $node->attr('gram/sempos');
    
    return [
        [ $line1 ],
        [ $line2 ],
        [ $line3_1, $line3_2 ]
    ];
}

sub nonroot_nnode_labels {
    my ( $self, $node ) = @_;
    return [
        [ $node->{normalized_name} ],
        [ $node->{ne_type} ],
        []
    ];
}

sub nonroot_pnode_labels {
    my ( $self, $node ) = @_;

    my $terminal = $node->get_pml_type_name eq 'p-terminal.type' ? 1 : 0;
    
    my $line1 = '';
    my $line2 = '';
    if ($terminal) {
        $line1 = $node->{form};
        $line2 = $node->{tag};
        $line2 = '-' if $line2 eq '-NONE-';
    } else {
        $line1 = '#{darkblue}'.$node->{phrase}.'#{black}'.join('', map "-$_", TredMacro::ListV($node->{functions}));
    }

    return [
        [ $line1 ],
        [ $line2 ],
        [ '' ]
    ];
}

sub _identify_and_bless_node {
    my ($self) = shift;
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

sub _set_labels {
    my ($self, $node) = @_;
    
    my $buf = $node->{_precomputed_buffer};
    for (my $i = 0; $i < 3; $i++) {
        $node->{_precomputed_labels}->[$i] = $buf->[$i]->[ $self->_get_label_variant($node, $i) ];
    }
}

sub shift_label {
    my ($self, $line, $mode) = @_;
    my $node = $self->_identify_and_bless_node;
    return if $node->is_root;
    
    my $layer = $node->get_layer;
    my @nodes;
    if ($mode eq 'node') {
        return unless $self->_rotate_label_variant($node, $line);
        @nodes = ( $node );
    } else {
        return unless $self->_rotate_label_variant($layer, $line);
        foreach my $bundle ( $self->treex_doc->get_bundles ) {
            foreach my $zone ( $bundle->get_all_zones ) {
                if ( $zone->has_tree($layer) ) {
                    push @nodes, $zone->get_tree($layer)->get_descendants;
                }
            }
        }
        @nodes = grep { not exists $_->{_label_variants} } @nodes;
    }

    for my $node (@nodes) {
        $self->_set_labels($node);
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
        $self->_set_labels($node);
    }
}

# ---- info displayed when mouse stops over a node - "hint" (should return a string, that may contain newlines) ---

sub node_hint { # silly code just to avoid the need for eval
    my $layer = pop @_;
    my %subs;
    $subs{t} = \&tnode_hint;
    $subs{a} = \&anode_hint;
    $subs{n} = \&nnode_hint;
    $subs{p} = \&pnode_hint;
    
    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }(@_);
    } else {
        log_fatal "Undefined or unknown layer: $layer";
    }

    return;
}

sub anode_hint {
    my ( $self, $node ) = @_;
    my @lines = ();

    push @lines, "Parenthesis root" if $node->{is_parenthesis_root};
    if ($node->language eq 'cs') {
        push @lines, "Full lemma: ".$node->{lemma};
        push @lines, "Full tag: ".$node->{tag};
    }

    return join "\n", @lines;
}

sub tnode_hint {
    my ( $self, $node ) = @_;
    my @lines = ();

    if ( ref $node->get_attr( 'gram' ) ) {
        foreach my $gram ( keys %{$node->get_attr( 'gram' )} ) {
            push @lines, "gram/$gram : " . $node->get_attr( 'gram/'.$gram );
        }
    }
    
    push @lines, "Direct speech root" if $node->get_attr( 'is_dsp_root' );
    push @lines, "Parenthesis" if $node->get_attr( 'is_parenthesis' );
    push @lines, "Name of person" if $node->get_attr( 'is_name_of_person' );
    push @lines, "Name" if $node->get_attr( 'is_name' );
    push @lines, "State" if $node->get_attr( 'is_state' );
    push @lines, "Quotation : " . join ", ", map { $_->{type} } TredMacro::ListV( $node->get_attr( 'quot' ) ) if $node->get_attr( 'quot' );

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
        push @lines, "lemma: ".$node->{lemma};
        push @lines, "tag: ".$node->{tag};
        push @lines, "form: ".$node->{form};
    } else {
        push @lines, "phrase: ".$node->{phrase};
        push @lines, "functions: ".join(', ', TredMacro::ListV($node->{functions}));
    }
    
    return join "\n", @lines;
}

# --- arrows ----

my %arrow_color = (
    'coref_gram.rf' => 'red',
    'coref_text.rf' => 'blue',
    'compl.rf'      => 'green',
    'alignment'     => 'grey',
);

# copied from TectoMT_TredMacros.mak
sub node_style_hook {
    my ( $self, $node, $styles ) = @_;

    return if ref($node) eq 'Treex::Core::Bundle';
    
    my %line = TredMacro::GetStyles( $styles, 'Line' );
    my @target_ids;
    my @arrow_types;

    foreach my $ref_attr ( 'coref_gram.rf', 'coref_text.rf', 'compl.rf' ) {
        if ( defined $node->attr($ref_attr) ) {
            foreach my $target_id ( @{ $node->attr($ref_attr) } ) {
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

    $self->_DrawArrows( $node, $styles, \%line, \@target_ids, \@arrow_types, );
    
    my %n = TredMacro::GetStyles( $styles, 'Node' );
    TredMacro::AddStyle( $styles, 'Node', -tag => ( $n{-tag} || '' ) . '&' . $node->{id} );
    
    my $xadj = $tree_shifts{$node->root->{id}}{'right'} * 50;
    if ( ref($node) =~ m/^Treex::Core::Node/ and $node->get_layer eq 'p'
         and not $node->is_root and scalar $node->parent->children == 1 ) {
        $xadj += 15;
    }
    TredMacro::AddStyle( $styles, 'Node', -xadj => $xadj ) if $xadj;

    return;
}

# copied from tred.def
sub _AddStyle {
    my ( $styles, $style, %s ) = @_;
    if ( exists( $styles->{$style} ) ) {
        for my $key ( keys %s ) {
            $styles->{$style}{$key} = $s{$key};
        }
    } else {
        $styles->{$style} = \%s;
    }
    return;
}

# based on DrawCorefArrows from config/TectoMT_TredMacros.mak, simplified
# ignoring special values ex and segm
sub _DrawArrows {
    my ( $self, $node, $styles, $line, $target_ids, $arrow_types ) = @_;
    my ( @coords, @colors, @dash, @tags );
    my ( $rotate_prv_snt, $rotate_nxt_snt, $rotate_dfr_doc ) = ( 0, 0, 0 );

    foreach my $target_id (@$target_ids) {
        my $arrow_type = shift @$arrow_types;

        my $target_node = $self->treex_doc->get_node_by_id($target_id);

        if ( $node->get_bundle eq $target_node->get_bundle ) { # same sentence

            my $T = "[?\$node->{id} eq '$target_id'?]";
            my $X = "(x$T-xn)";
            my $Y = "(y$T-yn)";
            my $D = "sqrt($X**2+$Y**2)";
            my $c = <<"COORDS";
&n,n,
(x$T+xn)/2 - $Y*(25/$D+0.12),
(y$T+yn)/2 + $X*(25/$D+0.12),
x$T,y$T

COORDS

            push @coords, $c;
        } else { # should be always the same document, if it exists at all

            my $orientation = $target_node->get_bundle->get_position - $node->get_bundle->get_position - 1;
            $orientation = $orientation > 0 ? 'right' : ( $orientation < 0 ? 'left' : 0 );
            if ( $orientation =~ /left|right/ ) {
                if ( $orientation eq 'left' ) {
                    log_info "ref-arrows: Preceding sentence\n" if $main::macroDebug;
                    push @coords, "\&n,n,n-30,n+$rotate_prv_snt";
                    $rotate_prv_snt += 10;
                } else { #right
                    log_info "ref-arrows: Following sentence\n" if $main::macroDebug;
                    push @coords, "\&n,n,n+30,n+$rotate_nxt_snt";
                    $rotate_nxt_snt += 10;
                }
            } else {
                log_info "ref-arrows: Not found!\n" if $main::macroDebug;
                push @coords, "&n,n,n+$rotate_dfr_doc,n-25";
                $rotate_dfr_doc += 10;
            }
        }

        push @tags, $arrow_type;
        push @colors, ( $arrow_color{$arrow_type} || log_fatal "Unknown color for arrow type $arrow_type" );
        push @dash, '5,3';
    }

    $line->{-coords} ||= 'n,n,p,p';

    if (@coords) {
        _AddStyle(
            $styles, 'Line',
            -coords => ( $line->{-coords} || '' ) . join( "", @coords ),
            -arrow      => ( $line->{-arrow}      || '' ) . ( '&last' x @coords ),
            -arrowshape => ( $line->{-arrowshape} || '' ) . ( '&16,18,3' x @coords ),
            -dash => ( $line->{-dash} || '' ) . join( '&', '', @dash ),
            -width => ( $line->{-width} || '' ) . ( '&1' x @coords ),
            -fill => ( $line->{-fill} || '' ) . join( "&", "", @colors ),
            -tag  => ( $line->{-tag}  || '' ) . join( "&", "", @tags ),
            -smooth => ( $line->{-smooth} || '' ) . ( '&1' x @coords )
        );
    }
    return;
}

# --- node styling: color, size, shape... of nodes and edges

sub bundle_root_style {
    my $style = '#{nodeXSkip:10}#{nodeYSkip:5}#{lineSpacing:0.9}#{balance:0}';
    $style .= '#{Node-width:7}#{Node-height:7}#{Node-currentwidth:9}#{Node-currentheight:9}';
    $style .= '#{CurrentOval-width:3}#{CurrentOval-outline:'.TredMacro::CustomColor('current').'}';

    return $style;
}

sub node_style { # silly code just to avoid the need for eval
    my ( $self, $node ) = @_;
    my $styles = '';

    if ( $node->is_root() ) {
        $styles .= '#{Node-rellevel:'.$tree_shifts{ $node->get_attr('id') }{'down'}.'}';
    }

    my $layer = $node->get_layer;
    my %subs;
    $subs{t} = \&tnode_style;
    $subs{a} = \&anode_style;
    $subs{n} = \&nnode_style;
    $subs{p} = \&pnode_style;

    if ( defined $subs{$layer} ) {
        return $styles.&{ $subs{$layer} }($self, $node);
    } else {
        log_fatal "Undefined or unknown layer: $layer";
    }

    return;
}

sub anode_style {
    # my ( $self, $node ) = @_;
    return "#{Oval-fill:#f66}";
}

sub tnode_style {
    my ( $self, $node ) = @_;

    my $is_coord = sub { my $n = shift; return $n->{functor} =~ /ADVS|APPS|CONFR|CONJ|CONTRA|CSQ|DISJ|GRAD|OPER|REAS/ };
    
    my $style = '#{Oval-fill:#48f}';
    return $style if $node->is_root;
    
    $style .= '#{Node-shape:'.( $node->{is_generated} ? 'rectangle' : 'oval' ).'}';
    
    my $coord_circle = '#{Line-decoration:shape=oval;coords=-20,-20,20,20;outline=#ddd;width=2;dash=_ }';
    # For coordination roots
    my $k1 = '20 / sqrt((xp-xn)**2 + (yp-yn)**2)';
    my $x1 = 'xn-(xn-xp)*'.$k1;
    my $y1 = 'yn-(yn-yp)*'.$k1;
    # For coordination members
    my $k2 = '(1 - 20 / sqrt((xp-xn)**2 + (yp-yn)**2))';
    my $x2 = 'xn-(xn-xp)*'.$k2;
    my $y2 = 'yn-(yn-yp)*'.$k2;
    
    if (($node->{functor} =~ m/^(?:PAR|PARTL|VOCAT|RHEM|CM|FPHR|PREC)$/) or
        (not $node->is_root and $node->parent->is_root)) {
        $style .= '#{Line-width:1}#{Line-dash:2,4}';
    } elsif ($node->{is_member}) {
        if ($is_coord->($node) and $is_coord->($node->parent)) {
            $style .= "#{Line-coords:n,n,n,n&$x1,$y1,$x2,$y2}".$coord_circle;
            $style .= '#{Line-width:0&1}#{Line-fill:white&#6f11ea}';
        } elsif (not $node->is_root and $is_coord->($node->parent)) {
            $style .= "#{Line-coords:n,n,$x2,$y2}";
        } else {
            $style .= '#{Line-fill:'.TredMacro::CustomColor('error').'}';
        }
    } elsif (not $node->is_root and $is_coord->($node->parent)) {
        $style .= "#{Line-coords:n,n,$x2,$y2}#{Line-fill:#6f11ea}#{Line-width:1}";
    } elsif ($is_coord->($node)) {
        $style .= $coord_circle."#{Line-coords:n,n,n,n&$x1,$y1,p,p}";
        $style .= '#{Line-width:0&2}#{Line-fill:white&#bebebe}';
    } else {
        $style .= '';
    }

    return $style;
}

sub nnode_style {

    #    my ( $self, $node ) = @_; # style might be dependent on node features in the future
    return "#{Oval-fill:yellow}";
}

sub pnode_style {
    my ( $self, $node ) = @_;
    
    my $terminal = $node->get_pml_type_name eq 'p-terminal.type' ? 1 : 0;
    
    my $style = '#{Line-coords:n,n,n,p,p,p}';
    $style .= '#{CurrentTextBox-fill:red}#{nodeXSkip:4}#{nodeYSkip:0}';
    $style .= '#{NodeLabel-halign:center}#{Node-textalign:center}#{NodeLabel-skipempty:1}';

    if ($terminal) {
        my $shift = $tree_depths{$node->root->{id}} - $node->{_depth};
        $style .= "#{Node-rellevel:$shift}";
    }

    if (not $node->is_root and scalar($node->parent->children) == 1) {
        $style .= '#{Node-addafterskip:15}';
    }
    
    if (not $terminal) {
        $style .= '#{Oval-fill:'.($node->{is_head} ? 'lightgreen' : 'lightyellow').'}';
        $style .= '#{Node-shape:rectangle}#{CurrentOval-outline:red}';
        $style .= '#{CurrentOval-width:2}#{Node-surroundtext:1}#{NodeLabel-valign:center}';
    } else {
        $style .= '#{CurrentOval-fill:red}#{Line-dash:.}';
        $style .= '#{Oval-fill:'.($node->{tag} eq '-NONE-' ? 'gray' : '#ff6').'}';
    }
    
    if ($node->is_root and 0) {
        my $c = $self->grp->{treeView}->{canvas};
        my @foo = $c->find('withtag', 'node');
        print STDERR "DEBUG-INFO: ".$node->{id}." - ".scalar(@foo)."\n";
    }
    
    return $style;
}

# ---- END OF PRECOMPUTING VISUALIZATION ------

sub conf_dialog {
    my $self = shift;
    if ($self->tree_layout->conf_dialog()) {
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

=item node_style_hook

=item load_layouts

=item save_layouts

=item conf_dialog

=back

=head2 Methods for displaying attributes below nodes

=over 4

=item bundle_root_labels

=item tree_root_labels

=item nonroot_node_labels

=item nonroot_anode_labels

=item nonroot_nnode_labels

=item nonroot_pnode_labels

=item nonroot_tnode_labels

=back

=head2 Methods for defining node's style

=over 4

=item bundle_root_style

=item node_style

=item nnode_style

=item anode_style

=item tnode_style

=item pnode_style

=back

=head2 Methods for configuring layout of the trees

=over 4

=item get_tree_label

=item get_layout_label

=item get_layout

=item move_layout

=item wrap_layout

=item normalize_layout

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

