package Treex::Block::P2A::EN::FixCoord;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    if ($anode->afun eq 'NR' and $anode->tag eq 'CC') {
        $anode->set_afun('Coord');
        my $left_conjunct = $anode->get_children({preceding_only=>1, last_only=>1});
        my $right_conjunct = $anode->get_children({following_only=>1, first_only=>1});
        foreach my $conjunct (grep {$_} ($left_conjunct, $right_conjunct)) {
            $conjunct->set_is_member(1);
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::EN::FixCoord - heuristics for filling afun=Coord and is_member=1

=head1 DESCRIPTION

A block for fixing coordination structures in files for manual annotations generated from PTB by p2a conversion. It doesn't solve multiple conjuncts.


=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
