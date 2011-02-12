package Treex::Block::T2T::EN2CS::TrLFNumeralsByRules;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $cs_troot->get_descendants() ) {
        my $sempos = $cs_tnode->get_attr('gram/sempos') or next;
        next if $sempos ne 'n.quant.def';
        my $en_tnode = $cs_tnode->get_source_tnode() or next;
        next if $en_tnode->formeme ne 'n:attr';
        $cs_tnode->set_formeme('n:attr');
        $cs_tnode->set_attr( 'formeme_origin', 'rule-numeral' );
        $cs_tnode->set_attr( 't_lemma_origin', 'rule-numeral' );

        # delete variants
        $cs_tnode->set_attr( 'translation_model/t_lemma_variants', undef );
        $cs_tnode->set_attr( 'translation_model/formeme_variants', undef );

        #my $en_tnode = $cs_tnode->get_source_tnode() or next;
        #my $cs_lemma = $cs_tnode->t_lemma;
        #my $en_lemma = $en_tnode->t_lemma;
        #print "$en_lemma\t$cs_lemma\n";
    }
    return;
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
