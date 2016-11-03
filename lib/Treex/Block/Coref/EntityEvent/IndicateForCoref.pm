package Treex::Block::Coref::EntityEvent::IndicateForCoref;
use Moose;
use Moose::Util::TypeConstraints;
use List::MoreUtils qw/all any/;
use Treex::Core::Common;
use Treex::Tool::Coreference::Utils;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Core::Block';

subtype 'BridgeTypesHash' => as 'HashRef[Bool]';
coerce 'BridgeTypesHash'
    => from 'Str'
    => via { my @a = split /,/, $_; my %hash; @hash{@a} = (1) x @a; \%hash };

has 'bridg_as_coref' => ( is => 'ro', isa => 'BridgeTypesHash', coerce => 1, default => '' );
has 'fix_missing_coord' => ( is => 'ro', isa => 'Bool', default => 0 );

sub process_tnode {
    my ($self, $tnode) = @_;

    my @antes = $self->_get_antes($tnode);
    while (@antes && all {Treex::Tool::Coreference::NodeFilter::matches($_, ["demonpron"])} @antes) {
        @antes = map {$self->_get_antes($_)} @antes;
    }
    if (@antes) {
        $tnode->wild->{entity_event} = (any {is_event($_)} @antes) ? "EVENT" : "ENTITY";
    }
    else {
        my $coref_spec = $tnode->get_attr('coref_special');
        if (defined $coref_spec && $coref_spec eq "segm") {
            $tnode->wild->{entity_event} = "EVENT";
        }
    }
}

sub _get_antes {
    my ($self, $tnode) = @_;
    
    my @antes = $tnode->get_coref_nodes;
    if (!@antes) {
        if (keys %{$self->bridg_as_coref}) {
            my ($bridg_antes, $bridg_types) = $tnode->get_bridging_nodes;
            my @bridg_ok_idx = grep {$self->bridg_as_coref->{$bridg_types->[$_]}} 0..$#$bridg_types;
            @antes = map {$bridg_antes->[$_]} @bridg_ok_idx;
        }
    }
    return @antes;
}

#sub process_document {
#    my ($self, $doc) = @_;
#
#    my @zones = map {$_->get_zone($self->language, $self->selector)} $doc->get_bundles;
#    if (any {!defined $_} @zones) {
#        log_fatal "[Treex::Block::T2T::CopyCorefFromAlignment] Zone must be specified by a language and selector.";
#    }
#    my @ttrees = map {$_->get_ttree} @zones;
#
#    # set entity_event for coreference chain
#    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees, { bridg_as_coref => $self->bridg_as_coref });
#    foreach my $chain (@chains) {
#        my $is_event = any {is_event($_)} @$chain;
#        foreach my $mention (@$chain) {
#            $mention->wild->{entity_event} = $is_event ? "EVENT" : "ENTITY";
#            if ($self->fix_missing_coord && $mention->is_coap_root && $mention->functor ne "APPS") {
#                foreach my $member ($mention->get_coap_members) {
#                    $member->wild->{entity_event} = $is_event ? "EVENT" : "ENTITY";
#                }
#            }
#        }
#    }
#
#    # set entity_event for coref_special nodes
#    foreach my $ttree (@ttrees) {
#        foreach my $tnode ($ttree->get_descendants({ordered => 1})) {
#            next if (defined $tnode->wild->{entity_event});
#            my $coref_spec = $tnode->get_attr('coref_special');
#            if (defined $coref_spec && $coref_spec eq "segm") {
#                $tnode->wild->{entity_event} = "EVENT";
#            }
#            if ($self->fix_missing_coord && $tnode->is_coap_root && $tnode->functor ne "APPS") {
#                foreach my $member ($tnode->get_coap_members) {
#                    $member->wild->{entity_event} = "EVENT";
#                }
#            }
#        }
#    }
#}

sub is_event {
    my ($tnode) = @_;

    if (($tnode->formeme // "") =~ /^v/ || ($tnode->gram_sempos // "") =~ /^v/) {
        return 1;
    }
    elsif ($tnode->is_coap_root && $tnode->functor ne "APPS") {
        my $verb_as_member = any {
            ($_->formeme // "") =~ /^v/ || ($_->gram_sempos // "") =~ /^v/
        } $tnode->get_coap_members;
        return $verb_as_member ? 1 : 0;
    }
    else {
        return 0;
    }
}

#sub event_or_entity {
#    my ($self, $tnode) = @_;
#    my ($ante) = $tnode->get_coref_nodes;
#    if (!defined $ante && %{$self->bridg_as_coref}) {
#        my ($b_antes, $b_types) = $tnode->get_bridging_nodes;
#        ($ante) = map {$b_antes->[$_]} grep {$self->bridg_as_coref->{$b_types->[$_]}} 0..$#$b_types;
#    }
#    if (defined $ante) {
#        return trg_node_event_or_entity($ante);
#    }
#    else {
#        my $coref_spec = $tnode->get_attr("coref_special");
#        if (($coref_spec // "") eq "segm") {
#            return "EVENT";
#        }
#        else {
#            return "OTHER";
#        }
#    }
#}

1;

=head1 NAME

Treex::Block::Coref::EntityEvent::IndicateForCoref

=head1 DESCRIPTION

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
