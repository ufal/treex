package Treex::Block::A2T::EN::SetFunctors2;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetFunctors';

has '+model_dir' => ( default => 'data/models/functors/en/' );

has '+plan_template'  => ( default => 'plan.template' );

has '+features_config' => ( default => 'features.yml' );

has '+model_files' => ( builder => '_build_model_files', lazy_build => 1 );

has '+plan_vars' => ( builder => '_build_plan_vars', lazy_build => 1 );


sub _build_model_files {
    my ($self) = @_;
    return [
        'ff.dat',
        $self->plan_template,
        $self->features_config,
        map { 'model-' . $_ . '.dat' } ( '', 'n', 'adj', 'adv', 'v', 'x', 'coap' ), 
    ];
}

sub _build_plan_vars {
    my ($self) = @_;    
    return {
        'FF-INFO' => 'ff.dat',
        'MODELS' => 'model-**.dat',
    };    
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetFunctors

=head1 DESCRIPTION

This is just a default configuration of L<Treex::Block::A2T::SetFunctors> for English, containing pre-set
paths to the trained models and configuration in the Treex shared directory. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
