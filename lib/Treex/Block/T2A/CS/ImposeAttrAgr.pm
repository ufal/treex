package Treex::Block::T2A::CS::ImposeAttrAgr;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if $tnode->formeme !~ /attr|poss/;
    my $a_attr = $tnode->get_lex_anode or return;    # weird, this should not happen
    my ($t_noun) = $tnode->get_eparents;
    my $a_noun = $t_noun->get_lex_anode;
    return if !$a_noun || $a_noun->is_root();        #TODO: || $a_noun->get_attr('gram/sempos') !~ /^n/; ???

    # By default, imposed categories are: gender number case.
    my @categories = qw(gender number case);

    # However, for nouns in attributive position, it is just the case.
    # TODO: mlayer_pos eq N seems redundant, but "tento" has "n:attr" at the moment (2/2010)
    if ( $tnode->formeme eq 'n:attr' && ( $tnode->get_attr('mlayer_pos') || '' ) eq 'N' ) {
        @categories = qw(case);
    }
    foreach my $cat (@categories) {
        $a_attr->set_attr( "morphcat/$cat", $a_noun->get_attr("morphcat/$cat") );
    }

    # overriding case agreement in constructions like 'nic noveho','neco zajimaveho'

    my $a_parent;
    if ($tnode->formeme =~ /^adj/
        && ( ($a_parent) = $a_attr->get_eparents() )
        && $a_parent->lemma =~ /^(nic|něco)/
        )
    {
        if ( $a_attr->get_attr('morphcat/case') =~ /[14]/ ) {
            $a_attr->set_attr( 'morphcat/case', 2 );
        }
        $a_attr->set_attr( 'morphcat/gender', 'N' );
        $a_attr->set_attr( 'morphcat/number', 'S' );
    }

    return;
}

1;

=over

=item Treex::Block::T2A::CS::ImposeAttrAgr

Resolving gender/number/case agreement of adjectivals in attributive positions
with their governing nouns.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
