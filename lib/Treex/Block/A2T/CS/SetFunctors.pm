package Treex::Block::A2T::CS::SetFunctors;

use Moose;
use Treex::Core::Common;
use Treex::Block::Write::Arff;

extends 'Treex::Tool::ML::MLProcessBlock';

has '+model_dir'      => ( default => 'data/models/functors/cs/' );
has '+plan_template'  => ( default => 'plan.template' );
has 'features_config' => ( isa     => 'Str', is => 'ro', default => 'features.yml' );

has '+model_files' => ( builder => '_build_model_files', lazy_build => 1 );
has '+plan_vars' => ( builder => '_build_plan_vars', lazy_build => 1 );

has '+class_name' => ( default => 'functor' );

sub _build_model_files {
    my ($self) = @_;
    return [
        'ff.dat',
        $self->plan_template,
        $self->features_config,
        map { 'model-' . $_ . '.dat' } ( '', 'n', 'adj', 'adv', 'v', '[3f][3f][3f]', '[5b]OTHER[5d]', 'coap' ), 
    ];
}

sub _build_plan_vars {
    my ($self) = @_;    
    return {
        'FF-INFO' => 'ff.dat',
        'MODELS' => 'model-**.dat',
    };    
}

override '_write_input_data' => sub {

    my ( $self, $document, $file ) = @_;

    # print out data in pseudo-conll format for the ml-process program
    log_info( "Writing the ARFF data to " . $file );
    my $arff_writer = Treex::Block::Write::Arff->new(
        {
            to          => $file->filename,
            language    => $self->language,
            selector    => $self->selector,
            config_file => $self->model_dir . $self->features_config,
            layer       => 't',
            force_types => 'formeme: STRING',
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

Generated nodes and nodes of the 'coap' type are left out because their functors are typically already
set from elsewhere when this block is called and the trained models do not take them into account. 

The path to the pre-trained model and its configuration in the shared directory is set in the C<model_dir>,
C<plan_template> and C<model_files> parameters. 

=head1 TODO

Create a separate functor setting block for coordination and apposition nodes.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
