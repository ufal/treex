package Treex::Block::T2A::CS::ImposeRelPronAgr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    foreach my $t_relpron (
        grep {
            my $i = $_->gram_indeftype;
            defined $i
                and $i eq 'relat'
                and defined $_->get_attr('coref_gram.rf')
        } $t_root->get_descendants
        )
    {

        my $a_relpron = $t_relpron->get_lex_anode;
        my $t_antec   = @{ $t_relpron->get_deref_attr('coref_gram.rf') }[0];

        my $a_antec = $t_antec->get_lex_anode;

        if ( $t_relpron->formeme =~ /poss|attr/ ) {    # possessive relative pronouns
            $a_relpron->set_attr( 'morphcat/possgender', $a_antec->get_attr('morphcat/gender') );
            $a_relpron->set_attr( 'morphcat/possnumber', $a_antec->get_attr('morphcat/number') );
        }
        else {
            $a_relpron->set_attr( 'morphcat/gender', $a_antec->get_attr('morphcat/gender') );
            $a_relpron->set_attr( 'morphcat/number', $a_antec->get_attr('morphcat/number') );
        }
    }

}

1;

=over

=item Treex::Block::T2A::CS::ImposeRelPronAgr

Copy the values of gender and number of relative pronouns
from their antecedents (in the sense of grammatical coreference).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
