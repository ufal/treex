package Treex::Block::T2T::CS2EN::RearrangeNounCompounds;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;

    if ($tnode->formeme eq "n:attr") {
        my $par = $tnode->get_parent;
        if (defined $par->formeme && $par->formeme =~ /^n:.+\+X/) {
            $par->shift_after_subtree($tnode, {without_children=>1});
        }
    }
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2EN::RearrangeNounCompounds

=head1 DESCRIPTION

A block to swap or rearrange NP compounds, e.g. "účet GMail" -> "Gmail account".

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
