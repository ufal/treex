package Treex::Block::A2T::SetFunctorsMLProcess;

use Moose;
use Treex::Core::Common;

extends 'Treex::Tool::ML::MLProcessBlockPiped';

has '+input_attrib_names' => ( default => sub { ['functor'] } );

sub process_ttree {

    my ( $self, $troot ) = @_;

    my @tnodes = $troot->get_descendants( { ordered => 1 } );
    my @classified = $self->classify_nodes(@tnodes);

    for ( my $i = 0; $i < @tnodes; ++$i ) {
        $tnodes[$i]->set_functor( $classified[$i]->{functor} );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetFunctorsMLProcess

=head1 DESCRIPTION

Sets functors in tectogrammatical trees using a pre-trained machine learning model (logistic regression, SVM etc.)
via the ML-Process Java executable with WEKA integration.

Pre-set configurations with default paths to trained models for Czech and English are available
as L<Treex::Block::A2T::CS::SetFunctors> and L<Treex::Block::A2T::EN::SetFunctors2>, respectively. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
