package Treex::Block::T2T::EN2CS::TrLFemaleSurnames;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;
    return if ( $cs_tnode->gram_gender || '' ) ne 'fem';
    my $en_tnode = $cs_tnode->src_tnode    or return;
    my $n_node   = $en_tnode->get_n_node() or return;
    my $n_type   = $n_node->get_attr('ne_type');
    return if $n_type ne 'ps';
    my $cs_lemma = $cs_tnode->t_lemma;
    return if $cs_lemma =~ /[áí]$/;
    $cs_lemma =~ s/([cs])ka$/$1ká/ or $cs_lemma =~ s/[oa]?$/ová/;
    $cs_tnode->set_t_lemma($cs_lemma);
    $cs_tnode->set_t_lemma_origin('Translate_L_female_surnames');
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
