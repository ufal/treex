package Treex::Block::Filter::CzEng::MicrosoftLinesWithFilenames;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en = $bundle->get_zone('en')->sentence;
    my $cs = $bundle->get_zone('cs')->sentence;
    my $pattern = '\w+\.[a-z]{3}\b';
    if ($cs =~ m/$pattern/ || $en =~ m/$pattern/) {
        $self->add_feature( $bundle, 'microsoft_lines_with_filenames' ); 
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::MicrosoftLinesWithFilenames

Marking lines containing file names or URLs (typically useless content).

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
