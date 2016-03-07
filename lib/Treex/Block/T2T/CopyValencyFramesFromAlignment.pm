package Treex::Block::T2T::CopyValencyFramesFromAlignment;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($aligned) = $tnode->get_directed_aligned_nodes();

    if ($aligned) {
        foreach my $source ( @{$aligned} ) {
            my $val_frame = $source->val_frame_rf;
            if ($val_frame) {
                $tnode->set_val_frame_rf($val_frame);
                last;
            }
        }
    }
    if ( !$tnode->val_frame_rf ) {
        $tnode->set_val_frame_rf('');
    }
}

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CopyValencyFramesFromAlignment

=head1 DESCRIPTION

Project valency frame references through alignment links on the t-layer, e.g. golden 
valency frame references to automatically generated t-trees of the same sentences.

The processed trees must already be aligned to other trees on the t-layer, 
which already have their valency frame references set.
This copies the valency frame references for all nodes that are aligned
and have the reference set. Nodes without alignment or without reference are assigned 
an empty string.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
