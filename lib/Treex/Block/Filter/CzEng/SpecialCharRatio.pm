package Treex::Block::Filter::CzEng::SpecialCharRatio;
use Moose;
use Treex::Core::Common;
use List::Util qw( min max sum );

extends 'Treex::Block::Filter::CzEng::Common';

my @watched = qw# . | ! / ( ) { } [ ] ? ; : - #;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;
    
    my @en_words = map { substr($_->get_attr("form"), 0, 1) } @en;
    my @cs_words = map { substr($_->get_attr("form"), 0, 1) } @cs;

    my ( %en_chars, %cs_chars );
    for my $char (@watched) {
        $en_chars{$char} = scalar grep { $_ eq $char } @en_words;
        $cs_chars{$char} = scalar grep { $_ eq $char } @cs_words;
    }

    my $max_total_chars = max( sum(values %en_chars), sum(values %cs_chars) );
    
    my $intersection_size = 0;
    for my $char (@watched) {
        if ( defined $en_chars{$char} && defined $cs_chars{$char} ) {
            $intersection_size += min( $en_chars{$char}, $cs_chars{$char} );
        }
    }
        
    my $reliable = "";# $max_total_chars >= 4 ? "reliable_" : "rough_";
    my @bounds = ( 0, 0.2, 0.5, 0.8, 1 );

    if ( $max_total_chars > 0 ) {
        $self->add_feature( $bundle, $reliable . "special_char_ratio="
            . $self->quantize_given_bounds( $intersection_size / $max_total_chars, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::SpecialCharRatio

=back

A filtering feature. Computes how many watched characters of each kind are covered
on both sides.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
