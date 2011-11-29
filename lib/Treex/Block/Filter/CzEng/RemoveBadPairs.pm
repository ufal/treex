package Treex::Block::Filter::CzEng::RemoveBadPairs;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Filter::CzEng::Common';

has threshold => (
    isa           => 'Num',
    is            => 'rw',
    required      => 0,
    default       => '0.3',
    documentation => 'threshold for accepting of sentence pairs'
);

sub process_document {
    my $last_correct_bundle = undef;
    my $bad_section_length = 0;

    my ( $self, $document ) = @_;
    for my $bundle ( $document->get_bundles() ) {
        my ( $score ) = grep { $_ =~ m/filter_score/ } $self->get_features($bundle);
        $score =~ s/filter_score=//;
        if ( $score < $self->{threshold} ) {
            $bad_section_length++;
            $bundle->remove();
            log_info "successfully removed bundle";
        } else {
            if ( $bad_section_length > 0 && defined $last_correct_bundle ) {
                $last_correct_bundle->set_attr('czeng/missing_sents_above', $bad_section_length);
            }
            $bad_section_length = 0;
            $last_correct_bundle = $bundle;    
        }
    }
}

1;

=over

=item Treex::Block::Filter::CzEng::RemoveBadPairs

Remove bundles with filter score below threshold. The number of removed bundles
is stored in the last correct bundle in wild->{missing_bundles}.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
