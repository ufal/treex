package Treex::Block::T2T::CopyFunctorsFromAlignment;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($aligned) = $tnode->get_directed_aligned_nodes();

    if ($aligned) {
        foreach my $source ( @{$aligned} ) {
            my $functor = $source->functor;
            if ($functor) {
                $tnode->set_functor($functor);
                last;
            }
        }
    }
    if ( !$tnode->functor ) {
        $tnode->set_functor('???');
    }
}

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CopyFunctorsFromAlignment

=head1 DESCRIPTION

Project functor values through alignment links on the t-layer, e.g. golden functor values to automatically generated
t-trees of the same sentences, or source functors to target language.

The processed trees must already be aligned to other trees on the t-layer, which already have their functor values set.
This copies the functor values for all nodes that are aligned; if a node is not aligned and does not already have any functor
value, it is set to '???'.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
