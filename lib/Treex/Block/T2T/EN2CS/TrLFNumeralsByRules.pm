package Treex::Block::T2T::EN2CS::TrLFNumeralsByRules;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;
    my $sempos = $cs_tnode->get_attr('gram/sempos') or return;
    return if $sempos ne 'n.quant.def';
    my $en_tnode = $cs_tnode->src_tnode or return;
    return if $en_tnode->formeme ne 'n:attr';
    $cs_tnode->set_formeme('n:attr');
    $cs_tnode->set_formeme_origin('rule-numeral');
    $cs_tnode->set_t_lemma_origin('rule-numeral');

    # delete variants
    $cs_tnode->set_attr( 'translation_model/t_lemma_variants', undef );
    $cs_tnode->set_attr( 'translation_model/formeme_variants', undef );
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLFNumeralsByRules


If succeeded, lemma and formeme are filled
and atributtes C<formeme_origin> and C<t_lemma_origin> is set to I<rule-numeral>.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
