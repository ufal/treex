package Treex::Block::Misc::CopenhagenDT::FlattenUnannotatedTrees;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $lang (qw(it es de)) {
        if(!defined($document->wild->{annotation}{$lang})) {next;}
        if(defined($document->wild->{annotation}{$lang}{syntax})) {next;}

        foreach my $bundle ($document->get_bundles) {
            my $zone = $bundle->get_zone($lang);

            if (not defined $zone) {next;}

            foreach my $node ( $zone->get_atree->get_descendants ) {
                $node->set_parent($node->get_root);
            }
        }
    }

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::FixLonelyNodes

Unannotated trees are flattened under the technical root

=back

=cut

# Copyright 2012 Michael Carl
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
