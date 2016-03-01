package Treex::Core::TredView::LineStyles;

use Moose;
use Treex::Core::Log;


has '_dash' => (
    is => 'ro',
    isa => 'HashRef[Str]',
    builder => '_build_dash',
);

sub _build_dash {
    return {
        # just alignment lines are dashed, others are plain
        'alignment'        => '5,3',
        'left'             => '5,3',
        'right'            => '5,3',
        'int'              => '5,3',
        'gdfa'             => '5,3',
        'revgdfa'          => '5,3',
        'rule-based'       => '5,3',
        'monolingual'      => '5,3',      
        'coref_supervised' => '5,3',      
        'copy'             => '5,3',        
    };
}


sub dash_style {
    my ( $self, $code ) = @_;    

    # try to truncate complex alignment types to first one (e.g. "gdfa.int.left.right.revgdfa" -> "gdfa")
    $code =~ s/\..*// if ( not exists $self->_dash->{$code} );
    # return dash type or nothing
    return defined( $self->_dash->{$code} ) ? $self->_dash->{$code} : '' ;
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Core::TredView::LineStyles - List of line styles used in TrEd

=head1 DESCRIPTION

This package provides names for common line styles (dash types) used in TrEd.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
