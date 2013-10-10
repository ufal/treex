package Treex::Block::HamleDT::Transform::StanfordCopulas;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $cop) = @_;

    my ($pnom) = grep { $_->afun eq 'Pnom' }
        $cop->get_children({ordered => 1});
    if ( defined $pnom ) {
        # types
        $pnom->set_conll_deprel($cop->conll_deprel);
        $cop->set_conll_deprel('cop');
        # rehanging
        $pnom->set_parent($cop->get_parent);
        $cop->set_parent($pnom);
        foreach my $child (
            grep { $_->conll_deprel ne 'cc' && $_->conll_deprel ne 'conj' }
                $cop->get_children
        ) {
            $child->set_parent($pnom);
        }

    }

    return;
}

1;

=head1 NAME 

Treex::Block::HamleDT::Transform::StanfordCopulas -- rehang and relabel copulas according to
Standford Dependencies style.

=head1 DESCRIPTION

A copular verb (identified by having a nominal predicate as a child)
becomes a dependent of the nominal predicate (identified by the C<Pnom> afun)
and gets labelled by the C<cop> type (stored in C<conll/deprel>).

The children of the copular verb are processed i the follwoing way:

=over

=item the (first) nominal predicate becomes the new head

=item coordinaton conunctions (C<cc> type) and conjuncts (C<conj> type) stay as
dependents of the copular verb

=item all other children become dependents of the new head

=back 

(To be used as post-processing in the conversion pipeline, i.e. after having
converted coordinations to SD style and stored SD types into C<conll/deprel>,
but still having afuns stored in the C<afun> attributes.)

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

