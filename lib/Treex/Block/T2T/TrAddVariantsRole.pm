package Treex::Block::T2T::TrAddVariantsRole;
use Moose::Role;
requires '_build_models';

has discr_type => (
    is      => 'ro',
    isa     => 'Str',
    default => 'maxent',
);

has discr_weight => (
    is            => 'ro',
    isa           => 'Num',
    documentation => 'Weight of the discriminative model (the model won\'t be loaded if the weight is zero).'
);

has discr_model => (
    is      => 'ro',
    isa     => 'Str',
);

has static_weight => (
    is            => 'ro',
    isa           => 'Num',
    documentation => 'Weight of the Static model (NB: the model will be loaded even if the weight is zero).'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
);

override '_build_models' => sub {
    my ($self) = @_;

    return [
        {
            type => $self->discr_type,
            weight => $self->discr_weight,
            filename => $self->discr_model,
        },
        {
            type => 'static',
            weight => $self->static_weight,
            filename => $self->static_model,
        },
    ];
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrAddVariantsRole -- add support for setting the models by using the parameters static_model, static_weight, discr_model, discr_type, discr_weight

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
