package Treex::Block::Filter::Generic::RemoveBadPairs;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Filter::Generic::Common';

has threshold => (
    isa           => 'Num',
    is            => 'rw',
    required      => 0,
    default       => '0.3',
    documentation => 'threshold for accepting of sentence pairs'
);

sub process_document {
    my $bad_section_length = 0;

    my ( $self, $document ) = @_;
    for my $bundle ( $document->get_bundles() ) {
        my $score = $self->get_final_score( $bundle );
        if ( $score < $self->{threshold} ) {
            $bad_section_length++;
            $bundle->remove();
        } else {
            if ( $bad_section_length > 0 ) {
                my $prev_missing = $bundle->attr( 'czeng/missing_sents_before' );
                $bad_section_length += $prev_missing if defined $prev_missing; 
                $bundle->set_attr( 'czeng/missing_sents_before', $bad_section_length );
            }
            $bad_section_length = 0;
        }
    }
}

1;

=over

=item Treex::Block::Filter::Generic::RemoveBadPairs

Remove bundles with filter score below threshold. The number of removed bundles
is stored in the next correct bundle in 'czeng/missing_sentences_before'.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
