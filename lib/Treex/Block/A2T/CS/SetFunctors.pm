package Treex::Block::A2T::CS::SetFunctors;

use Moose;
use Treex::Core::Common;
use Treex::Block::Write::ConllLike;

extends 'Treex::Tool::ML::MLProcessBlock';

has '+model_dir'     => ( default => 'data/models/functors/cs/' );
has '+plan_template' => ( default => 'plan.template' );

has '+plan_vars' => (
    default => sub {
        return {
            'MODEL'     => 'model.dat',
            'FF-INFO'   => 'ff-data.dat',
            'IF-INFO'   => 'if-data.dat',
            'LANG-CONF' => 'st-cs.conf'
        };
        }
);

has '+model_files' => ( default => sub { return [ 'model.dat', 'if-data.dat', 'ff-data.dat', 'st-cs.conf' ] } );

has '+class_name' => ( default => 'deprel' );

override '_write_input_data' => sub {

    my ( $self, $document, $file ) = @_;

    # print out data in pseudo-conll format for the ml-process program
    log_info( "Writing the CoNLL-like data to " . $file );
    my $conll_writer = Treex::Block::Write::ConllLike->new(
        to       => $file->filename,
        language => $self->language,
        selector => $self->selector
    );
    $conll_writer->process_document($document);
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

The path to the pre-trained model and its configuration in the shared directory is set in the C<model_dir>,
C<plan_template> and C<model_files> parameters. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
