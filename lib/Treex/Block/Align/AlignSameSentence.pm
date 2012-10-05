package Treex::Block::Align::AlignSameSentence;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => 'Treex::Type::Layer', default => 'a' );
has 'to_language' => ( is       => 'ro', isa => 'Treex::Type::LangCode' );
has 'to_selector' => ( is       => 'ro', isa => 'Treex::Type::Selector', default => 'ref' );
has align_type => (is=>'ro', default=>'copy');

sub process_zone {
    my ( $self, $tst_zone ) = @_;
    my $to_language = $self->to_language || $tst_zone->language;
    my $ref_zone = $tst_zone->get_bundle()->get_zone( $to_language, $self->to_selector );
    log_fatal 'Cannot align zone ' . $tst_zone->get_label . ' to itself' if $ref_zone == $tst_zone;
    
    my @tst_nodes = $tst_zone->get_tree( $self->layer )->get_descendants( { ordered => 1 } );
    my @ref_nodes = $ref_zone->get_tree( $self->layer )->get_descendants( { ordered => 1 } );

    log_fatal("The two zones do not have a corresponding number of nodes.") if ( @ref_nodes != @tst_nodes );

    for ( my $i = 0; $i < @ref_nodes; ++$i ) {
        $tst_nodes[$i]->add_aligned_node( $ref_nodes[$i], $self->align_type );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::AlignSameSentence

=head1 DESCRIPTION

Alignment of two trees belonging to the same sentence (i.e. containing the same list of tokens).
The source tree is specified as usual using the parameters
C<language> and C<selector>.

=head1 PARAMETERS

=item C<layer>

The layer of the aligned trees (default: a).

=item C<to_language>

The target (reference) language for the alignment. Defaults to current C<language> setting. 

=item C<to_selector>

The target (reference) selector for the alignment.
Default is "ref".


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
