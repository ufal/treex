package Treex::Block::Filter::Generic::MarkBadPairs;
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

has dry_run => (
    isa => 'Bool',
    is  => 'rw',
    default => 0,
    documentation => 'write skipped sents count to wild attr'
);

sub process_document {
    my $bad_section_length = 0;
    my $last_doc = "";

    my ( $self, $document ) = @_;
    for my $bundle ( $document->get_bundles() ) {
        my $score = $self->get_final_score( $bundle );
        my $doc = $bundle->attr( 'czeng/origfile' );
        $doc =~ s/-\d+$//;
        if ( $score < $self->{threshold} ) {
            $bad_section_length++;
            $bundle->wild->{to_delete} = 1;                
#            $bundle->remove(); # does not work yet
        } else {
            delete $bundle->wild->{to_delete}; 
            if ( $bad_section_length > 0 ) {
                if ( $doc eq $last_doc ) {
                    my $prev_missing = $bundle->attr( 'czeng/missing_sents_before' );
                    $bad_section_length += $prev_missing if defined( $prev_missing ) && ! $self->{dry_run}; 
                    $self->_set_missing_sents_count( $bundle, $bad_section_length );
                } else {
                    # this is a start of a new document (file) => nothing is missing
                    $self->_set_missing_sents_count( $bundle, undef );
                }
            }
            $bad_section_length = 0;
        }
        $last_doc = $doc;
    }
}

sub _set_missing_sents_count {
    my ( $self, $bundle, $count ) = @_;
    if ( $self->{dry_run} ) {
        if ( defined $count ) {
            $bundle->wild->{missing_sents_before} = $count;
        } else {
            delete $bundle->wild->{missing_sents_before};
        }
    } else {
        $bundle->set_attr( 'czeng/missing_sents_before', $count );
    }
}

1;

=over

=item Treex::Block::Filter::Generic::MarkBadPairs

Mark sentence pairs with score below the threshold as 'to_delete' in <wild>.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
