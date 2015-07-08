package Treex::Block::T2T::EN2CS::TrLAddVariants;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2T::TrLAddVariants', 'Treex::Block::T2T::EN2CS::TrLAddVariantsInterpol';

has '+discr_model' => ( default => 'tlemma_czeng12.maxent.10000.100.2_1.compact.pls.gz' );
has '+static_model' => ( default => 'tlemma_czeng09.static.pls.slurp.gz' );

has human_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_humanlex.static.pls.slurp.gz',
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
        {
            type => 'static',
            weight => 0.1,
            filename => $self->human_model,
        },
    ];
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2CS::TrLAddVariants -- add t-lemma translation variants from translation models (en2cs translation)

=head1 DESCRIPTION

Adding t-lemma translation variants for the en2cs translation.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
