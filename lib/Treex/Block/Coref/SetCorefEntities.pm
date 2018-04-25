package Treex::Block::Coref::SetCorefEntities;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

subtype 'BridgTypesHash' => as 'HashRef[Bool]';
coerce 'BridgTypesHash'
    => from 'Str'
    => via { my @a = split /,/, $_; my %hash; @hash{@a} = (1) x @a; \%hash };

# TODO: move other ("f", "s", "e") special flags to wild_attr_name and cancel wild_attr_special_name
# so far, only "?" (loose monolingual alignment) and "c" (coordination member) used there
# TODO: is it possible to use ProjectCorefEntities before SimpleEval or EntityEventEval?
# all the modifications would need to be done only at a single place

has 'bridg_as_coref' => ( is => 'ro', isa => 'BridgTypesHash', coerce => 1, default => '' );

sub process_document {
    my ($self, $doc) = @_;

    my @zones = map {$_->get_zone($self->language, $self->selector)} $doc->get_bundles;
    if (any {!defined $_} @zones) {
        log_fatal "[Treex::Block::T2T::CopyCorefFromAlignment] Zone must be specified by a language and selector.";
    }
    my @ttrees = map {$_->get_ttree} @zones;

    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees, { bridg_as_coref => $self->bridg_as_coref });
    my $entity_id = 1;
    foreach my $chain (@chains) {
        foreach my $mention (@$chain) {
            $mention->wild->{coref_entity} = $entity_id;
        }
        $entity_id++;
    }
}

1;

=head1 NAME

Treex::Block::Coref::SetCorefEntities

=head1 DESCRIPTION

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
