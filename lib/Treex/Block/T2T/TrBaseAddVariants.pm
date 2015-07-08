package Treex::Block::T2T::TrBaseAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::TrBaseAddVariantsInterpol';

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

Treex::Block::T2T::TrBaseAddVariants -- abstract class, add translation variants from translation models (language-independent)

=head1 DESCRIPTION

This block uses a combination of translation models to predict log-probabilities of translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>) and Static (based on simple corpus counts).

Using L<Treex::Tool::Memcached::Memcached> models is enabled via the 
L<Treex::Block::T2T::TrUseMemcachedModel> role.  

See the 'documentation' parameter of the individual attributes for details on various options.

=back

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
