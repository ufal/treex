package Treex::Block::A2W::EN::DeleteTracesFromAtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_anode {
    my ( $self, $anode ) = @_;
    if ($anode->tag eq '-NONE-') {
        foreach my $child ($anode->get_descendants) {
            $child->set_parent($anode->get_parent);
        }
        $anode->remove();
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::EN::DeleteTracesFromAtree

=head1 DESCRIPTION

Deletes all traces (nodes with tag '-NONE-') from the a-tree.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
