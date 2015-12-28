package Treex::Block::Align::FilterAlignment;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => 'Treex::Type::Layer', default => 'a' );

has '+language' => ( required => 1 );

has 'condition' => ( is => 'ro', isa => 'Str', default => '1' );

has 'invert' => ( is => 'ro', isa => 'Bool', default => 0 );

sub process_zone {

    my ( $self, $zone ) = @_;
    my @nodes = $zone->get_tree( $self->layer )->get_descendants( { ordered => 1 } );

    foreach my $a (@nodes) {
        my ($bs, $types) = $a->get_directed_aligned_nodes();
        
        next if (!$bs);
        
        for (my $i = 0; $i < scalar @{$bs}; ++$i ){
            
            my ($b, $type) = ($bs->[$i], $types->[$i]);
            
            if ( ( eval( $self->condition ) - $self->invert ) == 0 ) {
                $a->delete_aligned_node($b);
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::FilterAlignment

=head1 DESCRIPTION

This block deletes some of the alignment links based on the given condition.

=head1 PARAMETERS

=item C<layer>

The layer of the aligned trees (default: a).

=item C<language>

The current language. This parameter is required.

=item C<selector>

The current selector (default: empty).

=item C<condition>

The condition that must be fulfilled so that the alignment link will NOT be deleted. 

The condition may be any Perl code returning a boolean value. You may use C<$a> as the source 
node, C<$b> as the target node and C<$type> as the alignment type. 

The condition defaults to 1, i.e. no nodes will be deleted in the default setting.

=item C<invert>

Invert the matching sense, i.e. if set to 1, all nodes fulfilling the given condition
WILL be deleted. Defaults to 0.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
