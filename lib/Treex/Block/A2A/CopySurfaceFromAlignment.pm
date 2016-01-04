package Treex::Block::A2A::CopySurfaceFromAlignment;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_atree {

    my ( $self, $aroot ) = @_;

    my @anodes = $aroot->get_descendants();
    my %aligned = map { $_ => _get_aligned_node($_) } @anodes;

    map { $_->set_form( $aligned{$_}->form ) if ( $aligned{$_} ) } @anodes;
    map { $_->set_lemma( $aligned{$_}->lemma ) if ( $aligned{$_} ) } @anodes; # ??? do this ???
    map { $_->set_no_space_after( $aligned{$_}->no_space_after ) if ( $aligned{$_} ) } @anodes;

}

# A simplification -- retrieve the first aligned node
sub _get_aligned_node {

    my ( $anode ) = @_;

    my ($aligned) = $anode->get_directed_aligned_nodes();

    if ($aligned) {
        return $aligned->[0];
    }
    return undef;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::CopySurfaceFromAlignment

=head1 DESCRIPTION

Copy surface forms and order from an aligned a-tree (which should be the same sentence). 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
