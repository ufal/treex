package Treex::Block::T2T::EN2CS::TrLFNumeralsByRules;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $cs_tnode->t_lemma_origin ne 'clone';
    my $en_tnode = $cs_tnode->src_tnode or return;

    my $new_lemma = $self->translate_numeral($cs_tnode, $en_tnode);
    if (defined $new_lemma) {
        $cs_tnode->set_t_lemma($new_lemma);
        $cs_tnode->set_attr('mlayer_pos', 'C');
        $cs_tnode->set_t_lemma_origin('rule-TrLFNumeralsByRules');

        if (($cs_tnode->gram_sempos||'') eq 'n.quant.def' && $en_tnode->formeme eq 'n:attr') {
            $cs_tnode->set_formeme('n:attr');
            $cs_tnode->set_formeme_origin('rule-TrLFNumeralsByRules');
        }
    }
    return;
}

sub translate_numeral {
    my ($self, $cs_tnode, $en_tnode) = @_;
    my $en_tlemma = $en_tnode->t_lemma;

    # 1st -> 1. 2nd -> 2.
    return "$1." if $en_tlemma =~ /^(\d+)(st|nd|rd|th)$/;

    if ( $en_tlemma =~ /^\d+(,\d\d\d)*(\.\d+)?$/ ) {
        $en_tlemma =~ s/\.(\d+)$/,$1/;          # point goes to comma in Czech
        $en_tlemma =~ s/,(\d\d\d)/ $1/g;        # thousand separator is not a comma, but a space (ISO 31-0)
        $en_tlemma =~ s/^(\d) (\d\d\d)$/$1$2/;  # but for 1000-9999 no space is more common
        return $en_tlemma;
    }

    if ( $en_tlemma =~ /^(\p{isAlpha}+)-(\p{isAlpha}+)$/ ) {
        # forty-four -> 44 ( 'čtyřiačtyřicet' should be also implemented somewhere )
        my $first = Treex::Tool::Lexicon::EN::number_for($1);
        my $second = Treex::Tool::Lexicon::EN::number_for($2);
        return $first + $second if $first && $second;
    }
    return;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLFNumeralsByRules


If succeeded, lemma and formeme are filled
and atributtes C<formeme_origin> and C<t_lemma_origin> is set to
I<rule-TrLFNumeralsByRules>.

=back

=cut

# Copyright 2016 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
