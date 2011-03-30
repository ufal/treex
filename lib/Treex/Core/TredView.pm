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

    return if not $self->pml_doc();    # get_nodelist_hook is invoked also before file_opened_hook

    my $bundle = $fsfile->tree($treeNo);
    bless $bundle, 'Treex::Core::Bundle';    # TODO: how to make this automatically?
                                             # Otherwise (in certain circumstances) $bundle->get_all_zones
                                             # results in Can't locate object method "get_all_zones" via package "Treex::PML::Node" at /ha/work/people/popel/tectomt/treex/lib/Treex/Core/TredView.pm line 22

    my @nodes;

    foreach my $tree ( map { $_->get_all_trees } $bundle->get_all_zones ) {
        if ( $tree->does('Treex::Core::Node::Ordered') ) {
            push @nodes, $tree->get_descendants( { add_self => 1, ordered => 1 } );
        }
        else {
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
    my ( $self, undef, $treeNo ) = @_;    # the unused argument stands for $fsfile
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

sub nonroot_node_labels {    # silly code just to avoid the need for eval
    my $layer = pop @_;
    my %subs;
    $subs{t} = \&nonroot_tnode_labels;
    $subs{a} = \&nonroot_anode_labels;
    $subs{n} = \&nonroot_nnode_labels;
    $subs{p} = \&nonroot_pnode_labels;
    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }(@_);
    }
    else {
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
    return ( '', '', '' );
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
    }
    else {
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

        if ( $node->get_bundle eq $target_node->get_bundle ) {    # same sentence

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
        }

        else {    # should be always the same document, if it exists at all

            my $orientation = $target_node->get_bundle->get_position - $node->get_bundle->get_position - 1;
            $orientation = $orientation > 0 ? 'right' : ( $orientation < 0 ? 'left' : 0 );
            if ( $orientation =~ /left|right/ ) {
                if ( $orientation eq 'left' ) {
                    log_info "ref-arrows: Preceding sentence\n" if $main::macroDebug;
                    push @coords, "\&n,n,n-30,n+$rotate_prv_snt";
                    $rotate_prv_snt += 10;
                }
                else {    #right
                    log_info "ref-arrows: Following sentence\n" if $main::macroDebug;
                    push @coords, "\&n,n,n+30,n+$rotate_nxt_snt";
                    $rotate_nxt_snt += 10;
                }
            }
            else {
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

sub node_style {    # silly code just to avoid the need for eval
    my $layer = pop @_;
    my %subs;
    $subs{t} = \&tnode_style;
    $subs{a} = \&anode_style;
    $subs{n} = \&nnode_style;
    $subs{p} = \&pnode_style;
    if ( defined $subs{$layer} ) {
        return &{ $subs{$layer} }(@_);
    }
    else {
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

1;

__END__


=head1 NAME

Treex::Core::TredView


=head1 DESCRIPTION

descr
