package Treex::Block::T2T::EN2CS::AddRelpronBelowRc;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    RELCLAUSE:
    foreach my $rc_head ( grep { $_->formeme =~ /rc/ } $t_root->get_descendants ) {

        # Skip verbs with subject (i.e. child in nominative)
        #        next RELCLAUSE if any { $_->formeme =~ /1/ } $rc_head->get_echildren();

        # !!! pozor: klauze, ktere byly relativni uz predtim, akorat
        # nemely zajmeno ('the man I saw'), by se mely zpracovavat stejne
        # Skipping clauses which were relative also on the source side
        my $src_tnode = $rc_head->src_tnode;
        next RELCLAUSE if !$src_tnode;
        next RELCLAUSE if $src_tnode->formeme =~ /rc/;

        # Grammatical antecedent is typically the nominal parent of the clause
        my ($gram_antec) = $rc_head->get_eparents;
        next RELCLAUSE if !$gram_antec;
        next RELCLAUSE if $gram_antec->formeme !~ /^n/;

        # Create new t-node
        my $relpron = $rc_head->create_child(
            {   nodetype         => 'complex',
                functor          => '???',
                formeme          => 'n:1',
                t_lemma          => 'který',
                t_lemma_origin   => 'Add_relpron_below_rc',
                'gram/sempos'    => 'n.pron.indef',
                'gram/indeftype' => 'relat',

                #TODO this does not work since moved to Treex
                #'coref_gram.rf'  => [ $gram_antec->id ],
            }
        );
        $relpron->set_deref_attr( 'coref_gram.rf', [$gram_antec] );

        $relpron->shift_before_subtree($rc_head);
    }
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::AddRelpronBelowRc

Generating new t-nodes corresponding to relative pronoun 'ktery' below roots
of relative clauses, whose source-side counterparts were not relative
clauses (e.g. when translatin an English gerund to a Czech relative
clause ). Grammatical coreference is filled too.

=back

=cut

# Copyright 2009 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
