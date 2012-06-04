package Treex::Block::A2T::LA::SetFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# Fallback tables
my %FUNCTOR_FOR_AFUN = (
    Atr   => 'RSTR',
    Obj   => 'PAT',
    Sb    => 'ACT',
    Pred  => 'PRED',
    Atv   => 'COMPL',
    AtvV  => 'COMPL',
    OComp => 'EFF',
    Adv   => 'MANN',
);

my %FUNCTOR_FOR_LEMMA = (
    meuus       => 'APP',
    tuus        => 'APP',
    suus        => 'APP',
    noster      => 'APP',
    vester      => 'APP',
    nihilominus => 'CNCS',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Skip coap nodes with already assigned functors
    return if $t_node->functor;

    # Set functor, '???' marks unknown values
    $t_node->set_functor( $self->guess_functor($t_node) || '???' );
    return;
}

sub guess_functor {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;
    my ( $lemma, $afun, $tag ) = $a_node->get_attrs(qw(lemma afun tag));
    my ($t_eparent) = $t_node->get_eparents();
    my ( $p_lemma, $p_afun, $p_tag ) = ( '', '', '' );
    if ( $t_eparent && ( my $a_eparent = $t_eparent->get_lex_anode() ) ) {
        ( $p_lemma, $afun, $tag ) = $a_eparent->get_attrs(qw(lemma afun tag));
    }

    # Subjects
    if ( $afun eq 'Sb' ) {

        # Sb depending on active verbs
        return 'ACT' if $p_tag =~ /^3..[ABCDH]/;

        # Sb depending on passive verbs - not deponent (ie, with lemma ending in -or)
        return 'PAT' if $p_tag =~ /^3..[JKLMQ]/ && $p_lemma !~ /or$/;

        # ablative absolute: ACT to Sb of present participle (mediantibus rebus)
        return 'ACT' if $tag =~ /^......[FO]/ && $p_tag =~ /^2..D..[FO]/;

        # ablative absolute: PAT to Sb of past participle (praesupposita materia)
        return 'PAT' if $tag =~ /^......[FO]/ && $p_tag =~ /^2..M..[FO]/ && $p_lemma !~ /or$/;
    }

    # TODO: convert the rest of the old code in SlaA_to_SlaT::Assign_functors

    # Fallbacks
    return $FUNCTOR_FOR_LEMMA{$lemma} || $FUNCTOR_FOR_AFUN{$afun};
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::SetFunctors - guess Latin functor using hand-written rules

=head1 DESCRIPTION 

Coordination and apposition functors must be filled before using this block
(it uses effective parents and effective children).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček

Marco Passarotti 

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
