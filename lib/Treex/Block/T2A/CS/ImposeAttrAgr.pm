package TCzechT_to_TCzechA::Impose_attr_agr;

use 5.008;
use strict;
use warnings;
use utf8;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $t_attr ( grep { $_->get_attr('formeme') =~ /attr|poss/ } $t_root->get_descendants() ) {
        my $a_attr   = $t_attr->get_lex_anode or next; # weird, this should not happen
        my ($t_noun) = $t_attr->get_eff_parents;
        my $a_noun   = $t_noun->get_lex_anode;
        next if !$a_noun || $a_noun->is_root();    #TODO: || $a_noun->get_attr('gram/sempos') !~ /^n/; ???

        # By default, imposed categories are: gender number case.
        my @categories = qw(gender number case);

        # However, for nouns in attributive position, it is just the case.
        # TODO: mlayer_pos eq N seems redundant, but "tento" has "n:attr" at the moment (2/2010)
        if ( $t_attr->get_attr('formeme') eq 'n:attr' && ($t_attr->get_attr('mlayer_pos')||'') eq 'N' ) {
            @categories = qw(case);
        }
        foreach my $cat (@categories) {
            $a_attr->set_attr( "morphcat/$cat", $a_noun->get_attr("morphcat/$cat") );
        }

        # overriding case agreement in constructions like 'nic noveho','neco zajimaveho'
        my ($a_parent) = $a_attr->get_eff_parents;
        if ($a_parent->get_attr('m/lemma')
            =~ /^(nic|něco)/
            and $t_attr->get_attr('formeme') =~ /^adj/
            )
        {
            if ( $a_attr->get_attr('morphcat/case') =~ /[14]/ ) {
                $a_attr->set_attr( 'morphcat/case', 2 );
            }
            $a_attr->set_attr( 'morphcat/gender', 'N' );
            $a_attr->set_attr( 'morphcat/number', 'S' );
        }
    }
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Impose_attr_agr

Resolving gender/number/case agreement of adjectivals in attributive positions
with their governing nouns.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
