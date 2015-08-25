package Treex::Core::TredView::TreeLayout;

use Moose;
use Moose::Util::TypeConstraints;

subtype 'TreeLayout' => as 'ArrayRef[ArrayRef[Int]]';

has '_layouts_loaded' => ( is => 'rw', isa => 'Int',                 default => 0 );
has '_layouts_saved'  => ( is => 'rw', isa => 'Int',                 default => 0 );
has '_layouts'        => ( is => 'rw', isa => 'HashRef[TreeLayout]', default => sub { {} } );

has '_tag_text' => ( is => 'ro', isa => 'Str', default => 'text' );
has '_tag_tree' => ( is => 'ro', isa => 'Str', default => 'tree' );
has '_tag_wrap' => ( is => 'ro', isa => 'Str', default => 'wrap' );
has '_tag_none' => ( is => 'ro', isa => 'Str', default => 'none' );

has '_margin' => ( is => 'ro', isa => 'Int', default => 20 );
has '_width'  => ( is => 'ro', isa => 'Int', default => 80 );
has '_height' => ( is => 'ro', isa => 'Int', default => 45 );

has '_drag_tree' => ( is => 'rw', isa => 'Maybe[HashRef[Str]]', default => undef );
has '_drag_x'    => ( is => 'rw', isa => 'Int', default => -1 );
has '_drag_y'    => ( is => 'rw', isa => 'Int', default => -1 );
has '_cur_tree'  => ( is => 'rw', isa => 'Maybe[HashRef[Str]]', default => undef );

has '_cur_layout' => ( is => 'rw', isa => 'TreeLayout' );

sub get_tree_label {
    my ( $self, $tree ) = @_;
    my $label = $tree->language . '-' . $tree->get_layer;
    my $sel   = $tree->selector;
    $label .= '-' . $sel if $sel;
    return $label;
}

sub get_layout_label {
    my ( $self, $bundle ) = @_;
    {
        no warnings 'once';
        $bundle = $TredMacro::root if not $bundle;
    }
    return unless ref($bundle) eq 'Treex::Core::Bundle';

    my @label;
    ###!!! DZ: Occasionally we get a 'zone' of the type Treex::PML::Struct (instead of Treex::Core::BundleZone).
    ###!!! Ttred then complains "Can't locate object method "get_all_trees" via package..."
    ###!!! I am grepping the zones for real ones but one may want to find the cause within get_all_zones() instead.
    my @zones = grep {ref($_) ne 'Treex::PML::Struct'} $bundle->get_all_zones();
    foreach my $zone ( sort { $a->language cmp $b->language } @zones ) {
        push @label, map { $self->get_tree_label($_) } sort { $a->get_layer cmp $b->get_layer } $zone->get_all_trees();
    }
    return join ',', @label;
}

sub get_layout {
    my $self  = shift;
    my $label = $self->get_layout_label(@_);
    if ( exists $self->_layouts->{$label} ) {
        return $self->_layouts->{$label};
    }
    else {
        my $cols = [];
        my @trees = split ',', $label;
        for ( my $i = 0; $i <= $#trees; $i++ ) {
            $cols->[$i]->[0] = { 'label' => $trees[$i], 'visible' => 1 };
        }

        $self->_layouts->{$label} = $cols;
        return $cols;
    }
}

sub load_layouts {
    my $self = shift;
    return if $self->_layouts_loaded;
    $self->{_layouts_loaded} = 1;

    my $filename = TredMacro::FindMacroDir('treex') . '/.layouts.cfg';
    open my $CFG, '<:encoding(utf-8)', $filename or return;

    while (<$CFG>) {
        chomp;
        my ( $label, $coords ) = split '=';
        my @label  = split ',', $label;
        my @coords = split ',', $coords;
        my $cols   = [];

        for ( my $i = 0; $i <= $#label; $i++ ) {
            my ( $col, $row, $visibility ) = split '-', $coords[$i];
            $visibility = 1 if not defined $visibility;
            $cols->[$col]->[$row] = { 'label' => $label[$i], 'visible' => $visibility };
        }

        $self->_layouts->{$label} = $cols;
    }

    close $CFG;
    return;
}

sub save_layouts {
    my $self = shift;
    return if $self->_layouts_saved;
    # There's no point in saving layouts when GUI is not running (e.q. btred processing)
    return unless ref(TredMacro::GUI()) eq 'TrEd::Window';

    my $filename = TredMacro::FindMacroDir('treex') . '/.layouts.cfg';
    open my $CFG, '>:encoding(utf-8)', $filename or die $!;

    while ( my ( $label, $cols ) = each %{ $self->_layouts } ) {
        my %coords = ();
        for ( my $col = 0; $col < scalar(@$cols); $col++ ) {
            for ( my $row = 0; $row < scalar( @{ $cols->[$col] } ); $row++ ) {
                my $tree = $cols->[$col]->[$row];
                $coords{$tree->{'label'}} = "$col-$row-".$tree->{'visible'} if $tree;
            }
        }

        my @coords = ();
        for my $tree ( split ',', $label ) {
            push @coords, $coords{$tree};
        }

        print $CFG $label . '=' . join( ',', @coords ) . "\n";
    }

    close $CFG;
    $self->{_layouts_saved} = 1;
    return;
}

sub _move_layout {
    my ( $self, $x, $y ) = @_;
    my $layout     = $self->_cur_layout;
    my $new_layout = [];

    for ( my $i = 0; $i < $x; $i++ ) {
        $new_layout->[$i] = [];
    }
    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        for ( my $j = 0; $j < scalar @{ $layout->[$i] }; $j++ ) {
            if ( $layout->[$i]->[$j] ) {
                if ( $i + $x < 0 or $j + $y < 0 ) {
                    print STDERR "Error: layout is moving out of bounds.\n";
                    return;
                }
                $new_layout->[ $i + $x ]->[ $j + $y ] = $layout->[$i]->[$j];
            }
        }
    }

    $self->{_cur_layout} = $new_layout;
    return;
}

sub _wrap_layout {
    my $self       = shift;
    my $layout     = $self->_cur_layout;
    my $new_layout = [];

    # 8 pairs of coords lying around the center point (0, 0)
    my @c = (
        -1, -1,
        0,  -1,
        1,  -1,
        -1, 0,
        1,  0,
        -1, 1,
        0,  1,
        1,  1
    );

    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        for ( my $j = 0; $j < scalar @{ $layout->[$i] }; $j++ ) {
            if ( $layout->[$i]->[$j] and $layout->[$i]->[$j]->{'label'} ne $self->_tag_wrap ) {
                $new_layout->[$i]->[$j] = $layout->[$i]->[$j];
                for ( my $k = 0; $k < scalar @c; $k += 2 ) {
                    my ( $x, $y ) = ( $i + $c[$k], $j + $c[ $k + 1 ] );
                    if ($x >= 0 and $y >= 0 and not $new_layout->[$x]->[$y]) {
                        $new_layout->[$x]->[$y] = { 'label' => $self->_tag_wrap, 'visible' => 0 };
                    }
                }
            }
        }
    }

    $self->{_cur_layout} = $new_layout;
    return;
}

sub _normalize_layout {
    my $self        = shift;
    my $layout      = $self->_cur_layout;
    my %filled_cols = ();
    my %filled_rows = ();
    my $gap_x       = 0;
    my $gap_y       = 0;
    my $new_layout  = [];

    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        for ( my $j = 0; $j < scalar @{ $layout->[$i] }; $j++ ) {
            if ( $layout->[$i]->[$j] and $layout->[$i]->[$j]->{'label'} ne $self->_tag_wrap ) {
                $filled_cols{$i} = 1;
                $filled_rows{$j} = 1;
            }
        }
    }

    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        $gap_y = 0;
        $gap_x++ if not exists $filled_cols{$i};
        for ( my $j = 0; $j < scalar @{ $layout->[$i] }; $j++ ) {
            $gap_y++ if not exists $filled_rows{$j};
            if ( $layout->[$i]->[$j] and $layout->[$i]->[$j]->{'label'} ne $self->_tag_wrap ) {
                $new_layout->[ $i - $gap_x ]->[ $j - $gap_y ] = $layout->[$i]->[$j];
            }
        }
    }

    $self->{_cur_layout} = $new_layout;
    return;
}

sub _get_layout_coords {
    my ( $self, $x, $y ) = @_;
    $x -= $self->_margin;
    $y -= $self->_margin;
    $x /= $self->_width + $self->_margin;
    $y /= $self->_height + $self->_margin;
    return ( $x, $y );
}

sub _get_pos {
    my ( $self, $x, $y ) = @_;
    my $a = $x - $self->_margin;
    my $b = $y - $self->_margin;

    my $wm = $self->_width + $self->_margin;
    my $hm = $self->_height + $self->_margin;

    my ( $i, $j );
    {
        use integer;
        $i = $a / $wm;
        $j = $b / $hm;
    }
    $a %= $wm;
    $b %= $hm;

    return if $a >= $self->_width or $b >= $self->_height;

    my $tree;
    if ( $i < 0 or $j < 0 ) {
        $tree = { 'label' => $self->_tag_none, 'visible' => 0 };
    }
    elsif ( defined $self->_cur_layout->[$i]->[$j] ) {
        $tree = $self->_cur_layout->[$i]->[$j];
    }
    else {
        $tree = { 'label' => $self->_tag_none, 'visible' => 0 };
    }
    return ( $i * $wm + $self->_margin, $j * $hm + $self->_margin, $tree );
}

sub _mouse_move {
    my ( $self, $canvas ) = @_;
    my ( $x, $y, $tree ) = $self->_get_pos( $Tk::event->x, $Tk::event->y );

    if ( $self->_cur_tree and (not $tree or $tree->{'label'} ne $self->_cur_tree->{'label'}) ) {
        if ( $self->_cur_tree->{'label'} ne $self->_tag_wrap and $self->_cur_tree->{'label'} ne $self->_tag_none ) {
            $canvas->itemconfigure( $self->_cur_tree->{'label'} . '&&' . $self->_tag_tree, -outline => 'black', -width => 1 );
        }
        else {
            $canvas->delete( $self->_cur_tree->{'label'} );
        }
        $self->{_cur_tree} = undef;
    }
    if ( $tree and (not $self->_cur_tree or $tree->{'label'} ne $self->_cur_tree->{'label'}) ) {
        if ( $tree->{'label'} ne $self->_tag_wrap and $tree->{'label'} ne $self->_tag_none ) {
            my $color = $self->_drag_tree ? ( $tree->{'label'} eq $self->_drag_tree->{'label'} ? 'red' : 'green' ) : 'blue';
            $canvas->itemconfigure( $tree->{'label'}.'&&'.$self->_tag_tree, -outline => $color, -width => 2 );
        }
        elsif ( $self->_drag_tree ) {
            my $color = $tree->{'label'} eq $self->_tag_wrap ? 'green' : 'red';
            $canvas->create(
                'rectangle',
                $x, $y, $x + $self->_width, $y + $self->_height,
                -tags => [$tree->{'label'}], -outline => $color, -width => 2
            );
        }
        $self->{_cur_tree} = $tree;
    }
    return;
}

sub _mouse_drag {
    my ( $self, $canvas ) = @_;
    my ( $x, $y, $tree ) = $self->_get_pos( $Tk::event->x, $Tk::event->y );
    return if ( not $tree ) or $tree->{'label'} eq $self->_tag_wrap or $tree->{'label'} eq $self->_tag_none;

    $self->{_drag_tree} = $tree;
    ( $self->{_drag_x}, $self->{_drag_y} ) = $self->_get_layout_coords( $x, $y );
    $canvas->itemconfigure( $tree->{'label'} . '&&' . $self->_tag_tree, -outline => 'red', -width => 2, -fill => 'yellow' );
    return;
}

sub _mouse_drop {
    my ( $self, $canvas ) = @_;
    return unless $self->_drag_tree;

    my ( $x, $y, $tree ) = $self->_get_pos( $Tk::event->x, $Tk::event->y );

    $canvas->itemconfigure( $self->_drag_tree->{'label'} . '&&' . $self->_tag_tree, -fill => 'white' );

    if ( ( not $tree ) or $tree->{'label'} eq $self->_tag_none ) {
        $canvas->delete( $self->_tag_none ) if $tree;
        $self->{_drag_tree} = undef;
        $self->{_drag_x} = $self->{_drag_y} = -1;
        return;
    }

    my $layout = $self->_cur_layout;

    $layout->[ $self->_drag_x ]->[ $self->_drag_y ] = undef;
    ( $x, $y ) = $self->_get_layout_coords( $x, $y );
    if ( $tree->{'label'} ne $self->_tag_wrap ) {
        for ( my $i = scalar @$layout; $i > $x; $i-- ) {
            if ( defined $layout->[ $i - 1 ]->[$y] ) {
                $layout->[$i]->[$y] = $layout->[ $i - 1 ]->[$y];
                $layout->[ $i - 1 ]->[$y] = undef;
            }
        }
    }
    $layout->[$x]->[$y] = $self->_drag_tree;

    $self->{_cur_layout} = $layout;
    $self->_normalize_layout();
    $self->_move_layout( 1, 1 );
    $self->_wrap_layout();
    $self->_draw_layout($canvas);

    $self->{_drag_tree} = undef;
    $self->{_drag_x} = $self->{_drag_y} = -1;
    return;
}

sub _mouse_right {
    my ( $self, $canvas ) = @_;
    my ( $x, $y, $tree ) = $self->_get_pos( $Tk::event->x, $Tk::event->y );
    return if ( not $tree ) or $tree->{'label'} eq $self->_tag_wrap or $tree->{'label'} eq $self->_tag_none or $self->{_drag_tree};

    ( $x, $y ) = $self->_get_layout_coords( $x, $y );
    my $layout = $self->_cur_layout;
    my $visibility = $layout->[$x]->[$y]->{'visible'} ? 0 : 1;

    $layout->[$x]->[$y]->{'visible'} = $visibility;
    $canvas->itemconfigure( $tree->{'label'} . '&&' . $self->_tag_tree, -fill => $visibility ? 'white' : 'grey' );
    $self->{_cur_layout} = $layout;
    return;
}

sub _draw_layout {
    my ( $self, $canvas ) = @_;
    my $layout = $self->_cur_layout;

    $canvas->delete('all');
    for ( my $i = 0; $i < scalar @$layout; $i++ ) {
        for ( my $j = 0; $j < scalar @{ $layout->[$i] }; $j++ ) {
            my $tree = $layout->[$i]->[$j];
            if ( $tree and $tree->{'label'} ne $self->_tag_wrap ) {
                my ( $lang, $layer, $selector ) = split '-', $tree->{'label'}, 3;
                $lang = Treex::Core::Types::get_lang_name($lang);
                $canvas->create(
                    'rectangle',
                    $i * ( $self->_width + $self->_margin ) + $self->_margin,
                    $j * ( $self->_height + $self->_margin ) + $self->_margin,
                    ( $i + 1 ) * ( $self->_width + $self->_margin ),
                    ( $j + 1 ) * ( $self->_height + $self->_margin ),
                    -tags => [ $self->_tag_tree, $tree->{'label'} ],
                    -fill => $tree->{'visible'} ? 'white' : 'grey'
                );
                $canvas->create(
                    $self->_tag_text,
                    ( $i + 1 ) * ( $self->_width + $self->_margin ) - 0.5 * $self->_width,
                    ( $j + 1 ) * ( $self->_height + $self->_margin ) - 0.5 * $self->_height,
                    -anchor  => 'center',
                    -justify => 'center',
                    -tags    => [$tree->{'label'}],
                    -text    => "$lang\n" . uc($layer) . ( $selector ? "\n$selector" : '' )
                );
            }
        }
    }

    $canvas->CanvasBind( '<Motion>'          => [ $self => '_mouse_move', $canvas ] );
    $canvas->CanvasBind( '<ButtonPress-1>'   => [ $self => '_mouse_drag', $canvas ] );
    $canvas->CanvasBind( '<ButtonRelease-1>' => [ $self => '_mouse_drop', $canvas ] );
    $canvas->CanvasBind( '<ButtonRelease-3>' => [ $self => '_mouse_right', $canvas ] );
    return;
}

sub conf_dialog {
    my $self = shift;

    $self->{_cur_layout} = $self->get_layout();
    $self->_normalize_layout();
    $self->_move_layout( 1, 1 );
    $self->_wrap_layout();

    my $top    = TredMacro::ToplevelFrame();
    my $dialog = $top->DialogBox( -title => "Trees layout configuration", -buttons => [ "OK", "Cancel" ] );
    my $canvas = $dialog->add(
        'Canvas',
        -width  => 7 * $self->_width + 8 * $self->_margin,
        -height => 5 * $self->_height + 6 * $self->_margin
    );

    $self->_draw_layout($canvas);
    $canvas->pack( -expand => 1, -fill => 'both' );

    my $button = $dialog->Show();
    if ( $button eq 'OK' ) {
        $self->_normalize_layout();
        $self->_layouts->{ $self->get_layout_label() } = $self->_cur_layout;
        return 1;
    }
    else {
        return 0;
    }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Core::TredView::TreeLayout - Layout of trees in Tred

=head1 DESCRIPTION

This package supports the main Tred visualization package Treex::Core::TredView.
It's purpose is to allow an user friendly configuration of the placement of
the trees stored in a bundle.

The mechanism works only with bundles. Each bundle gets a label that describes
it's content (combination of layers, languages and selectors). When there is a
bundle to be displayed, the package constructs its label and tries to find its
layout. If the label is unknown (no layout found), default is provided.

Therefore it's perfectly legal to have different sets of trees in each bundle in
a single file. Also, when a layout is configured for some set of trees, it will
be used each time the same set is displayed even if these sets occur in
completely different and unrelated files.

The configuration is persistent - it is saved along with the tred extension in
a special file.

=head1 METHODS

=head2 Public methods

=over 4

=item get_tree_label

=item get_layout_label

=item get_layout

=item load_layouts

=item save_layouts

=item conf_dialog

=back

=head2 Private methods

=over 4

=item _move_layout

=item _wrap_layout

=item _normalize_layout

=item _get_layout_coords

=item _get_pos

=item _mouse_move

=item _mouse_drag

=item _mouse_drop

=item _draw_layout

=back

=head1 AUTHOR

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

