package Treex::Block::T2T::EN2CS::TrLFemaleSurnames;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $cs_troot->get_descendants() ) {
        next if ($cs_tnode->get_attr('gram/gender')||'') ne 'fem';
        my $en_tnode = $cs_tnode->get_source_tnode() or next;
        my $n_node   = $en_tnode->get_n_node()       or next;
        my $n_type   = $n_node->get_attr('ne_type');
        next if $n_type ne 'ps';
        my $cs_lemma = $cs_tnode->t_lemma;
        next if $cs_lemma =~ /[áí]$/;
        $cs_lemma =~ s/([cs])ka$/$1ká/ or $cs_lemma =~ s/[oa]?$/ová/;
        $cs_tnode->set_t_lemma($cs_lemma);
        $cs_tnode->set_attr( 't_lemma_origin', 'Translate_L_female_surnames' );
    }
    return;
}

1;

#TODO: Prune translation_model/t_lemma_variants instead of this post-Viterbi fix

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLFemaleSurnames

Female surnames in Czech usually end with suffix I<ová> (Thather->Thatherová).
T-lemma of nodes with feminine gender which are linked
to named entity type C<ps> (surname), is changed according to this rule.

=back

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
