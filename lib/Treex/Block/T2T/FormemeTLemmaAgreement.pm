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

    return 0;
}


sub compute_score {
    my ( $self, $logpa, $nnda, $logpb, $nndb) = @_;
    my $score = undef;

    if ($self->fun =~ /^AM-Log-P/) {
        # arithmetic mean of log probabilities
        # a(log(P(a),log(P(b))) = (log(P(a) + log(P(b))) / 2
        $score = ($logpa + $logpb) / 2;
    } elsif ($self->fun =~ /^Log-AM-P/) {
        # log of arithmetic mean of probabilities
        # log(a(P(a), P(b))) = log((P(a) + P(b)) / 2)
        #                    = log(P(a) + P(b)) - log(2)
        $score = log(exp($logpa) + exp($logpb)) - log(2);
    } elsif ($self->fun =~ /^Log-GM-P/) {
        # log of geometric mean of probabilities
        # log(g(P(a), P(b))) = log(sqrt(P(a) * P(b)))
        #                    = log(sqrt(exp(log(P(a)) + log(P(b)))))
        $score = log(sqrt(exp($logpa + $logpb)));
    } elsif ($self->fun =~ /^GM-Log-P/) {
        # geometric mean of log probabilities
        $score = -sqrt($logpa * $logpb);
    } elsif ($self->fun =~ /^Log-HM-P/) {
        # log of harmonic mean of probabilities
        # log(h(P(a), P(b))) = log(2 * P(a) * P(b) / (P(a) + P(b)))
        #                    = log(2) + log(P(a)) + log(P(b)) - log(P(a) + P(b))
        $score = log(2) + $logpa + $logpb - log(exp($logpa) + exp($logpb));
    } elsif ($self->fun =~ /^HM-Log-P/) {
        # harmonic mean of log probabilities + edge cases
        return 0 if ($logpa == 0 or $logpb == 0);        
        $score = 2 * $logpa * $logpb / ($logpa + $logpb);
    } else {
        die "invalid function name: ".$self->fun;
    }

    if ($self->fun =~ /-W$/) {
        my $wa = $logpa < 0 ? $nnda/-$logpa : 1;
        my $wb = $logpb < 0 ? $nndb/-$logpb : 1;
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
                    $t_lemma_origin = $t_lemma_variant->{origin};
                    $formeme = $formeme_variant->{formeme};
                    $formeme_origin = $formeme_variant->{origin};
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
        $tnode->set_attr('t_lemma', $t_lemma );
        $tnode->set_attr('t_lemma_origin', $t_lemma_origin . "--FormemeTLemmaAgreement $before -> $after");
        $tnode->set_attr('formeme', $formeme );
        $tnode->set_attr('formeme_origin', $formeme_origin . "--FormemeTLemmaAgreement $before -> $after");
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

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
