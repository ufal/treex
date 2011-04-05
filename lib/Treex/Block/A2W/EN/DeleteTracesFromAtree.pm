package Treex::Block::A2W::EN::DeleteTracesFromAtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_zone {
    my ( $self, $zone ) = @_;

    my %a2t;
    foreach my $tnode ($zone->get_ttree->get_descendants()) {
        foreach my $anode ($tnode->get_anodes) {
            push @{$a2t{$anode}}, $tnode;
        }
    }
    foreach my $anode ($zone->get_atree->get_descendants()) {
        if ($anode->tag eq '-NONE-') {
            foreach my $child ($anode->get_descendants) {
                $child->set_parent($anode->get_parent);
            }
            foreach my $tnode (@{$a2t{$anode}}) {
                if ($tnode->get_lex_anode && $tnode->get_lex_anode eq $anode) {
                    $tnode->set_lex_anode(undef);
                }
                else {
                    my @new_aux_anodes = grep { $_ ne $anode } $tnode->get_aux_anodes;
                    $tnode->set_aux_anodes(@new_aux_anodes);
                }
            }
            $anode->remove;
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::EN::DeleteTracesFromAtree

=head1 DESCRIPTION

Deletes all traces (nodes with tag '-NONE-') from the a-tree.
The lex.rf and aux.rf links from t-tree are also deleted.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
