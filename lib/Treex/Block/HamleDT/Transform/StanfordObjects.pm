package Treex::Block::HamleDT::Transform::StanfordObjects;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $predicate) = @_;

    my @objects = grep { $_->conll_deprel =~ '^[di]?obj$' } $predicate->get_children();
    if ( @objects == 1 && $objects[0]->conll_deprel eq 'obj' ) {
        $objects[0]->set_conll_deprel('dobj');
    }

    return;
}

1;

=head1 NAME 

Treex::Block::HamleDT::Transform::StanfordObjects -- relabel objects according to
Standford Dependencies style.

=head1 DESCRIPTION

If there is only one object, it is the direct object and should get C<dobj>
label instead of the more general C<obj> label. Otherwise, we do not know as of now, so we keep the label as it is.
(Probably C<obj>, but potentially some previous block might
have found out whether it is a direct or indirect object, so maybe the label is
already the correct specific one.)

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

