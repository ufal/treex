package Treex::Block::A2A::TranslateWithPreprocessing;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Translate';

override '_get_sentence_and_node_positions' => sub {
    my ( $self, $zone ) = @_;

    my $sentence = $zone->sentence;

    # precompute node positions
    my @nodes = $zone->get_atree()->get_root()->get_descendants(
        { ordered => 1 }
    );
    my $position = 0;
    foreach my $node (@nodes) {

        my $form = $node->no_space_after ? $node->form : $node->form . ' ';
        my $formlen = length $form;
        if ( $form =~ /^_/ ) {

            # cut out from $sentence
            my $pre = substr $sentence, 0, $position;
            # my $cutout = substr $sentence, $position. $formlen;
            my $suf = substr $sentence, ( $position + $formlen );
            $sentence = $pre . $suf;
        }
        else {

            # store position
            $self->position2node->{$position} = $node;

            # move on
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

