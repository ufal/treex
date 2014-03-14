package Treex::Core::TredView::Styles;

use Moose;
use Treex::Core::Log;
use Treex::Core::TredView::Colors;
use Treex::Core::TredView::LineStyles;


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

has '_line_styles' => (
    is      => 'ro',
    isa     => 'Treex::Core::TredView::LineStyles',
    default => sub { Treex::Core::TredView::LineStyles->new() }
);

sub _is_coord {
    my ( $self, $node ) = @_;
    return 0 if $node->get_layer ne 't';
    return ( $node->{functor} and $node->{functor} =~ /^(?:ADVS|APPS|CONFR|CONJ|CONTRA|CSQ|DISJ|GRAD|OPER|REAS)$/ );
}

sub bundle_style {
    my $self  = shift;
    my $style = '#{nodeXSkip:10}#{nodeYSkip:5}#{lineSpacing:0.9}#{balance:0}';
    $style .= '#{Node-width:7}#{Node-height:7}#{Node-currentwidth:10}#{Node-currentheight:10}';
    $style .= '#{CurrentOval-width:3}#{CurrentOval-outline:' . $self->_colors->get('current') . '}';
    $style .= '#{Line-fill:' . $self->_colors->get('edge') . '}#{Line-width:2}';

    return $style;
}

sub node_style {
    my ( $self, $node ) = @_;
    my $styles = '';

    if ( $node->is_root() ) {
        $styles .= '#{Node-rellevel:' . $node->{'_shift_down'} . '}';
    }

    my $layer = $node->get_layer;
    my %subs;
    $subs{t} = \&_tnode_style;
    $subs{a} = \&_anode_style;
    $subs{n} = \&_nnode_style;
    $subs{p} = \&_pnode_style;

    if ( defined $subs{$layer} ) {
        return $styles . &{ $subs{$layer} }( $self, $node );
    }
    else {
        log_fatal "Undefined or unknown layer: $layer";
    }
}

sub _anode_style {
    my ( $self, $node ) = @_;
    if ( $node->clause_number ) {
        my $clr = $self->_colors->get_clause_color( $node->clause_number );
        return '#{Oval-fill:' . $clr . '}' . '#{Line-fill:' . $clr . '}';
    }
    return '#{Oval-fill:' . $self->_colors->get('anode') . '}';
}

sub _tnode_style {
    my ( $self, $node ) = @_;

    my $style = '#{Oval-fill:' . $self->_colors->get('tnode') . '}';
    return $style if $node->is_root;

    $style .= '#{Node-shape:' . ( $node->{is_generated} ? 'rectangle' : 'oval' ) . '}';

    my $coord_circle = '#{Line-decoration:shape=oval;coords=-20,-20,20,20;outline=' . $self->_colors->get('coord') . ';width=1;dash=5,5 }';
    $coord_circle .= '#{Line-arrow:&}#{Line-arrowshape:&}#{Line-dash:&}';
    $coord_circle .= '#{Line-tag:&}#{Line-smooth:&}#{Oval-fill:' . $self->_colors->get('tnode_coord') . '}';

    # For coordination roots
    my $k1 = '20 / sqrt((xp-xn)**2 + (yp-yn)**2)';
    my $x1 = 'xn-(xn-xp)*' . $k1;
    my $y1 = 'yn-(yn-yp)*' . $k1;

    # For coordination members
    my $k2 = '(1 - 20 / sqrt((xp-xn)**2 + (yp-yn)**2))';
    my $x2 = 'xn-(xn-xp)*' . $k2;
    my $y2 = 'yn-(yn-yp)*' . $k2;

    my $line_width = 2;
    my $line_color = $self->_colors->get('edge');
    my $line_coords;
    my $line_dash;

    if ($node->{is_member}) {
        if (not $node->is_root and $self->_is_coord($node->parent)) {
            $line_width = 1;
            $line_color = $self->_colors->get('coord');
        } else {
            $line_color = $self->_colors->get('error');
        }
    } elsif (not $node->is_root and $self->_is_coord($node->parent)) {
        $line_color = $self->_colors->get('coord_mod');
    } elsif ($self->_is_coord($node)) {
        $line_color = $self->_colors->get('coord');
        $line_width = 1;
    }

    if (($node->{functor} and $node->{functor} =~ m/^(?:PAR|PARTL|VOCAT|RHEM|CM|FPHR|PREC)$/) or (not $node->is_root and $node->parent->is_root)) {
        $line_width = 1;
        $line_dash = '2,4';
        $line_color = $self->_colors->get('edge');
    }

    if ($self->_is_coord($node)) {
        $line_coords = "n,n,n,n&$x1,$y1";
        $line_width = '0&'.$line_width;
        $line_color = 'white&'.$line_color;
        $line_dash = '&'.$line_dash if $line_dash;
    } else {
        $line_coords = 'n,n';
    }

    if (not $node->is_root and $self->_is_coord($node->parent)) {
        $line_coords .= ",$x2,$y2";
    } else {
        $line_coords .= ',p,p';
    }
    
    $style .= $coord_circle if $self->_is_coord($node);
    $style .= "#{Line-width:$line_width}#{Line-fill:$line_color}#{Line-coords:$line_coords}";
    $style .= "#{Line-dash:$line_dash}" if $line_dash;
    $style .= '#{Oval-fill:#00ff00}' if $node->wild->{ali_root};
    return $style;
}

sub _nnode_style {
    my ( $self, $node ) = @_;
    return '#{Oval-fill:' . $self->_colors->get('nnode') . '}';
}

sub _pnode_style {
    my ( $self, $node ) = @_;

    my $terminal = $node->is_leaf;

    my $style = '#{Line-coords:n,n,n,p,p,p}';
    $style .= '#{nodeXSkip:4}#{nodeYSkip:0}#{NodeLabel-skipempty:1}';
    $style .= '#{NodeLabel-halign:center}#{Node-textalign:center}';

    if ($terminal) {
        my $shift = $node->root->{_tree_depth} - $node->{_depth};
        $style .= "#{Node-rellevel:$shift}";
    }

    if ( not $node->is_root and scalar( $node->parent->children ) == 1 ) {
        $style .= '#{Node-addafterskip:15}';
    }

    if ( not $terminal ) {
        $style .= '#{Oval-fill:' . ( $node->{is_head} ? $self->_colors->get('nonterminal_head') : $self->_colors->get('nonterminal') ) . '}';
        $style .= '#{Node-shape:rectangle}#{CurrentOval-outline:' . $self->_colors->get('current') . '}';
        $style .= '#{CurrentOval-width:2}#{Node-surroundtext:1}#{NodeLabel-valign:center}';
    }
    else {
        $style .= '#{Line-dash:.}';
        my $ctype = $node->tag eq '-NONE-' ? 'trace'
                  : $node->is_head         ? 'terminal_head'
                  :                          'terminal';
        $style .= '#{Oval-fill:' . $self->_colors->get($ctype) . '}';
    }

    return $style;
}

# based on DrawCorefArrows from config/TectoMT_TredMacros.mak, simplified
# ignoring special values ex and segm
sub draw_arrows {
    my ( $self, $node, $styles, $line, $target_ids, $arrow_types ) = @_;
    my ( @coords, @colors, @dash, @tags );
    my ( $rotate_prv_snt, $rotate_nxt_snt, $rotate_dfr_doc ) = ( 0, 0, 0 );

    foreach my $target_id (@$target_ids) {
        next if !defined $target_ids || $target_id eq ""; # skip blank IDs
        # some alignment links do not have their type filled, default to generic alignment
        my $arrow_type = shift @$arrow_types // 'alignment';         

        my $target_node
            = eval { $self->_treex_doc->get_node_by_id($target_id) };
        if ($target_node) {
            if ( $node->get_bundle eq $target_node->get_bundle ) {    # same sentence

                my $T  = "[?\$node->{id} eq '$target_id'?]";
                my $X  = "(x$T-xn)";
                my $Y  = "(y$T-yn)";
                my $D  = "sqrt($X**2+$Y**2)";
                my $BX = 'n';
                my $BY = 'n';
                my $MX = "((x$T+xn)/2 - $Y*(25/$D+0.12))";
                my $MY = "((y$T+yn)/2 + $X*(25/$D+0.12))";
                my $EX = "x$T";
                my $EY = "y$T";
                my $K1 = "20 / sqrt(($MX-xn)**2 + ($MY-yn)**2)";
                my $K2 = "20 / sqrt((x$T-$MX)**2 + (y$T-$MY)**2)";

                if ( $self->_is_coord($node) ) {
                    $BX = "xn-(xn-$MX)*$K1";
                    $BY = "yn-(yn-$MY)*$K1";
                }
                if ( $self->_is_coord($target_node) ) {
                    $EX = "x$T+($MX-x$T)*$K2";
                    $EY = "y$T+($MY-y$T)*$K2";
                }
                if ( $arrow_type eq 'coindex' ) {
                    $MX = "((x$T+xn)/2 + $Y*(25/$D+0.12))";
                    $MY = "((y$T+6+yn)/2 - $X*(25/$D+0.12))";
                    $EY = "y$T+6";
                }

                push @coords, "$BX,$BY,$MX,$MY,$EX,$EY";
            }
            else {    # should be always the same document, if it exists at all

                my $orientation = $target_node->get_bundle->get_position - $node->get_bundle->get_position;
                $orientation = $orientation > 0 ? 'right' : 'left';
                if ( $orientation =~ /left|right/ ) {
                    if ( $orientation eq 'left' ) {
                        log_info "ref-arrows: Preceding sentence\n" if $main::macroDebug;
                        push @coords, "n,n,n-30,n+$rotate_prv_snt";
                        $rotate_prv_snt += 10;
                    }
                    else {    #right
                        log_info "ref-arrows: Following sentence\n" if $main::macroDebug;
                        push @coords, "n,n,n+30,n+$rotate_nxt_snt";
                        $rotate_nxt_snt += 10;
                    }
                }
            }
        }
        else {
            log_info "ref-arrows: Not found!\n" if $main::macroDebug;
            push @coords, "n,n,n+$rotate_dfr_doc,n-25";
            $rotate_dfr_doc += 10;
        }

        push @tags, $arrow_type;
        push @colors, ( $self->_colors->get($arrow_type) );
        push @dash, ( $self->_line_styles->dash_style($arrow_type) );
    }

    $line->{-coords} ||= 'n,n,p,p';

    if (@coords) {
        TredMacro::AddStyle(
            $styles, 'Line',
            -coords => ( $line->{-coords} || '' ) . '&' . join( '&', @coords ),
            -arrow      => ( $line->{-arrow}      || '' ) . ( '&last' x @coords ),
            -arrowshape => ( $line->{-arrowshape} || '' ) . ( '&16,18,3' x @coords ),
            -dash => ( $line->{-dash} || '' ) . '&' . join( '&', @dash ),
            -width => ( $line->{-width} || '' ) . ( '&1' x @coords ),
            -fill => ( $line->{-fill} || '' ) . '&' . join( '&', @colors ),
            -tag  => ( $line->{-tag}  || '' ) . '&' . join( '&', @tags ),
            -smooth => ( $line->{-smooth} || '' ) . ( '&1' x @coords )
        );
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Core::TredView::Styles - Styling of trees in Tred (how they look)

=head1 DESCRIPTION

This packages provides styling for the trees displayed in Tred.

=head1 METHODS

=head2 Public methods

=over 4

=item bundle_style

=item node_style

=item draw_arrows

=back

=head2 Private methods

=over 4

=item _anode_style

=item _tnode_style

=item _nnode_style

=item _pnode_style

=back

=head1 AUTHOR

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

