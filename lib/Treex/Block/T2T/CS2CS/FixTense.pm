package Treex::Block::T2T::CS2CS::FixTense;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

use Treex::Tool::Lexicon::CS;
use Treex::Tool::Lexicon::EN;

sub fix {
    my ( $self, $t_node ) = @_;

    # fix only verbs
    if ( $t_node->formeme !~ /^v/) {
        return;
    }

    # get the en node
    my $ennode = $t_node->wild->{'deepfix_info'}->{'ennode'};
    if ( !defined $ennode || $ennode->formeme !~ /^v/) {
        return;
    }
    
    # get the lex node
    my $lexnode = $t_node->wild->{'deepfix_info'}->{'lexnode'};
    if( !defined $lexnode ) {
        return;
    }

    # get the tenses
    my $tense = $t_node->gram_tense;
    my $entense = $ennode->gram_tense;
    my $entensehash = $ennode->wild->{tense};

    # there is no point switching to 'nil'
    if ( !$entense || $entense eq 'nil' ) {
        return;
    }

    if ( $self->magic =~ /dry_run/ ) {
        # only print out what would be done
        my $info_before = $tense . '(' . $t_node->gram_verbmod . ',' . $t_node->gram_diathesis . ')';
        my $info_after = $entense . '(' . $ennode->gram_verbmod . ',' . $ennode->gram_diathesis . ')';
        if ( $info_before ne $info_after ) {
            $self->change_anode_attribute($lexnode, 'form', $lexnode->form . '_' . $info_before . '->' . $info_after, 1);
        }
        return;
    }

    # if the tenses are already identical, there is nothing to fix
    if ( $tense eq $entense ) {
        return;
    }

    if ( $self->magic =~ /fixall/ ) {
        # skip further checks
        $self->switch_tense($t_node, $tense, $entense);
        return;
    }

    # if the Czech tense is 'nil', there is probably a good reason for that
    if ( !$tense || $tense eq 'nil' ) {
        return;
    }

    # fix only ind
    if ( $ennode->gram_verbmod ne 'ind' || $t_node->gram_verbmod ne 'ind') {
        return;
    }

    # don't fix 'that' (danger of reported speech tense shifting)
    if ( (any { $_->lemma eq 'that' } $ennode->get_aux_anodes)
        && $entense eq 'ant'
        && !$entensehash->{perf}    
    ) {
        return;
    }

    # don't fix 'X said (ant)' (danger of reported speech tense shifting)
    # but do fix if tense is Present Perfect or Past Perfect
    my $parent_is_past_dicendi = any {
        defined $_->t_lemma
        && Treex::Tool::Lexicon::EN::is_dicendi_verb($_->t_lemma)
        && $_->gram_tense eq 'ant'
    } $ennode->get_eparents;
    if ( $parent_is_past_dicendi
        && $entense eq 'ant'
        && !$entensehash->{perf}
    ) {
        return;
    }

    # don't fix 'if'/'when' (conditionals are quite complicated)
    if (
        ( any { $_->lemma =~ /^if|when$/ } $ennode->get_aux_anodes )
        || ( any { defined $_->t_lemma && $_->t_lemma =~ /^if|when$/ }
            $ennode->get_children )
    ) {
        return;
    }

    # do not fix
    # if the tense to switch to is sim
    # and just one of the diathesis values is act
    if ( $entense eq 'sim'
        && $ennode->gram_diathesis ne $t_node->gram_diathesis
        && (any { $_ eq 'act' } ($ennode->gram_diathesis,
                $t_node->gram_diathesis))
    ) {
        return;
    }

    # passed all the checks: switch the tense!
    $self->switch_tense($t_node, $tense, $entense);

    return;
}

sub switch_tense {
    my ($self, $t_node, $from, $to) = @_;

    my $msg = "($from>$to) " . $self->tnode_sgn($t_node) . ': ';

    my $modal = $t_node->gram_deontmod ne 'decl';
    
    # passives have to be treated specially
    if ( !$modal && $t_node->gram_diathesis eq 'pas' ) {
        my $verb = $self->find_verb($t_node);
        $t_node->set_gram_tense($to);
        if ( $to eq 'ant' ) {
            $msg .= $self->set_tense_ant($verb);
        }
        elsif ( $to eq 'sim' ) {
            $msg .= $self->set_tense_sim($verb);
        }
        elsif ( $to eq 'post' ) {
            $msg .= $self->set_tense_sim($verb);
        }
    }
    
    # passives with modals and non-passives are all processed in the same way
    else {

        # get rid of old tense
        if ( $from eq 'post' ) {
            $msg .= $self->remove_tense_post($t_node);
        }
        elsif ( $from eq 'ant' ) {
            $msg .= $self->remove_tense_ant($t_node);
        }

        # find the verb to fix
        my $verb = $modal ?
            $self->find_verb($t_node)
            : $t_node->wild->{'deepfix_info'}->{'lexnode'};
        
        # switch to new tense
        $t_node->set_gram_tense($to);
        if ( $to eq 'ant' ) {
            $msg .= $self->set_tense_ant($verb);
        }
        elsif ( $to eq 'sim' ) {
            $msg .= $self->set_tense_sim($verb);
        }
        elsif ( $to eq 'post' ) {
            if ( $t_node->gram_aspect eq 'cpl' && !$modal ) {
                # "poletí"
                $msg .= $self->set_tense_sim($verb);
            }
            else {
                # "bude letět"
                $msg .= $self->set_tense_post($verb);
            }
        }
    }

    $self->logfix("Tense $msg");

    return;
}

# delete "budu" if it is present...
sub remove_tense_post {
    my ($self, $t_node) = @_;

    my $msg = '';

    my $verb = $t_node->wild->{'deepfix_info'}->{'lexnode'};
    my $budu = first { $_->lemma eq 'být' && $_->form =~ /^(ne)?bud/ }
    $t_node->get_aux_anodes( {ordered => 1} );
    if ( defined $budu ) {
        my $number = $self->get_node_tag_cat($budu, 'num');
        my $person = $self->get_node_tag_cat($budu, 'pers');
        my $negation = $self->negation_xor (
            $self->get_node_tag_cat($budu, 'neg'),
            $self->get_node_tag_cat($verb, 'neg')
        );
        $self->change_anode_attribute($verb, 'tag:num',  $number, 1);
        $self->change_anode_attribute($verb, 'tag:pers', $person, 1);
        $self->change_anode_attribute($verb, 'tag:neg', $negation, 1);
        $msg = $self->remove_anode( $budu );
    }

    return $msg;
}

# used to merge negation on two nodes into one
sub negation_xor {
    my ($self, $neg1, $neg2) = @_;

    my $num_of_negated = scalar( grep { $_ eq 'N' } ($neg1, $neg2) );
    if ( $num_of_negated == 1 ) {
        # one negation
        return 'N';
    }
    else {
        # no negation or double negation
        return 'A';
    }
}

# delete "jsem" if it is present...
sub remove_tense_ant {
    my ($self, $t_node) = @_;

    my $msg = '';

    my $verb = $t_node->wild->{'deepfix_info'}->{'lexnode'};
    my $jsem = first { $_->lemma eq 'být' && $_->form =~ /^js/ }
    $t_node->get_aux_anodes( {ordered => 1} );
    if ( defined $jsem ) {
        my $number = $self->get_node_tag_cat($jsem, 'num');
        my $person = $self->get_node_tag_cat($jsem, 'pers');
        $self->change_anode_attribute($verb, 'tag:num',  $number, 1);
        $self->change_anode_attribute($verb, 'tag:pers', $person, 1);
        $msg = $self->remove_anode( $jsem );
    }

    return $msg;
}

my %auxfuture_numpersneg2form = (
    'S1A' => 'budu',
    'S2A' => 'budeš',
    'S3A' => 'bude',
    'P1A' => 'budeme',
    'P2A' => 'budete',
    'P3A' => 'budou',
    'S1N' => 'nebudu',
    'S2N' => 'nebudeš',
    'S3N' => 'nebude',
    'P1N' => 'nebudeme',
    'P2N' => 'nebudete',
    'P3N' => 'nebudou',
);

# change the verb tense to future
sub set_tense_post {
    my ($self, $verb) = @_;

    my $msg = '';
    my $person = $self->get_node_tag_cat($verb, 'person');
    if ( $person !~ /^[123]$/ ) {
        $person = '3';
    }
    my $number = $self->get_node_tag_cat($verb, 'number');
    if ( $number !~ /^[SP]$/ ) {
        $number = 'S';
    }
    my $voice = $self->get_node_tag_cat($verb, 'voice');
    if ( $voice !~ /^[AP]$/ ) {
        $voice = 'A';
    }
    my $negation = $self->get_node_tag_cat($verb, 'negation');
    # TODO: full generation according to AddAuxVerbCompoundFuture
    # set the main verb to infinitive

    $self->change_anode_attribute( $verb, 'form',
        Treex::Tool::Lexicon::CS::truncate_lemma($verb->lemma, 1), 1);
    $msg .= $self->change_anode_attribute( $verb, 'tag', 'Vf--------A----' );
    # and add auxiliary 'být'
    my $form = $auxfuture_numpersneg2form{ $number.$person.$negation };
    my $tag = 'VB-' . $number . '---' . $person . 'F-' . $negation . 'A---';
    my $budu = $verb->create_child( {
            'lemma' => 'být',
            'form'  => $form,
            'afun'  => 'AuxV',
            'tag'   => $tag,
        });
    $budu->shift_before_node($verb);

    return $msg;
}

my %auxpast_numberperson2form = (
    'S1' => 'jsem',
    'S2' => 'jsi',
    'P1' => 'jsme',
    'P2' => 'jste',
);

# change the verb tense to past
sub set_tense_ant {
    my ($self, $verb) = @_;

    my $msg = '';
    my $person = $self->get_node_tag_cat($verb, 'person');
    if ( $person !~ /^[123]$/ ) {
        $person = '3';
    }
    my $number = $self->get_node_tag_cat($verb, 'number');
    if ( $number !~ /^[SP]$/ ) {
        $number = 'S';
    }
    my $gender = $self->get_node_tag_cat($verb, 'gender');
    if ( $gender =~ /^[X-]$/ ) {
        # the correct gender will be set according to the subject...
        $gender = 'M';
    }
    my $voice = $self->get_node_tag_cat($verb, 'voice');
    if ( $voice !~ /^[AP]$/ ) {
        $voice = 'A';
    }
    $msg .= $self->change_anode_attributes( $verb, {
            'tag:tense' => 'R',
            'tag:subpos' => 'p',
            'tag:gender' => $gender,
            'tag:person' => 'X',
            'tag:number' => $number,
            'tag:voice'  => $voice,
        });
    if ( $person ne '3' ) {
        my $form = $auxpast_numberperson2form{ $number.$person };
        my $tag = 'VB-' . $number . '---' . $person . 'P-AA---';
        my $jsem = $verb->create_child( {
                'lemma' => 'být',
                'form'  => $form,
                'afun'  => 'AuxV',
                'tag'   => $tag,
            });
        # TODO before or after?
        $jsem->shift_before_node($verb);
    }

    return $msg;
}

# change the verb tense to present
sub set_tense_sim {
    my ($self, $verb) = @_;

    # handle person and number
    my $person = $self->get_node_tag_cat($verb, 'person');
    if ( $person !~ /^[123]$/ ) {
        $person = '3';
    }
    my $number = $self->get_node_tag_cat($verb, 'number');
    if ( $number !~ /^[SP]$/ ) {
        $number = 'S';
    }
    my $voice = $self->get_node_tag_cat($verb, 'voice');
    if ( $voice !~ /^[AP]$/ ) {
        $voice = 'A';
    }
    # TODO: switch lemma from dokonavý to nedokonavý
    # regenerate the node
    my $msg = $self->change_anode_attributes( $verb, {
            'tag:tense' => 'P',
            'tag:subpos' => 'B',
            'tag:gender' => '-',
            'tag:person' => $person,
            'tag:number' => $number,
            'tag:voice'  => $voice,
        });

    return $msg;
}

sub find_verb {
    my ($self, $t_node) = @_;

    # find the first verb that is not 'by'
    my $result = ( first { $_->tag =~ /^V[^c]/ }
        $t_node->get_anodes( { ordered => 1 } ) )
    // $t_node->wild->{'deepfix_info'}->{'lexnode'};

    return $result;
}


1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::FixTense

=head1 DESCRIPTION

Usually, the Czech tense should match the English tense. This block tries to fix
that.

We try not to fix conditionals and reported speech. We also do not fix passive
if the target tense is 'sim', as this is often expressed by active 'ant' in
Czech (or in other ways).

The generative parts are adapted from L<T2A::CS::AddAuxVerbCompoundPast>
and L<T2A::CS::AddAuxVerbCompoundFuture>.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.


