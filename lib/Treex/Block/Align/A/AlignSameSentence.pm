package Treex::Block::Align::A::AlignSameSentence;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language'   => ( required => 1 );
has 'to_language' => ( is       => 'ro', isa => 'LangCode', lazy_build => 1 );
has 'to_selector' => ( is       => 'ro', isa => 'Selector', default => 'ref' );

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

sub process_zone {

    my ( $self, $tst_zone ) = @_;
    my $ref_zone = $tst_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    my @tst_nodes = $tst_zone->get_atree->get_descendants( { ordered => 1 } );
    my @ref_nodes = $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    
    log_fatal("The two zones do not have a corresponding number of nodes.") if (@ref_nodes != @tst_nodes);

    for (my $i = 0; $i < @ref_nodes; ++$i){
        $tst_nodes[$i]->add_aligned_node( $ref_nodes[$i] );        
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::A::AlignSameSentence

=head1 DESCRIPTION

Alignment of two analytical parses of the same sentence (i.e. containing the same list of tokens).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
