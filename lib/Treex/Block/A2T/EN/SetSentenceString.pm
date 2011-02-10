package SEnglishA_to_SEnglishT::Set_sentence_string;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {

        my $a_root = $bundle->get_tree('SEnglishA');

        my @bag = grep { $_->tag ne '-NONE-' } $a_root->get_descendants;
        @bag = sort { $a->get_attr('ord') <=> $b->get_attr('ord') } @bag;
        @bag = map { $_->form . (' ') } @bag;

        my $sentence = join( '', @bag );

        # quick hack for some spacing issues
        $sentence =~ s/ $//;
        $sentence =~ s/ ([,.])/$1/g;

        $bundle->set_attr( 'english_source_sentence', $sentence );
    }

}

1;

=over

=item SEnglishA_to_SEnglishT::Set_sentence_string

C<english_source_sentence> attribute of each bundle is set to a sentence string derived
from form attribute.

=back

=cut

# Copyright 2008 Jan Ptacek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
