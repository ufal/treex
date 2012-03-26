package Treex::Block::T2A::CS::SetFormemes2;

use Moose;
use Treex::Core::Common;

extends 'Treex::Tool::ML::MLProcessBlockPiped';

has '+model' => ( default => 'data/models/formemes/cs/models-pack.dat.gz' );

has '+features_config' => ( default => 'data/models/formemes/cs/features.yml' );

has '+input_attrib_names' => ( default => sub { ['formeme'] } );

sub process_ttree {

    my ( $self, $troot ) = @_;

    my @tnodes = $troot->get_descendants( { ordered => 1 } );
    my @classified = $self->classify_nodes(@tnodes);

    for ( my $i = 0; $i < @tnodes; ++$i ) {
        $tnodes[$i]->set_formeme( $classified[$i]->{formeme} );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::SetFormemes

=head1 DESCRIPTION

Assigns formemes in tectogrammatical trees using a pre-trained machine learning model (logistic regression)
via the ML-Process/WEKA libraries.

The default model is given in the C<model> attribute, the list of features passed to the classifier
is given in the C<features_config> attribute.

=head1 SEE ALSO

L<Treex::Tool::ML::MLProcessBlockPiped>  

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
