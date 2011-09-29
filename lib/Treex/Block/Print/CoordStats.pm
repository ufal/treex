package Treex::Block::Print::CoordStats;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_bundle {

    my ( $self, $bundle ) = @_;
    my $zone     = $bundle->get_zone('mul');
    my $language = $zone->language;
    my $set      = $zone->get_document->path =~ /train/ ? 'train' : 'test';
    my $atree    = $zone->get_atree;

    foreach my $node ( $atree->get_descendants( { add_self => 1 } ) ) {

        my @features;
        if ( $node->is_root ) {
            push @features, 'is_root';
        }

        if ( ( $node->afun || '' ) eq 'Coord' ) {
            push @features, 'is_coord_head';

            # Both the inner and outer CS is considered "nested"
            if (( $node->get_parent && ( $node->get_parent->afun || '' ) eq 'Coord' )
                || grep { ( $_->afun || '' ) eq 'Coord' } $node->get_children
                )
            {
                push @features, 'is_nested';
            }
        }

        if ( $node->is_member ) {
            push @features, 'is_member';
        }

        if ( $node->is_shared_modifier ) {
            push @features, 'is_shared_modif';
        }

        if ( $node->wild->{is_coord_conjunction} ) {
            push @features, 'is_coord_conjunction';
        }

        print join "\t", ( $language, $set, @features );
        print "\n";

    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::CoordStats

=head1 DESCRIPTION

Printint data for counting occurrences of things related
to coordination constructions.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
