package Treex::Block::T2T::EN2CS::TrLAddVariants;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2T::EN2CS::TrLAddVariantsInterpol';
with 'Treex::Block::T2T::TrAddVariantsRole';

has '+discr_model' => ( default => 'tlemma_czeng12.maxent.10000.100.2_1.compact.pls.gz' );
has '+discr_weight' => ( default => 1.0 );

has '+static_model' => ( default => 'tlemma_czeng09.static.pls.slurp.gz' );
has '+static_weight' => ( default => 0.5 );

# EN2CS adds a human static model:

has human_model => ( is => 'ro', isa => 'Str', default => 'tlemma_humanlex.static.pls.slurp.gz' );

around '_build_models' => sub {
    my ($super, $self) = @_;

    my $result = $self->$super();
    my $human = {type => 'static', weight => 0.1, filename => $self->human_model};
    push @$result, $human;

    return $result;
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
