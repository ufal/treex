package Treex::Block::T2A::EN::AddAuxVerbModalTense;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddAuxVerbModalTense';

override '_build_gram2form' => sub {

    return {
        'ind' => {
            'sim' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'can',
                'poss_ep' => 'can',
                'vol'     => 'want to',
                'deb'     => 'must',
                'deb_ep'  => 'must',
                'hrt'     => 'have to',
                'fac'     => 'am able to',
                'perm'    => 'may',
                'perm_ep' => 'may',
            },
            'ant' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'could',
                'poss_ep' => 'can have',
                'vol'     => 'wanted to',
                'deb'     => 'had to',
                'deb_ep'  => 'must have',
                'hrt'     => 'had to',
                'fac'     => 'was able to',
                'perm'    => 'could',
                'perm_ep' => 'may have',
            },
            'post' => {
                ''     => 'will',
                'decl' => 'will',
                'poss' => 'will be able to',
                'vol'  => 'will want to',
                'deb'  => 'will have to',
                'hrt'  => 'will have to',
                'fac'  => 'will be able to',
                'perm' => 'will be able to',
            },
        },
        'cdn' => {
            'sim' => {
                ''        => 'would',
                'decl'    => 'would',
                'poss'    => 'would be able to',
                'poss_ep' => 'could',
                'vol'     => 'would want to',
                'deb'     => 'would have to',
                'deb_ep'  => 'must',
                'hrt'     => 'would have to',
                'fac'     => 'would be able to',
                'perm'    => 'would be able to',
                'perm_ep' => 'might',
            },
            'ant' => {
                ''        => 'would have',
                'decl'    => 'would have',
                'poss'    => 'would have been able to',
                'poss_ep' => 'could have',
                'vol'     => 'would have wanted to',
                'deb'     => 'would have had to',
                'deb_ep'  => 'must have',
                'hrt'     => 'would have had to',
                'fac'     => 'would have been able to',
                'perm'    => 'would have been able to',
                'perm_ep' => 'might have',
            },
            'post' => {
                ''     => 'would',
                'decl' => 'would',
                'poss' => 'would be able to',
                'vol'  => 'would want to',
                'deb'  => 'would have to',
                'hrt'  => 'would have to',
                'fac'  => 'would be able to',
                'perm' => 'would be able to',
            },
        },
    };
};

my %LEMMA_TRANSFORM = (
    'am'    => 'be',
    'could' => 'can',
    'was'   => 'be',
    'might' => 'may',
    'had'   => 'have',
    'would' => 'will',
);

my %FORM_TRANSFORM = (
    'am' => {
        '1' => {
            'P' => 'are',
        },
        '2' => {
            'S' => 'am',
        },
        '3' => {
            'S' => 'is',
        },
    },
    'want' => {
        '3' => {
            'S' => 'wants',
        },
    },
    'have' => {
        '3' => {
            'S' => 'has',
        },
    },
    'was' => {
        '1' => {
            'P' => 'were',
        },
        '2' => {
            'S' => 'were',
            'P' => 'were',
        },
        '3' => {
            'P' => 'were',
        },
    },
);

# get lemma of the auxiliary, given 1.person sg. in current tense
sub _get_lemma {
    my ($form) = @_;
    return $LEMMA_TRANSFORM{$form} ? $LEMMA_TRANSFORM{$form} : $form;
}

# get form of the auxiliary, adjusted for the given person and number
sub _get_form {
    my ( $form, $person, $number ) = @_;

    return (
        $FORM_TRANSFORM{$form}
            and $FORM_TRANSFORM{$form}->{$person}
            and $FORM_TRANSFORM{$form}->{$person}->{$number}
        )
        ? $FORM_TRANSFORM{$form}->{$person}->{$number} : $form;
}

override '_postprocess' => sub {
    my ( $self, $verbforms_str, $anodes ) = @_;

    # change morphology of the 1st auxiliary
    my ($afirst) = $anodes->[0];
    my ( $person, $number, $lemma ) = (
        $afirst->morphcat_person,
        $afirst->morphcat_number,
        $afirst->lemma
    );

    $afirst->set_lemma( _get_lemma($lemma) );
    $afirst->set_form( _get_form( $lemma, $person, $number ) );

    # prepare the last form for generation (past participle/infinitive)
    if ( $verbforms_str =~ /have$/ ) {    # use VBN tag
        $anodes->[-1]->set_morphcat_voice('P');
        $anodes->[-1]->set_morphcat_tense('R');
        $anodes->[-1]->set_conll_pos('VBN');
    }
    else {               # use VB tag
        $anodes->[-1]->set_morphcat_subpos('f');
        $anodes->[-1]->set_conll_pos('VB');
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddAuxVerbModalTense

=head1 DESCRIPTION

Add auxiliary expression for combined modality and tense.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
