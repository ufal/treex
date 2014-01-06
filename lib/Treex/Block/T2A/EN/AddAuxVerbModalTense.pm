package Treex::Block::T2A::EN::AddAuxVerbModalTense;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %MOD_2_FORM = (

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
);

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

sub process_tnode {
    
    my ( $self, $tnode ) = @_;
    my ( $verbmod, $tense, $deontmod ) = ( $tnode->gram_verbmod, $tnode->gram_tense, $tnode->gram_deontmod // '' );

    # return if the node is not a verb
    return if ( !$verbmod );

    # find the auxiliary appropriate verbal expression for this combination of verbal modality, tense, and deontic modality
    # do nothing if we find nothing
    # TODO this should handle epistemic modality somehow. The expressions are in the array, but are ignored.
    return if ( !$MOD_2_FORM{$verbmod} or !$MOD_2_FORM{$verbmod}->{$tense} );
    my $verbform = $MOD_2_FORM{$verbmod}->{$tense}->{$deontmod};
    return if ( $verbform eq '' );

    # find the original anode
    my $anode = $tnode->get_lex_anode() or return;
    my $lex_lemma = $anode->lemma;
    my ( $person, $number ) = ( $anode->morphcat_person, $anode->morphcat_number );

    my ( $first_verbform, @verbforms ) = split / /, $verbform;

    # replace the current verb node by the first part of the auxiliary verbal expression
    $anode->set_lemma( _get_lemma($first_verbform) );
    $anode->set_form( _get_form( $first_verbform, $person, $number ) );
    $anode->set_afun('AuxV');

    # we'll use VBN for the original verb if the auxiliary verbal expression ends in 'have'
    my $use_vbn = ( $verbform =~ /have$/ );
    my $created_lex = 0;

    # add the rest (including the original verb) as "auxiliary" nodes
    foreach my $verbform ( $lex_lemma, reverse @verbforms ) {

        my $new_node = $anode->create_child();
        $new_node->shift_after_node($anode);
        $new_node->reset_morphcat();

        $new_node->set_lemma($verbform);
        $tnode->add_aux_anodes($new_node);

        # creating auxiliary part
        if ($created_lex) {
            $new_node->set_morphcat_pos('!');
            $new_node->set_form($verbform);
            $new_node->set_afun('AuxV');
        }

        # creating a new node for the lexical verb
        else {
            $new_node->set_morphcat_pos('V');
            $new_node->set_afun('Obj');
            if ($use_vbn) {    # use VBN tag
                $new_node->set_morphcat_voice('P');
                $new_node->set_morphcat_tense('R');
                $new_node->set_conll_pos('VBN');
            }
            else {             # use VB tag
                $new_node->set_morphcat_subpos('f');
                $new_node->set_conll_pos('VB');
            }
            $created_lex = 1;
        }
    }

    return;
}

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
