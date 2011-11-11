package Treex::Block::Filter::CzEng::AcademicTitle;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en      = $bundle->get_zone('en')->sentence;
    my $cs      = $bundle->get_zone('cs')->sentence;
    my $pattern = '\b((Bc|Mgr|Ing|MUDr|JUDr|RNDr|PhDr|MVDr|PharmDr|ThDr|Doc|Prof|arch)\.)$';
    if ( $cs =~ m/$pattern/i || $en =~ m/$pattern/i ) {
        $self->add_feature( $bundle, 'academic_title' );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::AcademicTitle

Finding subsequences of a character repeated four or more times.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
