package Treex::Block::T2T::CS2EN::DeleteSuperfluousNodes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %TLEMMAS = map {$_ => 1} qw/
    system
    application
/;

sub process_tnode {
    my ($self, $tnode) = @_;

    return if (!$TLEMMAS{$tnode->t_lemma});

    my ($ne_child) = grep {defined $_->src_tnode->get_n_node} $tnode->get_children;

    if (defined $ne_child) {
        $ne_child->set_formeme($tnode->formeme);
        $ne_child->set_functor($tnode->functor);

        $tnode->remove({children=>'rehang'});
    }
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2EN::DeleteSuperfluousNodes

=head1 DESCRIPTION

The block fixes the following typical translations:
"systém Windows 8" -> "Windows 8"
"aplikace PowerPoint" -> "PowerPoint"

This should be removed after a treelet translation model is introduced.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
