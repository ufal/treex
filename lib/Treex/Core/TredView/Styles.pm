package Treex::Core::TredView::Styles;

use Moose;
use Treex::Core::Log;

sub bundle_style {
    my $style = '#{nodeXSkip:10}#{nodeYSkip:5}#{lineSpacing:0.9}#{balance:0}';
    $style .= '#{Node-width:7}#{Node-height:7}#{Node-currentwidth:9}#{Node-currentheight:9}';
    $style .= '#{CurrentOval-width:3}#{CurrentOval-outline:'.TredMacro::CustomColor('current').'}';

    return $style;
}

sub node_style {
    my ( $self, $node ) = @_;
    my $styles = '';

    if ( $node->is_root() ) {
        $styles .= '#{Node-rellevel:'.$node->{'_shift_down'}.'}';
    }

    my $layer = $node->get_layer;
    my %subs;
    $subs{t} = \&_tnode_style;
    $subs{a} = \&_anode_style;
    $subs{n} = \&_nnode_style;
    $subs{p} = \&_pnode_style;

    if ( defined $subs{$layer} ) {
        return $styles.&{ $subs{$layer} }($self, $node);
    } else {
        log_fatal "Undefined or unknown layer: $layer";
    }
}

sub _anode_style {
    return "#{Oval-fill:#f66}";
}

sub _tnode_style {
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

sub _nnode_style {
    return "#{Oval-fill:yellow}";
}

sub _pnode_style {
    my ( $self, $node ) = @_;
    
    my $terminal = $node->get_pml_type_name eq 'p-terminal.type' ? 1 : 0;
    
    my $style = '#{Line-coords:n,n,n,p,p,p}';
    $style .= '#{CurrentTextBox-fill:red}#{nodeXSkip:4}#{nodeYSkip:0}';
    $style .= '#{NodeLabel-halign:center}#{Node-textalign:center}#{NodeLabel-skipempty:1}';

    if ($terminal) {
        my $shift = $node->root->{_tree_depth} - $node->{_depth};
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
    
    return $style;
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

=back

=head2 Private methods

=item _anode_style

=item _tnode_style

=item _nnode_style

=item _pnode_style

=over 4

=head1 AUTHOR

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

