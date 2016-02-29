package Treex::Tool::MLFix::CS::NumberSwitcher;
use Moose;
use Treex::Core::Common;
use utf8;

use Treex::Tool::MLFix::CS::FormGenerator;

has generator => (
    is => 'rw',
    isa => 'Treex::Tool::MLFix::CS::FormGenerator',
    required => 1
);

sub try_switch_node_number {
    my ( $self, $node, $ennode ) = @_;
    
    my ( $en_form, $en_tag ) = (undef, undef);
    if ( defined $ennode ) {
        $en_form = $ennode->form;
        $en_tag = $ennode->tag;
    }

    my ( $new_tag, $new_number ) = $self->try_switch_number(
        {
            lemma => $node->lemma,
            old_form => $node->form,
            new_tag => $node->tag,
            en_form => $en_form,
            en_tag => $en_tag,
        }
    );

    return $new_tag;
}

# if the form is about to change, it might be reasonable
# to change the morphological number instead
# and keep the form intact
# Returns the best tag to be used
sub try_switch_number {
    my ( $self, $params ) = @_;

    # check required parameters
    if (!defined $params->{lemma}
        || !defined $params->{old_form}
        || !defined $params->{new_tag}
        )
    {
        log_fatal("Parameters lemma, old_form and new_tag are required!");
    }

    # generate new form if not provided in parameters
    if ( !defined $params->{new_form} ) {
        $params->{new_form} = $self->generator->get_form(
            $params->{lemma}, $params->{new_tag}
        );
    }

    # controls the returned value
    my $use_switched = 0;
    my ( $switched_tag, $switched_num, $switched_form );

    # if form is about to change or could not be generated
    if (!$params->{new_form}
        || lc( $params->{old_form} ) ne lc( $params->{new_form} )
        )
    {

        # try to switch the number
        ( $switched_tag, $switched_num ) = $self->switch_num(
            $params->{new_tag}
        );
        $switched_form = $self->generator->get_form(
            $params->{lemma}, $switched_tag
        );

        # use the switched form if it is equal to the old form
        $use_switched = (
            $switched_form
                && lc( $params->{old_form} ) eq lc($switched_form)
        );

        # if English counterpart was provided, check also
        # whether the switched number is consistent with it
        if ( $use_switched && $params->{en_tag} ) {
            $use_switched = $self->en_word_can_be_num(
                $switched_num, $params->{en_tag}, $params->{en_form}
            );
        }
    }

    # return
    if ($use_switched) {
        return ( $switched_tag, $switched_form );
    } else {
        return ( $params->{new_tag}, $params->{new_form} );
    }
}

# returns the same tag with the opposite morphological number
sub switch_num {
    my ( $self, $tag ) = @_;

    my @result;

    if ( $tag =~ /^(...)S(.+)$/ ) {
        @result = ( $1 . 'P' . $2, 'P' );
    } else {
        $tag =~ /^(...).(.+)$/;
        @result = ( $1 . 'S' . $2, 'S' );
    }

    return @result;
}

# each number has a list of tags that cannot have it;
# not 100% but reasonably reliable
my $en_num_tags_not = {
    'S' => { 'NNS' => 1, 'NNPS' => 1, 'PDT' => 1 },
    'P' => { 'NN'  => 1, 'NNP'  => 1, 'VBZ' => 1 },
};

sub en_word_can_be_num {
    my ( $self, $num, $tag, $form ) = @_;

    if ( defined $en_num_tags_not->{$num}->{$tag} ) {
        return 0;
    }
    else {
        return 1;
    }

    # TODO: also look at the form
    # You can use Treex::Tool::EnglishMorpho::Analysis to get possible tags.
    # You can use treex/lib/Treex/Tool/EnglishMorpho/exceptions/nouns*.
}

1;

=head1 NAME 

Treex::Tool::MLFix::CS::NumberSwitcher

=head1 DESCRIPTION

This package provides the C<try_switch_number> method,
which tries to switch the morphological number of a word
which form is about to be changed (by mlfix)
and decides whether to keep or switch the number.

The idea is that if we have to change the tag of a word
and the wordform is no longer consistent with it,
it might be reasonable to keep the form
and change the morphological number instead if this is possible.

=head1 METHODS

=over

=item my ($bestTag, $bestForm) = $numberSwitcher->try_switch_number($parameters)

Tries to switch the number in the tag,
and returns the switched tag if this helps to keep the form unchanged.
Otherwise, it returns the original tag.

The wordform corresponding to the tag returned is also returned.

For example, the call:

 $numberSwitcher->try_switch_number( {
    lemma => 'lahev', old_form => 'lahve', new_tag => 'NNFS1-----A----'
 } )

returns:

 ('NNFP1-----A----', 'lahve')

since it is possible to keep the wordform "lahve"
if we switch the number from singular to plural
(instead of changing the wordform to "lahev").

The method takes the following parameters:

=over

=item lemma (required)

The morphological lemma.

=item old_form (required)

The original wordform.

=item new_tag (required)

The new morphological tag.

=item new_form

The new wordform (will be generated if not provided).

=item en_tag

POS tag of a corresponding English word.

=item en_form

Wordform of a corresponding English word.
(Currently not used but to be used in future.)

=back

=item $numberSwitcher->en_word_can_be_num ($number, $tag, $form)

Determines whether the given English word
can represent the given morphological number.
The number is to be specified as 'S' for singular or 'P' for plural
(which corresponds to the number in the Czech positional tagset).
The last parameter, the wordform, is optional
(and is not currently used - TODO!).

Examples of usage:

 $numberSwitcher->en_word_can_be_num('S', 'NNS', 'dogs')
 # returns 0
 
 $numberSwitcher->en_word_can_be_num('S', 'VBZ', 'runs')
 # returns 1
 
 $numberSwitcher->en_word_can_be_num('P', 'DET', 'the')
 # returns 1
 
 $numberSwitcher->en_word_can_be_num('P', 'DET', 'a')
 # returns 1
 # (should return 0 but currently the wordform is ignored, only the tag is used)

=item my ($new_tag, $new_number) = $numberSwitcher->switch_num($tag)

If the morphological number in the tag is singular,
the method switches it to plural.
Otherwise, it is switched to singular.

Examples of usage:

 $numberSwitcher->switch_num('VB-P---3P-AA---')
 # returns ('VB-S---3P-AA---', 'S')

 $numberSwitcher->switch_num('NNFS1-----A----')
 # returns ('NNFP1-----A----', 'P')

 $numberSwitcher->switch_num('NNFD1-----A----')
 # returns ('NNFS1-----A----', 'S')

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
