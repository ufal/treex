package Treex::Block::T2T::TrFAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::TrFAddVariantsInterpol';

has discr_type => (
    is      => 'ro',
    isa     => 'Str',
    default => 'maxent',
);

has discr_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.5,
    documentation => 'Weight of the discriminative model (the model won\'t be loaded if the weight is zero).'
);

has discr_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'formeme_czeng09.maxent.compact.pls.slurp.gz',
);

has static_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 1.0,
    documentation => 'Weight of the Static model (NB: the model will be loaded even if the weight is zero).'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'formeme_czeng09.static.pls.slurp.gz',
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

Treex::Block::T2T::TrFAddVariants -- add formeme translation variants from translation models (language-independent)

=head1 DESCRIPTION

This block uses a combination of translation models to predict log-probabilities of formeme translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>) and Static (based on simple corpus counts).
The block tries to translate an unknown formeme 'partially' (without one or more function words), since unknown
formemes appear usually due to analysis errors. 

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

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
