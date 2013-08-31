package Treex::Block::A2A::TranslateWithPreprocessing;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Translate';

override 'get_sentence_and_node_positions' => sub {
    my ( $self, $nodes ) = @_;

    # precompute node positions
    $self->set_position2node({});
    my $sentence = '';
    my $position = 0;
    foreach my $node (@$nodes) {

        # form and its length
        my $form = $node->no_space_after ? $node->form : $node->form . ' ';
        my $formlen = length $form;

        if ( $form !~ /^(_|NULL)/ ) {
            # store position
            $self->position2node->{$position} = $node;

            # move on
            $sentence .= $form;
            $position += $formlen;
        }
    }

    # get rid of remaining underscores (probably connecting compounds)
    $sentence =~ s/_/ /g;

    # log_info $sentence;
    return $sentence;
};

1;

=head1 NAME 

Treex::Block::A2A::TranslateWithPreprocessing

=head1 DESCRIPTION

Translates the sentence, including individual a-nodes, using Google Translate.

Preprocesses the sentence first, removing underscores and performing other
cleaning.

Only a mild extension to L<Treex::Block::A2A::Translate>, please see its POD
instead.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

