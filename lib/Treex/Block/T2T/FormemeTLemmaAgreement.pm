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
    my ( $self, $logpa, $logpb ) = @_;

    if ($self->fun eq "AM-Log-P") {
        # arithmetic mean of log probabilities
        # a(log(P(a),log(P(b))) = (log(P(a) + log(P(b))) / 2
        return ($logpa + $logpb) / 2;
    } elsif ($self->fun eq "Log-AM-P") {
        # log of arithmetic mean of probabilities
        # log(a(P(a), P(b))) = log((P(a) + P(b)) / 2)
        #                    = log(P(a) + P(b)) - log(2)
        return log(exp($logpa) + exp($logpb)) - log(2);
    } elsif ($self->fun eq "Log-GM-P") {
        # log of geometric mean of probabilities
        # log(g(P(a), P(b))) = log(sqrt(P(a) * P(b)))
        #                    = log(sqrt(exp(log(P(a)) + log(P(b)))))
        return log(sqrt(exp($logpa + $logpb)));
    } elsif ($self->fun eq "GM-Log-P") {
        # geometric mean of log probabilities
        return -sqrt($logpa * $logpb);
    } elsif ($self->fun eq "Log-HM-P") {
        # log of harmonic mean of probabilities
        # log(h(P(a), P(b))) = log(2 * P(a) * P(b) / (P(a) + P(b)))
        #                    = log(2) + log(P(a)) + log(P(b)) - log(P(a) + P(b))
        return log(2) + $logpa + $logpb - log(exp($logpa) + exp($logpb));
    } elsif ($self->fun eq "HM-Log-P") {
        # harmonic mean of log probabilities
        return 2 * $logpa * $logpb / ($logpa + $logpb);
    } else {
        die "invalid function name: ".$self->fun;
    }
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $t_lemma;
    my $t_lemma_origin;
    my $formeme;
    my $formeme_origin;

    my $best_score = 0+"-inf";

    my $t_lemma_variants_rf = $tnode->get_attr('translation_model/t_lemma_variants');
    my $formeme_variants_rf = $tnode->get_attr('translation_model/formeme_variants');

    my $num_alts = 0;

    foreach my $t_lemma_variant (@$t_lemma_variants_rf) {
        foreach my $formeme_variant (@$formeme_variants_rf) {
            if ($self->agree($t_lemma_variant->{pos},
                             $formeme_variant->{formeme})) {
                my $t_lemma_logprob = $t_lemma_variant->{logprob};
                my $formeme_logprob = $formeme_variant->{logprob};
                my $score = $self->compute_score($t_lemma_logprob,
                                                 $formeme_logprob);
                ++$num_alts;
                if ($score > $best_score) {
                    $best_score = $score;
                    $t_lemma = $t_lemma_variant->{t_lemma};
                    $t_lemma_origin = $t_lemma_variant->{origin};
                    $formeme = $formeme_variant->{formeme};
                    $formeme_origin = $formeme_variant->{origin};
                }
            }
        }
    }

    my $before = $tnode->t_lemma."/".($tnode->formeme // "");

    if (!$num_alts) {
        print STDERR "T2T::FormemeTLemmaAgreement: didn't find a congruous pair; keeping $before\n";
        return;
    }

    my $after = $t_lemma."/".$formeme;

    if ($before ne $after) {
        print STDERR "T2T::FormemeTLemmaAgreement: $before ==> $after  [$num_alts alternatives]\n";
    }

    $tnode->set_attr('t_lemma', $t_lemma );
    $tnode->set_attr('t_lemma_origin', $t_lemma_origin );
    $tnode->set_attr('formeme', $formeme );
    $tnode->set_attr('formeme_origin', $formeme_origin );
    my $a_node = $tnode->get_lex_anode() or return;
    $a_node->set_attr('lemma', $t_lemma );

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
