package Treex::Block::T2T::SelectCompatibleTlemmaFormeme;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $tm_lemmas   = $tnode->get_attr('translation_model/t_lemma_variants');
    my $tm_formemes = $tnode->get_attr('translation_model/formeme_variants');

    foreach my $tm_lemma (@$tm_lemmas) {
        my $found = 0;
        foreach my $tm_formeme (@$tm_formemes) {
            if ( $self->compatible( $tm_lemma->{pos}, $tm_formeme->{formeme} ) ) {
                $tnode->set_t_lemma( $tm_lemma->{t_lemma} );
                $tnode->set_t_lemma_origin( $tm_lemma->{origin} . '|1st-compatible' );
                $tnode->set_formeme( $tm_formeme->{formeme} );
                $tnode->set_formeme_origin( $tm_formeme->{origin} . '|1st-compatible' );
                $found = 1;
                last;
            }
        }
        last if ($found);
    }
}

sub compatible {
    my ( $self, $pos, $formeme ) = @_;

    return 1 if ( $pos eq 'verb'                       and $formeme =~ /^v/ );
    return 1 if ( $pos =~ /^(noun|adj|num)$/           and $formeme =~ /^n/ );
    return 1 if ( $pos =~ /^(adj|num)$/                and $formeme =~ /^adj/ );
    return 1 if ( $pos eq 'adv'                        and $formeme =~ /^adv/ );
    return 1 if ( $pos =~ /^(conj|part|int|punc|sym)$/ and $formeme eq 'x' );

    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::SelectCompatibleTlemmaFormeme

=head1 DESCRIPTION

Selecting 1st compatible t-lemma & formeme pair, based on the POS of t-lemma and the formeme.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

    
