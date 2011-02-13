package TCzechT_to_TCzechA::Add_auxverb_compound_past;

use utf8;
use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my %auxpast_numberperson2form = (
    'S1' => 'jsem',
    'S2' => 'jsi',
    'P1' => 'jsme',
    'P2' => 'jste',
    '.2' => 'jsi',    # !!! - hack - cislo by se melo hadat uz driv a tady uz byt vyplnene
    '.1' => 'jsem',
);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $tnode ( $bundle->get_tree('TCzechT')->get_descendants() ) {
        process_tnode($tnode);
    }
    return;
}

sub process_tnode {
    my ($tnode) = @_;
    my $tense = $tnode->get_attr('gram/tense') || '';
    return if $tense ne 'ant';

    # Conditionals don't have an extra auxverb for past tense "bych *jsem prišel"
    my $verbmod = $tnode->get_attr('gram/verbmod') || '';
    my $formeme = $tnode->get_attr('formeme') || '';
    return if $verbmod eq 'cdn' or $formeme =~ /(aby|kdyby)/;

    # Generate a form of the new auxverb
    my $anode  = $tnode->get_lex_anode();
    my $number = $anode->get_attr('morphcat/number') || 'S';
    my $person = $anode->get_attr('morphcat/person') || '';
    my $form   = $auxpast_numberperson2form{ $number . $person };
    return if !$form;

    my $new_node = $anode->create_child(
        {   attributes => {
                'm/lemma'      => 'být',
                'm/form'       => $form,
                'afun'         => 'AuxV',
                'morphcat/pos' => '!',
            }
        }
    );
    $new_node->shift_before_node($anode);
    $tnode->add_aux_anodes($new_node);
    return;
}

1;

=encoding utf8

=over

=item TCzechT_to_TCzechA::Add_auxverb_compound_past

Add auxiliaries such as I<jsem/jste...> in past-tense complex
verb forms (I<viděli jsme, přišli jste>).

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
