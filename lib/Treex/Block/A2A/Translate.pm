package Treex::Block::A2A::Translate;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::W2W::Translate';

has wild_name => ( is => 'rw', isa => 'Str', default => 'translation' );

override '_build_translator' => sub {
    my $self = shift;

    my $translator = super();
    $translator->set_align(1);

    return $translator;
};

override '_get_translation' => sub {
    my ( $self, $sentence ) = @_;

    return $self->_translator->translate_align($sentence);
};

override '_set_translation' => sub {
    my ( $self, $translation_result, $zone ) = @_;

    my $translation = $translation_result->{translation};
    if ( $self->SUPER::_set_translation( $translation, $zone ) ) {

        # success
        # sentence has already been set in SUPER

        # precompute node positions
        my @nodes = $zone->get_atree()->get_root()->get_descendants(
            { ordered => 1 }
        );
        my %position2node = ();
        my $length        = 0;
        my $max           = 0;
        foreach my $node (@nodes) {

            # store position
            $position2node{$length} = $node;
            $max = $length;

            # move on
            $length += length $node->form;
            if ( !$node->no_space_after ) {
                $length++;
            }
        }

        # store the translations
        my $id = $self->target_language . '_' . $self->target_selector;
        foreach my $aligninfo ( @{ $translation_result->{align} } ) {

            my $word     = $aligninfo->{word};
            my $position = $aligninfo->{position};

            # normalize position;
            # should not be needed, but should not die on this either...
            if ( $position > $max ) {
                log_warn "Position $position for '$word' not matched, have to adjust...";
                $position = $max;
            }
            else {
                while ( !defined $position2node{$position} ) {
                    log_warn "Position $position for '$word' not matched, have to adjust...";
                    $position++;
                }
            }

            # set the wild attribute
            my $node = $position2node{$position};
            if ( defined $node->wild->{ $self->wild_name }->{$id} ) {
                $node->wild->{ $self->wild_name }->{$id} .= " $word";
            }
            else {
                $node->wild->{ $self->wild_name }->{$id} = $word;
            }

            # log_info $node->form . ': ' . $word;
        }

        return 1;
    }
    else {

        # failure
        # log_warn has already been called in SUPER
        return 0;
    }

};

1;

=head1 NAME 

Treex::Block::A2A::Translate

Translates the sentence, including individual a-nodes, using Google Translate.

=head1 DESCRIPTION

Not only sets the full sentence as L<Treex::Block::W2W::Translate>, but also
sets translations of individual a-nodes, using the alignment provided by Google
Translate.

The translations are stored into wild attributes of the nodes - by default into
C<node-&gt;wild-&gt;{translation}-&gt;{language_selector}>,
e.g. C<node-&gt;wild-&gt;{translation}-&gt;{en_GT}> if default target language
and selector are used.

Otherwise is similar to L<Treex::Block::W2W::Translate>.

Uses L<Treex::Tool::GoogleTranslate::APIv1>.

=head1 SYNOPSIS
 
 # translate all Bulgarian sentences in the file to English, into en_GT zone,
 # storing the translation of each individual node into
 # $node->wild{translation}->{en_GT}
 treex -s A2A::Translate language=bg -- bg_file.treex.gz

 # translate to Czech, to cs_GOOGLE selector
 treex -s A2A::Translate language=bg target_language=cs target_selector=GOOGLE -- bg_file.treex.gz

 # translate only first 5 sentences
 treex -s A2A::Translate language=bg sid='s1 s2 s3 s4 s5' -- bg_file.treex.gz

=head1 PARAMETERS

=over

=item wild_name

The name of the wild attribute to store the translations in on a-nodes.
The default is C<translation>.

The only added attribute wrt L<Treex::Block::W2W::Translate>.

=item language

Source language. Required.

=item target_language

Defaults to C<en>.

=item target_selector

Defaults to C<GT>.

=item sid

List of sentence ids to translate, separated by spaces.
If set, only the sentences with the given ids will be translated.
Defaults to C<undef> - all sentences are translated by default.

=item auth_token

See L<Treex::Block::W2W::GoogleTranslate::APIv1/auth_token>.

=item auth_token_in_file

See L<Treex::Block::W2W::GoogleTranslate::APIv1/auth_token_in_file>.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

