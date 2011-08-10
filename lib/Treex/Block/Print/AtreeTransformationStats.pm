package Treex::Block::Print::AtreeTransformationStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my @zones = grep { $_->selector eq '' } $bundle->get_all_zones;

    log_fatal "There are " . scalar(@zones)
        . " zones with empty selector, but exactly one is required to collect stats from"
        if @zones != 1;

    my $zone     = $zones[0];
    my $language = $zone->language;

    $bundle->get_document->path =~ /(trans_\w+)/;
    my $directory = $1;
    foreach my $anode ( $zone->get_atree->get_descendants ) {
        my $transformation = ( join ' ', grep {/^trans/} sort keys %{ $anode->wild } ) || '';
        print "$language\t$directory\t$transformation\n";
    }
}

1;

=head1 NAME

Treex::Block::Print::AtreeTransformationStats

=head1 DESCRIPTION

Collecting statistics on the number of nodes rehanged by various
transformations in various languages.

=cut

# Copyright 2011 Zdenìk ®abokrtský <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
