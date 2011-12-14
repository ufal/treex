package Treex::Block::Align::AlignSameSentence;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => 'Treex::Type::Layer', default => 'a' );
has '+language'   => ( required => 1 );
has 'to_language' => ( is       => 'ro', isa => 'Treex::Type::LangCode', lazy_build => 1 );
has 'to_selector' => ( is       => 'ro', isa => 'Treex::Type::Selector', default => 'ref' );

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't align a zone to itself.");
    }
}

sub process_zone {
    my ( $self, $tst_zone ) = @_;
    my $ref_zone = $tst_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    my @tst_nodes = $tst_zone->get_tree( $self->layer )->get_descendants( { ordered => 1 } );
    my @ref_nodes = $ref_zone->get_tree( $self->layer )->get_descendants( { ordered => 1 } );

    log_fatal("The two zones do not have a corresponding number of nodes.") if ( @ref_nodes != @tst_nodes );

    for ( my $i = 0; $i < @ref_nodes; ++$i ) {
        $tst_nodes[$i]->add_aligned_node( $ref_nodes[$i] );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::AlignSameSentence

=head1 DESCRIPTION

Alignment of two trees belonging to the same sentence (i.e. containing the same list of tokens).

=head1 PARAMETERS

=item C<layer>

The layer of the aligned trees (default: a).

=item C<language>

The current language. This parameter is required.

=item C<selector>

The current selector (default: empty).

=item C<to_language>

The target (reference) language for the alignment. Defaults to current C<language> setting. 
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=item C<to_selector>

The target (reference) selector for the alignment. Defaults to current C<selector> setting.
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
