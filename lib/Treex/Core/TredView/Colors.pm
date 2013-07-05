package Treex::Core::TredView::Colors;

use Moose;
use Treex::Core::Log;

has '_colors' => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    builder => '_build_colors'
);

sub _build_colors {
    return {
        'edge'      => '#555555',
        'coord'     => '#bbbbbb',
        'error'     => '#ff0000',
        'coord_mod' => 'aquamarine4',

        'anode'            => '#ff6666',
        'anode_coord'      => '#ff6666',
        'nnode'            => '#ffff00',
        'tnode'            => '#4488ff',
        'tnode_coord'      => '#ccddff',
        'terminal'         => '#ffff66',
        'terminal_head'    => '#90ee90',
        'nonterminal_head' => '#90ee90',
        'nonterminal'      => '#ffffe0',
        'trace'            => '#aaaaaa',
        'current'          => '#ff0000',

        'coref_gram' => '#c05633',
        'coref_text' => '#4c509f',
        'compl'      => '#629f52',
        'coindex'    => '#ffa500',    #orange

        # various alignment link types
        'alignment'   => '#bebebe',
        'left'        => '#bebebe',
        'right'       => '#bebebe',
        'int'         => '#bebebe',
        'gdfa'        => '#bebebe',
        'revgdfa'     => '#bebebe',
        'rule-based'  => '#bebebe',
        'monolingual' => '#bebebe',
        'copy'        => '#bebebe',

        'lex'         => '#006400',
        'aux'         => '#ff8c00',
        'parenthesis' => '#809080',
        'afun'        => '#00008b',
        'member'      => '#0000ff',
        'sentmod'     => '#006400',
        'subfunctor'  => '#a02818',
        'nodetype'    => '#00008b',
        'sempos'      => '#8b008b',
        'phrase'      => '#00008b',
        'formeme'     => '#b000b0',
        'tag'         => '#004048',
        'tag_feat'    => '#7098A0',
        'translit'    => '#444400',
        'gloss'       => '#888800',

        'clause0' => '#ff00ff',    #magenta
        'clause1' => '#ffa500',    #orange
        'clause2' => '#0000ff',    #blue
        'clause3' => '#3cb371',    #MediumSeaGreen
        'clause4' => '#ff0000',    #red
        'clause5' => '#9932cc',    #DarkOrchid
        'clause6' => '#00008b',    #DarkBlue
        'clause7' => '#006400',    #DarkGreen
        'clause8' => '#8b0000',    #DarkRed
        'clause9' => '#008b8b',    #DarkCyan

        '_default' => 'cyan',
    };
}

# This is just to prevent repeating warning for the same unknown color code
has '_unknown_codes' => (
    is      => 'ro',
    isa     => 'HashRef[Bool]',
    default => sub { {} },
);

sub get {
    my ( $self, $code, $markup ) = @_;

    # try to truncate complex alignment types to first one (e.g. "gdfa.int.left.right.revgdfa" -> "gdfa")
    $code =~ s/\..*// if ( not exists $self->_colors->{$code} );

    # warn if the appropriate color still does not exist
    if ( !defined( $self->_colors->{$code} ) ) {
        log_warn "Unknown color code '$code'\n" if ( !$self->_unknown_codes->{$code} );
        $self->_unknown_codes->{$code} = 1;
        $code = '_default';
    }
    $code = $self->_colors->{$code};
    return $markup ? '#{' . $code . '}' : $code;
}

sub get_clause_color {
    my ( $self, $clause_number, $code, $markup ) = @_;
    return $self->get( 'clause' . ( $clause_number % 10 ), $markup );
}

1;

__END__

=head1 NAME

Treex::Core::TredView::Colors - List of colors used in TrEd

=head1 DESCRIPTION

This package provides names for common colors used in TrEd.

=head1 AUTHOR

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

