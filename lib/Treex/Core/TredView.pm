package Treex::Core::TredView;

# planned to be used from contrib.mac of tred's extensions

use Moose;
use Treex::Core::Log;

has 'grp'       => ( is => 'rw' );
has 'treex_doc' => ( is => 'rw' );
has 'pml_doc'   => ( is => 'rw' );

use List::Util qw(first);

sub get_nodelist_hook {
    my ( $self, $fsfile, $treeNo, $currentNode ) = @_;

    return if not $self->pml_doc(); # get_nodelist_hook is invoked also before file_opened_hook

    my $bundle = $fsfile->tree($treeNo);
    bless $bundle, 'Treex::Core::Bundle'; # TODO: how to make this automatically?
                                          # Otherwise (in certain circumstances) $bundle->get_all_zones
                                          # results in Can't locate object method "get_all_zones" via package "Treex::PML::Node" at /ha/work/people/popel/tectomt/treex/lib/Treex/Core/TredView.pm line 22

    my @nodes;

    my $layout = get_layout();

    foreach my $tree ( map { $_->get_all_trees } $bundle->get_all_zones ) {
        if ( $tree->does('Treex::Core::Node::Ordered') ) {
            push @nodes, $tree->get_descendants( { add_self => 1, ordered => 1 } );
        } else {
            push @nodes, $tree->get_descendants( { add_self => 1 } );
        }
    }

    unshift @nodes, $bundle;

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

sub precompute_visualization {
    my ($self) = @_;
    foreach my $bundle ( $self->treex_doc->get_bundles ) {

        $bundle->{_precomputed_root_style} = $self->bundle_root_style($bundle);
        $bundle->{_precomputed_labels}     = $self->bundle_root_labels($bundle);

        foreach my $zone ( $bundle->get_all_zones ) {

            foreach my $layer (@layers) {
                if ( $zone->has_tree($layer) ) {
                    my $root = $zone->get_tree($layer);
                    $root->{_precomputed_labels} = $self->tree_root_labels($root);
                    $root->{_precomputed_node_style} = $self->node_style( $root, $layer );

                    foreach my $node ( $root->get_descendants ) {
                        $node->{_precomputed_node_style} = $self->node_style( $node, $layer );
                        $node->{_precomputed_labels} = $self->nonroot_node_labels( $node, $layer );
                    }

                }
            }
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
    return [
        $root->get_layer . "-tree",
        "zone=" . $root->get_zone->get_label,
        ''
    ];
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

    #if    ( $layer eq 't' ) { return nonroot_tnode_labels(@_) }
    #elsif ( $layer eq 'a' ) { return nonroot_anode_labels(@_) }
    #elsif ( $layer eq 'n' ) { return nonroot_nnode_labels(@_) }
    #elsif ( $layer eq 'p' ) { return nonroot_pnode_labels(@_) }
    #else                    { log_fatal "Undefined or unknown layer: $layer" }

    return;
}

sub nonroot_anode_labels {
    my ( $self, $node ) = @_;
    return [
        $node->{form},
        $node->{lemma},
        $node->{tag},
    ];
}

sub nonroot_tnode_labels {
    my ( $self, $node ) = @_;
    return [
        $node->{t_lemma},
        $node->{functor},
        $node->{formeme},
    ];
}

sub nonroot_nnode_labels {
    my ( $self, $node ) = @_;
    return [
        $node->{normalized_name},
        $node->{ne_type},
    ];
}

sub nonroot_pnode_labels {
    my ( $self, $node ) = @_;
    return [
        $node->{form},
        $node->{lemma},
        $node->{tag},
    ];
}

# --- arrows ----

my %arrow_color = (
    'coref_gram.rf' => 'red',
    'coref_text.rf' => 'blue',
    'alignment'     => 'grey',
);

# copied from TectoMT_TredMacros.mak
sub node_style_hook {
    my ( $self, $node, $styles ) = @_;

    my %line = TredMacro::GetStyles( $styles, 'Line' );
    my @target_ids;
    my @arrow_types;

    foreach my $ref_attr ( 'coref_gram.rf', 'coref_text.rf', 'coref_compl.rf' ) {
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

    _DrawArrows( $node, $styles, \%line, \@target_ids, \@arrow_types, );
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
    my ( $node, $styles, $line, $target_ids, $arrow_types ) = @_;
    my ( @coords, @colors, @dash, @tags );
    my ( $rotate_prv_snt, $rotate_nxt_snt, $rotate_dfr_doc ) = ( 0, 0, 0 );

    my $document = $node->get_document;

    foreach my $target_id (@$target_ids) {
        my $arrow_type = shift @$arrow_types;

        my $target_node = $document->get_node_by_id($target_id);

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
                } else {        #right
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
    return "#{nodeXSkip:15} #{nodeYSkip:2} #{lineSpacing:0.7} #{BaseXPos:0} #{BaseYPos:10} #{BalanceTree:1} #{skipHiddenLevels:0}";
}

sub common_node_style {
    return q();
}

sub node_style {          # silly code just to avoid the need for eval
    my $layer = pop @_;
    my %subs;
    $subs{t} = \&tnode_style;
    $subs{a} = \&anode_style;
    $subs{n} = \&nnode_style;
    $subs{p} = \&pnode_style;
    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }(@_);
    } else {
        log_fatal "Undefined or unknown layer: $layer";
    }

    #if    ( $layer eq 't' ) { return tnode_style(@_) }
    #elsif ( $layer eq 'a' ) { return anode_style(@_) }
    #elsif ( $layer eq 'n' ) { return nnode_style(@_) }
    #elsif ( $layer eq 'p' ) { return pnode_style(@_) }
    #else                    { log_fatal "Undefined or unknown layer: $layer" }
    return;
}

sub anode_style {

    #    my ( $self, $node ) = @_; # style might be dependent on node features in the future
    return "#{Oval-fill:green}";
}

sub tnode_style {

    #    my ( $self, $node ) = @_; # style might be dependent on node features in the future
    return "#{Oval-fill:blue}";
}

sub nnode_style {

    #    my ( $self, $node ) = @_; # style might be dependent on node features in the future
    return "#{Oval-fill:yellow}";
}

sub pnode_style {

    #    my ( $self, $node ) = @_; # style might be dependent on node features in the future
    return "#{Oval-fill:magenta}";
}

# ---- END OF PRECOMPUTING VISUALIZATION ------

# ---- LAYOUT CONFIGURATION -------

my $layouts_loaded = 0;
my $layouts_saved = 0;
my %layouts = ();
my $tag_text = 'text';
my $tag_tree = 'tree';
my $tag_wrap = 'wrap';
my $tag_none = 'none';

sub get_layout_label {
    my $bundle = $TredMacro::root;
    return unless ref($bundle) eq 'Treex::Core::Bundle';

    my @label;
    foreach my $zone ( sort { $a->language cmp $b->language } $TredMacro::root->get_all_zones ) {
        my $lang = $zone->language;
        push @label, map { $lang.'-'.$_->get_layer() } sort { $a->get_layer cmp $b->get_layer } $zone->get_all_trees();
    }
    return join ',', @label;
}

sub get_layout {
    my $label = get_layout_label();
    if ( exists $layouts{$label} ) {
        return $layouts{$label};
    } else {
        my $cols = [];
        my @trees = split ',', $label;
        for ( my $i = 0; $i <= $#trees; $i++ ) {
            $cols->[$i]->[0] = $trees[$i];
        }

        $layouts{$label} = $cols;
        return $cols;
    }
}

sub load_layouts {
    return if $layouts_loaded;
    $layouts_loaded = 1;

    my $filename = TredMacro::FindMacroDir('treex').'/.layouts.cfg';
    open CFG, $filename or return;
    %layouts = ();

    while ( <CFG> ) {
        chomp;
        my ($label, $coords) = split '=';
        my @label = split ',', $label;
        my @coords = split ',', $coords;
        my $cols = [];

        for ( my $i = 0; $i <= $#label; $i++ ) {
            my ( $col, $row ) = split '-', $coords[$i];
            $cols->[$col]->[$row] = $label[$i];
        }

        $layouts{$label} = $cols;
    }

    close CFG;
}

sub save_layouts {
    return if $layouts_saved;

    my $filename = TredMacro::FindMacroDir('treex').'/.layouts.cfg';
    open CFG, ">$filename";

    while ( my ( $label, $cols ) = each %layouts ) {
        my %coords = ();
        for ( my $col = 0; $col < scalar( @$cols ); $col++ ) {
            for ( my $row = 0; $row < scalar( @{$cols->[$col]} ); $row++ ) {
                my $tree = $cols->[$col]->[$row];
                $coords{$tree} = "$col-$row" if $tree;
            }
        }

        my @coords = ();
        for my $tree ( split ',', $label ) {
            push @coords, $coords{$tree};
        }

        print CFG $label.'='.join(',', @coords)."\n";
    }

    close CFG;
    $layouts_saved = 1;
}

sub move_layout {
    my ($layout, $x, $y) = @_;
    my $new_layout = [];
    for ( my $i = 0; $i < $x; $i++ ) {
        $new_layout->[$i] = [];
    }
    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        for ( my $j = 0; $j < scalar @{$layout->[$i]}; $j++ ) {
            if ( $layout->[$i]->[$j] ) {
                if ( $i + $x < 0 or $j + $y < 0 ) {
                    print STDERR "Error: layout is moving out of bounds.\n";
                    return;
                }
                $new_layout->[$i+$x]->[$j+$y] = $layout->[$i]->[$j];
            }
        }
    }

    return $new_layout;
}

sub wrap_layout {
    my $layout = shift;
    my $new_layout = [];

    # 8 pairs of coords lying around the center point (0, 0)
    my @c = (
        -1, -1,
        0, -1,
        1, -1,
        -1,  0,
        1,  0,
        -1,  1,
        0,  1, 
        1,  1
    );

    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        for ( my $j = 0; $j < scalar @{$layout->[$i]}; $j++ ) {
            if ( $layout->[$i]->[$j] and $layout->[$i]->[$j] ne $tag_wrap ) {
                $new_layout->[$i]->[$j] = $layout->[$i]->[$j];
                for (my $k = 0; $k < scalar @c; $k += 2 ) {
                    my ($x, $y) = ($i + $c[$k], $j + $c[$k+1] );
                    $new_layout->[$x]->[$y] = $tag_wrap if $x >= 0 and $y >= 0 and not $new_layout->[$x]->[$y];
                }
            }
        }
    }

    return $new_layout;
}

sub normalize_layout {
    my $layout = shift;
    my %filled_cols = ();
    my %filled_rows = ();
    my $gap_x = 0;
    my $gap_y = 0;
    my $new_layout = [];

    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        for ( my $j = 0; $j < scalar@{$layout->[$i]}; $j++ ) {
            if ( $layout->[$i]->[$j] and $layout->[$i]->[$j] ne $tag_wrap ) {
                $filled_cols{$i} = 1;
                $filled_rows{$j} = 1;
            }
        }
    }

    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        $gap_y = 0;
        $gap_x++ if not exists $filled_cols{$i};
        for ( my $j = 0; $j < scalar@{$layout->[$i]}; $j++ ) {
            $gap_y++ if not exists $filled_rows{$j};
            if ( $layout->[$i]->[$j] and $layout->[$i]->[$j] ne $tag_wrap ) {
                $new_layout->[$i-$gap_x]->[$j-$gap_y] = $layout->[$i]->[$j];
            }
        }
    }

    return $new_layout;
}

use Tk::DialogBox;

sub conf_dialog {
    my $layout = get_layout();
    $layout = normalize_layout($layout);
    $layout = move_layout($layout, 1, 1);
    $layout = wrap_layout($layout);

    my $dialog = TredMacro::ToplevelFrame()->DialogBox( -title => "Trees layout configuration", -buttons => [ "OK", "Cancel" ] );
    my $m = 20;                 # canvas margin
    my $w = 80;                 # rectangle width
    my $h = 45;                 # rectangle height
    my $drag_tree = '';
    my $drag_x = '';
    my $drag_y = '';
    my $cur_tree = '';
    my $canvas = $dialog->add('Canvas', -width => 7 * $w + 8 * $m, -height => 5 * $h + 6 * $m );

    # Forward declaration
    my $draw_layout = sub {};

    my $get_layout_coords = sub {
        my ($x, $y) = @_;
        $x -= $m;
        $y -= $m;
        $x /= $w + $m;
        $y /= $h + $m;
        return ( $x, $y );
    };

    my $get_pos = sub {
        my ($x, $y) = @_;
        my $a = $x - $m;
        my $b = $y - $m;
        my ($i, $j);
        {
            use integer; $i = $a / ($w + $m); $j = $b / ($h + $m);
        }
        $a %= $w + $m;
        $b %= $h + $m;

        return if $a >= $w or $b >= $h;

        my $tree;
        if ( $i < 0 or $j < 0 ) {
            $tree = $tag_none;
        } elsif ( $layout->[$i]->[$j] ) {
            $tree = $layout->[$i]->[$j];
        } else {
            $tree = $tag_none;
        }
        return ( $i * ($w+$m) + $m, $j * ($h+$m) + $m, $tree );
    };

    my $mouse_move = sub {
        my $canvas = shift;
        my ( $x, $y, $tree ) = &$get_pos( $Tk::event->x, $Tk::event->y );
        $tree = '' if not defined $tree;

        if ( $cur_tree and $tree ne $cur_tree ) {
            if ( $cur_tree ne $tag_wrap and $cur_tree ne $tag_none ) {
                $canvas->itemconfigure( "$cur_tree&&$tag_tree", -outline => 'black', -width => 1 );
            } else {
                $canvas->delete( $cur_tree );
            }
            $cur_tree = '';
        }
        if ( $tree and $tree ne $cur_tree ) {
            if ( $tree ne $tag_wrap and $tree ne $tag_none ) {
                my $color = $drag_tree ? ( $tree eq $drag_tree ? 'red' : 'green' ) : 'blue';
                $canvas->itemconfigure( "$tree&&$tag_tree", -outline => $color, -width => 2 );
            } elsif ( $drag_tree ) {
                my $color = $tree eq $tag_wrap ? 'green' : 'red';
                $canvas->create( 'rectangle', $x, $y, $x + $w, $y + $h, -tags => [ $tree ], -outline => $color, -width => 2 );
            }
            $cur_tree = $tree;
        }
    };

    my $mouse_drag = sub {
        my $canvas = shift;
        my ( $x, $y, $tree ) = &$get_pos( $Tk::event->x, $Tk::event->y );
        return if ( not $tree ) or $tree eq $tag_wrap or $tree eq $tag_none;

        $drag_tree = $tree;
        ( $drag_x, $drag_y ) = &$get_layout_coords( $x, $y );
        $canvas->itemconfigure( "$tree&&$tag_tree", -outline => 'red', -width => 2, -fill => 'yellow' );
    };

    my $mouse_drop = sub {
        return unless $drag_tree;

        my $canvas = shift;
        my ( $x, $y, $tree ) = &$get_pos( $Tk::event->x, $Tk::event->y );

        $canvas->itemconfigure( "$drag_tree&&$tag_tree", -fill => 'white' );

        if ( (not $tree) or $tree eq $tag_none ) {
            $canvas->delete( $tag_none ) if $tree;
            $drag_tree = $drag_x = $drag_y = '';
            return;
        }

        $layout->[$drag_x]->[$drag_y] = undef;
        ( $x, $y ) = &$get_layout_coords( $x, $y );
        if ( $tree ne $tag_wrap ) {
            for ( my $i = scalar @$layout; $i > $x; $i-- ) {
                if ( $layout->[$i-1]->[$y] ) {
                    $layout->[$i]->[$y] = $layout->[$i-1]->[$y];
                    $layout->[$i-1]->[$y] = undef;
                }
            }
        }
        $layout->[$x]->[$y] = $drag_tree;

        $layout = normalize_layout( $layout );
        $layout = move_layout( $layout, 1, 1 );
        $layout = wrap_layout( $layout );
        &$draw_layout();

        $drag_tree = $drag_x = $drag_y = '';
    };

    $draw_layout = sub {
        $canvas->delete( 'all' );
  	for ( my $i = 0; $i < scalar @$layout; $i++ ) {
            for ( my $j = 0; $j < scalar @{$layout->[$i]}; $j++ ) {
                my $tree = $layout->[$i]->[$j];
                if ($tree and $tree ne $tag_wrap) {
                    my ($lang, $layer) = split '-', $tree;
                    $lang = Treex::Core::Common::get_lang_name($lang);
                    $canvas->create(
                        'rectangle',
                        $i * ($w+$m) + $m,
                        $j * ($h+$m) + $m,
                        ($i+1) * ($w+$m),
                        ($j+1) * ($h+$m),
                        -tags => [ $tag_tree, $tree ],
                        -fill => 'white'
                    );
                    $canvas->create(
                        $tag_text,
                        ($i+1) * ($w+$m) - 0.5 * $w,
                        ($j+1) * ($h+$m) - 0.5 * $h,
                        -anchor => 'center',
                        -justify => 'center',
                        -tags => [ $tree ],
                        -text => "$lang\n".uc($layer)
                    );
                }
            }
  	}

  	$canvas->CanvasBind( '<Motion>' => $mouse_move );
  	$canvas->CanvasBind( '<ButtonPress-1>' => $mouse_drag );
  	$canvas->CanvasBind( '<ButtonRelease-1>' => $mouse_drop );
    };

    &$draw_layout( $canvas, $layout );
    $canvas->pack(-expand => 1, -fill => 'both');

    my $button = $dialog->Show();
    if ( $button eq 'OK' ) {
        $layouts{ get_layout_label() } = normalize_layout( $layout );
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
is very thin. It only creates an instance of Treex::Core::TredView
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

Building Treex::Core::Document structure on the top of
Treex::PML::Document structure which was provided by TrEd.

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

=item common_node_style

=item node_style

=item nnode_style

=item anode_style

=item tnode_style

=item pnode_style

=back

=head2 Methods for configuring layout of the trees

=over 4

=item get_layout_label

=item get_layout

=item move_layout

=item wrap_layout

=item normalize_layout

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
