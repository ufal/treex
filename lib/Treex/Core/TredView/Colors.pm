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
        'coord_mod' => '#666666',

        'anode'            => '#ff6666',
        'anode_coord'      => '#ff6666',
        'nnode'            => '#ffff00',
        'tnode'            => '#4488ff',
        'tnode_coord'      => '#ccddff',
        'terminal'         => '#ffff66',
        'nonterminal_head' => '#90ee90',
        'nonterminal'      => '#ffffe0',
        'trace'            => '#aaaaaa',
        'current'          => '#ff0000',

        'coref_gram' => '#c05633',
        'coref_text' => '#4c509f',
        'compl'      => '#629f52',
        'alignment'  => '#bebebe',

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

        'clause0' => 'magenta',
        'clause1' => 'orange',
        'clause2' => 'blue',
        'clause3' => 'green',
        'clause4' => 'red',
        'clause5' => 'DarkOrange',
        'clause6' => 'DarkBlue',
        'clause7' => 'DarkGreen',
        'clause8' => 'DarkRed',
        'clause9' => 'DarkCyan',
    };
}

sub get {
    my ( $self, $code, $markup ) = @_;
    if ( not exists $self->_colors->{$code} ) {
        log_fatal "Unknown color code '$code'\n";
    }
    $code = $self->_colors->{$code};
    return $markup ? '#{' . $code . '}' : $code;
}

sub get_clause_color {
    my ( $self, $clause_number, $code, $markup ) = @_;
    return $self->get( 'clause' . ( $clause_number % 10 ), $markup );
}

1;

