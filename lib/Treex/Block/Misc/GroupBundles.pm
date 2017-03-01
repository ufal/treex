package Treex::Block::Misc::GroupBundles;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw(natatime zip);

extends 'Treex::Core::Block';

has 'selector_suffixes' => ( isa => 'Str', 'is' => 'ro', required => 1 );

sub process_document {
    my ( $self, $doc ) = @_;
    my @bundles = $doc->get_bundles();
    my @sel_suffs = split /[, ]+/, $self->selector_suffixes;

    if ( scalar(@bundles) % scalar(@sel_suffs) != 0 ) {
        log_fatal("Number of bundles not divisible by number of target selector suffixes.");
    }

    my $it = natatime scalar(@sel_suffs), @bundles;
    while ( my @bgroup = $it->() ) {
        for ( my $i = 0; $i < @bgroup; ++$i ) {
            $self->move_bundle( $bgroup[$i], $bgroup[0], $sel_suffs[$i] );
            if ( $i > 0 ) {
                $bgroup[$i]->remove();    # remove all but the 1st bundle
            }
        }
    }
    return;
}

sub move_bundle {
    my ( $self, $src_bundle, $trg_bundle, $sel_suff ) = @_;

    my @src_zones = $src_bundle->get_all_zones();

    foreach my $src_zone (@src_zones) {
        my ( $lang, $sel ) = ( $src_zone->language, $src_zone->selector );

        # create new zone
        my $trg_zone = $trg_bundle->create_zone( $lang, $sel . $sel_suff );

        # copy sentence
        $trg_zone->set_sentence( $src_zone->sentence );

        # copy trees
        foreach my $layer (qw(a t n p)) {
            if ( !$src_zone->has_tree($layer) ) {
                next;
            }
            my $src_tree = $src_zone->get_tree($layer);
            my $trg_tree = $trg_zone->create_tree($layer);
            foreach my $subtree ( $src_tree->get_children() ) {
                $subtree->set_parent($trg_tree);
            }
        }

        # remove old zone
        $src_bundle->remove_zone( $src_zone->language, $src_zone->selector );
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::GroupBundles -- join bundles by groups, moving the trees into different selectors

=head1 DESCRIPTION

This joins a group of N consecutive bundles into one bundle, adding suffixes to all the target
zones' selectors.

=head1 PARAMETERS

=over

=item selector_suffixes

List of comma-separated target selector suffixes. This also determines how many bundles are joined
into one group.

=back


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
