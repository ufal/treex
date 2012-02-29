package Treex::Block::T2T::EN2CS::TrLHackNNP;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by other rules
    return if $cs_tnode->t_lemma_origin !~ /^clone/;
    my $en_tnode = $cs_tnode->src_tnode     or return;
    my $en_anode = $en_tnode->get_lex_anode or return;
    my $en_lemma = $en_tnode->t_lemma;

    if ($en_lemma =~ /^[\p{isUpper}\d]+$/
        && $en_lemma !~ /^(UN|VAT)$/
        && $en_anode->tag =~ /^NNP/
        )
    {
        $cs_tnode->set_t_lemma($en_lemma);
        $cs_tnode->set_t_lemma_origin('rule-TrLHackNNP');
        $cs_tnode->set_attr( 'mlayer_pos', 'N' );
    }
    return;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLHackNNP

Proper nouns in upper case are forced to be not translated.
This block should be deleted - it is a nasty hack (which improves BLEU).

=back

=cut

# Copyright 2012 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

