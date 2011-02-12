package Treex::Block::T2T::EN2CS::TurnTextCorefToGramCoref;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';





binmode STDERR,":utf8";

sub process_bundle {

    my ( $self, $bundle ) = @_;

    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $perspron (
	grep {
	    $_->t_lemma eq "#PersPron" and $_->formeme !~ /n:1/
	} $t_root->get_descendants
	) {

	my $antec_ids_rf = $perspron->get_attr('coref_text.rf');

	# !!! ruseni koreferencnich linku vedoucich na smazane uzly by chtelo zajistit nejak lip!
	if ($antec_ids_rf and $bundle->get_document->id_is_indexed($antec_ids_rf->[0])) {
	    my $antec = $bundle->get_document->get_node_by_id($antec_ids_rf->[0]);
	    my $clause_head = _nearest_clause_head($perspron);

	    if ( $antec->formeme =~ /n:1/
                     and defined $clause_head
                         and $clause_head->t_lemma ne "být"
                             and $antec->get_parent eq $clause_head
		) {

		$perspron->set_attr('coref_gram.rf', $antec_ids_rf);
		$perspron->set_attr('coref_text.rf',undef);
	    }
	}
    }
}

sub _nearest_clause_head {
    my ($tnode) = @_;
    my $parent = $tnode->get_parent;
    while ( not( $parent->is_root ) ) {    # climbing up to the nearest clause head
	if ( $parent->is_clause_head ) {
	    return $parent;
	}
	$parent = $parent->get_parent
    }
    return undef;
}

1;

=over

=item Treex::Block::T2T::EN2CS::TurnTextCorefToGramCoref

Turn textual coreference to grammatical coreference
(related to reflexive pronouns).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
