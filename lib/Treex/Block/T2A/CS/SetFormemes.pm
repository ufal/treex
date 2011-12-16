package Treex::Block::T2A::CS::SetFormemes;

use Moose;
use Treex::Core::Common;
use Treex::Block::Write::Arff;

extends 'Treex::Tool::ML::MLProcessBlock';

has '+model_dir'     => ( default => 'data/models/formemes/cs/' );
has '+plan_template' => ( default => 'plan.template' );

has 'features_config' => ( isa => 'Str', is => 'ro', default => 'features.yml' );

has '+model_files' => ( builder => '_build_model_files', lazy_build => 1 );

has '+plan_vars' => (
    default => sub {
        return {
            'MODELS'  => 'model-**.dat',
            'FF-INFO' => 'ff.dat',
        };
        }
);

sub _build_model_files {
    my ($self) = @_;
    return [
        'ff.dat',
        $self->plan_template,
        $self->features_config,
        map { 'model-' . $_ . '.dat' }    # models for individual functors
            (
            '[3f][3f][3f]', '[5b]OTHER[5d]',                                      # filename-encoded '???' and '[OTHER]'
            'ACMP', 'ACT', 'ADDR', 'ADVS', 'AIM', 'APP', 'APPS', 'ATT', 'AUTH',
            'BEN',  'CAUS', 'CM',   'CNCS', 'COMPL', 'COND',
            'CONJ', 'CPHR', 'CPR',  'CRIT', 'CSQ',   'DENOM', 'DIFF', 'DIR1',
            'DIR2', 'DIR3', 'DISJ', 'DPHR', 'EFF',   'EXT', 'FPHR', 'GRAD',
            'ID',   'LOC',  'MANN', 'MAT',  'MEANS', 'MOD', 'OPER', 'ORIG',
            'PAR',  'PAT',  'PREC', 'PRED', 'REG', 'RESL', 'RESTR',
            'RHEM', 'RSTR', 'SUBS', 'TFHL', 'THL',   'THO', 'TPAR', 'TSIN',
            'TTILL', 'TWHEN',
            )
    ];
}

has '+class_name' => ( default => 'formeme' );

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

    $node->set_formeme($value);
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::SetFormemes

=head1 DESCRIPTION

Assigns formemes in tectogrammatical trees using a pre-trained machine learning model (logistic regression)
via the ML-Process/WEKA libraries.

The path to the pre-trained model and its configuration in the shared directory is set in the C<model_dir>,
C<plan_template> and C<model_files> parameters. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
