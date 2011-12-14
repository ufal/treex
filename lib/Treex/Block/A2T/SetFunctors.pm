package Treex::Block::A2T::SetFunctors;

use Moose;
use Treex::Core::Common;
use Treex::Block::Write::Arff;

extends 'Treex::Tool::ML::MLProcessBlock';

has 'features_config' => ( isa     => 'Str', is => 'ro', required => 1 );

has '+class_name' => ( default => 'functor' );


override '_write_input_data' => sub {

    my ( $self, $document, $file ) = @_;

    # print out data in ARFF format for the ML-Process program
    log_info( "Writing the ARFF data to " . $file );
    my $arff_writer = Treex::Block::Write::Arff->new(
        {
            to          => $file->filename,
            language    => $self->language,
            selector    => $self->selector,
            config_file => $self->model_dir . $self->features_config,
            layer       => 't',
            clobber     => 1
        }
    );

    $arff_writer->process_document($document);
    return;
};

override '_set_class_value' => sub {

    my ( $self, $node, $value ) = @_;

    $node->set_functor($value);
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::CS::SetFunctors

=head1 DESCRIPTION

Sets functors in tectogrammatical trees using a pre-trained machine learning model (logistic regression, SVM etc.)
via the ML-Process Java executable with WEKA integration.

Pre-set configurations with default paths to trained models for Czech and English are available 
as L<Treex::Block::A2T::CS::SetFunctors> and L<Treex::Block::A2T::EN::SetFunctors2>, respectively. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
