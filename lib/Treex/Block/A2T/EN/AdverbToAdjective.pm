package SEnglishA_to_SEnglishT::Adverb_to_adjective;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

use Lingua::Ispell;

$Lingua::Ispell::path = substr( `which ispell`, 0, -1 );
Lingua::Ispell::use_dictionary('en_US');

sub correct {
    my $word = shift;
    my @res  = Lingua::Ispell::spellcheck($word);
    if ( $#res == 0 ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_aux_root = $bundle->get_tree('SEnglishT');
        foreach my $t_node ( $t_aux_root->get_descendants ) {
            my $t_lemma = $t_node->get_attr('t_lemma');
            my $formeme = $t_node->get_attr('formeme');
            if ( defined $formeme and $formeme eq "adv" and $t_lemma =~ /ly$/ ) {
                foreach my $substitution ( [ 'lly', 'll' ], [ 'ily', 'y' ], [ 'ly', '' ], [ 'ly', 'le' ], ) {
                    my ( $adv_ending, $adj_ending ) = @$substitution;
                    my $new_t_lemma = $t_lemma;
                    if ( $new_t_lemma =~ s/${adv_ending}$/${adj_ending}/ and correct($new_t_lemma) ) {
                        $t_node->set_attr( 't_lemma', $new_t_lemma );

                        #	    print "XXXXXXXXXXXXXXX old: $t_lemma    new: $new_t_lemma\n";
                    }
                }
            }
        }
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Adverb_to_adjective

Morphological deadjectival adverbs are to be represented by the adjectival t-lemmas
at the t-layer (newly->new). This block tries to perform the corresponding substitution of endings, and if ispell
    confirms correctness of the derived adjective, it is used for replacing the original
    adverb in the C<t_lemma> attribute in SEnglishT trees.

    =back
    =cut

    # Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
