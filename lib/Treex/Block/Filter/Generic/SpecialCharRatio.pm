package Treex::Block::Filter::Generic::SpecialCharRatio;
use Moose;
use Treex::Core::Common;
use List::Util qw( min max sum );

extends 'Treex::Block::Filter::Generic::Common';

my @watched = qw# . | ! / ( ) { } [ ] ? ; : - " #;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @src = $bundle->get_zone($self->language)->get_atree->get_descendants;
    my @tgt = $bundle->get_zone($self->to_language)->get_atree->get_descendants;
    
    my @src_words = map { substr($_->get_attr("form"), 0, 1) } @src;
    my @tgt_words = map { substr($_->get_attr("form"), 0, 1) } @tgt;

    my ( %src_chars, %tgt_chars );
    for my $char (@watched) {
        $src_chars{$char} = scalar grep { $_ eq $char } @src_words;
        $tgt_chars{$char} = scalar grep { $_ eq $char } @tgt_words;
    }

    my $max_total_chars = max( sum(values %src_chars), sum(values %tgt_chars) );
    
    my $intersection_size = 0;
    for my $char (@watched) {
        if ( defined $src_chars{$char} && defined $tgt_chars{$char} ) {
            $intersection_size += min( $src_chars{$char}, $tgt_chars{$char} );
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

=item Treex::Block::Filter::Generic::SpecialCharRatio

=back

A filtering feature. Computes how many watched characters of each kind are covered
on both sides.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
