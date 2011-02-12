package Treex::Block::T2T::EN2CS::NeutPersPronGenderFromAntec;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_document {

    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('TCzechT');

        foreach my $neut_perspron (
            grep {
		$_->t_lemma eq "#PersPron"
		    and ($_->get_attr('gram/gender')||"") eq 'neut'
                    and defined $_->get_attr('coref_text.rf')
            } $t_root->get_descendants
            )
        {

            my $antec_id  = @{ $neut_perspron->get_attr('coref_text.rf') }[0];
            my $t_antec = $document->get_node_by_id($antec_id);

	    my $gender_antec = $t_antec->get_attr('gram/gender');
	    if (defined $gender_antec and $gender_antec ne 'neut') {
#		print "QQQ\t".$t_antec->t_lemma."\t".$bundle->get_attr('english_source_sentence')."\n";
		$neut_perspron->set_attr('gram/gender',$gender_antec);
	    }

        }
    }
}

1;

=over

=item Treex::Block::T2T::EN2CS::NeutPersPronGenderFromAntec

PersPron originating in English it/its gets in Czech its
gender from its antecedent ('... criticised the party because of its...').

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
