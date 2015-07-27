package Treex::Block::T2T::FormemeTLemmaAgreement;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has fun => ( isa => 'Str', is => 'ro', required => 1 );


sub agree {
    my ( $self, $pos, $formeme ) = @_;

    return 1 if ( $pos eq 'verb'                       and $formeme =~ /^v/ );
    return 1 if ( $pos =~ /^(noun|adj|num)$/           and $formeme =~ /^n/ );
    return 1 if ( $pos =~ /^(adj|num)$/                and $formeme =~ /^adj/ );
    return 1 if ( $pos eq 'adv'                        and $formeme =~ /^adv/ );
    return 1 if ( $pos =~ /^(conj|part|int|punc|sym)$/ and $formeme eq 'x' );
    return 1 if $pos eq 'X';

    return 0;
}


sub compute_score {
    my ( $self, $logA, $nndA, $logB, $nndB) = @_;
    my $score = undef;

    # $logA and $logB are 2-based logarithms of the probabilities:
    # A = prob(translation_A)
    # B = prob(translation_B)
    my $A = 2**$logA;
    my $B = 2**$logB;

    # "X ~= Y" means "optimizing X is equivalent to optimizing Y" (we can ignore monotonic transformations)
    if ($self->fun =~ /^AM-P/) {
        # arithmetic mean of probabilities, AM(A,B) = (A+B)/2 ~= A + B
        $score = $A + $B;
    } elsif ($self->fun =~ /^(GM-P|AM-Log-P)/) {
        # geometric mean of probabilities, GM(A,B) = sqrt(A * B) ~= A*B = 2**(logA + logB) ~= logA + logB
        $score = $logA + $logB;
    } elsif ($self->fun =~ /^GM-Log-P/) {
        # geometric mean of log probabilities, GM-log(A,B) = sqrt(logA * logB) ~= logA * logB
        # However, geometric mean of two negative numbers is positive
        # and the best $score is the highest one, so we need to take *negative* geometric mean of log probabilities.
        $score = - $logA * $logB;
    } elsif ($self->fun =~ /^HM-P/) {
        # harmonic mean of probabilities,  HM(A,B) = 2 * A * B / (A+B) ~= A*B/(A+B)
        $score = $A*$B / ($A+$B);
    } elsif ($self->fun =~ /^HM-Log-P/) {
        # harmonic mean of log probabilities + edge cases, HM-log(A,B) = 2 * logA * logB / (logA + logB)
        return 0 if ($logA == 0 or $logB == 0);
        $score = $logA * $logB / ($logA + $logB);
    } else {
        die "invalid function name: ".$self->fun;
    }

    if ($self->fun =~ /-W$/) {
        my $wa = $logA < 0 ? $nndA/-$logA : 1;
        my $wb = $logB < 0 ? $nndB/-$logB : 1;
        $score = $score * $wa * $wb;
    }
    return $score;
}

sub update_nnd {
    my ( $self, $variants_rf ) = @_;
    my $prev_logprob = undef;
    foreach my $variant (@$variants_rf) {
        if (defined $prev_logprob) {
            my $distance_to_prev = abs($variant->{logprob} - $prev_logprob);
            $variant->{nnd} = $distance_to_prev if ($distance_to_prev < $variant->{nnd});
        }
        $prev_logprob = $variant->{logprob};
    }
}

sub compute_distance_to_nearest_neighbour {
    my ( $self, $variants_rf ) = @_;

    foreach my $variant (@$variants_rf) {
        $variant->{nnd} = $variant->{logprob};
    }
    $self->update_nnd($variants_rf);
    $self->update_nnd([reverse @$variants_rf]);
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $t_lemma;
    my $t_lemma_origin;
    my $formeme;
    my $formeme_origin;
    my $mlayer_pos;

    my $best_score = 0+"-inf";

    my $t_lemma_variants_rf = $tnode->get_attr('translation_model/t_lemma_variants');
    my $formeme_variants_rf = $tnode->get_attr('translation_model/formeme_variants');

    my $num_alts = 0;

    # if there are no variants, use the one variant given by rules
    if (!$t_lemma_variants_rf or !@$t_lemma_variants_rf){
        $t_lemma_variants_rf = [ {t_lemma => $tnode->t_lemma, pos => ($tnode->get_attr('mlayer_pos') // 'X'), logprob => 0.0} ];
    }
    if (!$formeme_variants_rf or !@$formeme_variants_rf){
        $formeme_variants_rf = [ {formeme => $tnode->formeme, logprob => 0.0} ];
    }
    $self->compute_distance_to_nearest_neighbour($t_lemma_variants_rf);
    $self->compute_distance_to_nearest_neighbour($formeme_variants_rf);

    foreach my $t_lemma_variant (@$t_lemma_variants_rf) {
        foreach my $formeme_variant (@$formeme_variants_rf) {
            if ($self->agree($t_lemma_variant->{pos},
                             $formeme_variant->{formeme})) {
                my $t_lemma_logprob = $t_lemma_variant->{logprob};
                my $formeme_logprob = $formeme_variant->{logprob};
                my $t_lemma_nnd = $t_lemma_variant->{nnd};
                my $formeme_nnd = $formeme_variant->{nnd};
                my $score = $self->compute_score($t_lemma_logprob,
                                                 $t_lemma_nnd,
                                                 $formeme_logprob,
                                                 $formeme_nnd);
                ++$num_alts;
                if ($score > $best_score) {
                    $best_score = $score;
                    $t_lemma = $t_lemma_variant->{t_lemma};
                    $t_lemma_origin = $t_lemma_variant->{origin} // '';
                    $formeme = $formeme_variant->{formeme};
                    $formeme_origin = $formeme_variant->{origin} // '';
                    $mlayer_pos = $t_lemma_variant->{mlayer_pos};
                }
            }
        }
    }

    my $before = $tnode->t_lemma."/".($tnode->formeme // "");

    if (!$num_alts) {
        my $str = '';
        foreach my $t_lemma_variant (@$t_lemma_variants_rf){
            $str .= $t_lemma_variant->{t_lemma} . '#' . $t_lemma_variant->{pos} . "\n";
        }
        foreach my $formeme_variant (@$formeme_variants_rf){
            $str .= $formeme_variant->{formeme} . "\n";
        }
        log_warn("T2T::FormemeTLemmaAgreement: didn't find a congruous pair; keeping $before\n$str");
        return;
    }

    my $after = $t_lemma."/".$formeme;

    if ($before ne $after) {
        $tnode->set_t_lemma($t_lemma);
        $tnode->set_t_lemma_origin($t_lemma_origin . "--FormemeTLemmaAgreement $before -> $after");
        $tnode->set_formeme($formeme);
        $tnode->set_formeme_origin($formeme_origin . "--FormemeTLemmaAgreement $before -> $after");
        $tnode->set_attr('mlayer_pos', $mlayer_pos );
    }

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::FormemeTLemmaAgreement

=head1 DESCRIPTION

Select congruous t_lemma-formeme pairs.

=head1 PARAMETERS

=head2 fun

Which function should be used to combine the formeme and t-lemma probabilities into one score.
The possibilities are C<AM-P>, C<GM-P>, C<HM-P> (arithmetic, geometric and harmonic mean, respectively),
and  C<HM-Log-P>, C<GM-Log-P> (harmonic/geometric mean of logarithms of probabilities).
(Note that optimizing C<AM-Log-P> is equivalent to optimizing C<GM-P>, so C<AM-Log-P> is missing in the list above.)

All functions have a variant with C<-W> suffix, check the source code for its meaning.

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
