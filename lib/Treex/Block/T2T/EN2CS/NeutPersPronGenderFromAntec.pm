package Treex::Block::T2T::EN2CS::NeutPersPronGenderFromAntec;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my ($t_antec) = $tnode->get_coref_text_nodes();
    if ( ( $tnode->gram_gender || "" ) eq 'neut' && defined $t_antec ) {
        my $gender_antec = $t_antec->gram_gender;
        if ( defined $gender_antec and $gender_antec ne 'neut' ) {
            $tnode->set_gram_gender($gender_antec);
        }
    }
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::NeutPersPronGenderFromAntec

PersPron originating in English it/its gets in Czech its
gender from its antecedent ('... criticised the party because of its...').

=back

=cut

# Copyright 2010-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
