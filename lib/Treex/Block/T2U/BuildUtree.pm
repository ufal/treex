# -*- encoding: utf-8 -*-
package Treex::Block::T2U::BuildUtree;
use Moose;
use Treex::Core::Common;
use Treex::Tool::UMR::Common qw{ get_corresponding_unode };
use namespace::autoclean;

extends 'Treex::Core::Block';
with 'Treex::Tool::UMR::PDTV2PB';

has '+language' => ( required => 1 );

sub process_zone
{
    my ( $self, $zone ) = @_;
    my $troot = $zone->get_ttree();
    # Build u-root.
    my $uroot = $zone->create_utree({overwrite => 1});
    $uroot->set_deref_attr('ttree.rf', $troot);
    # Recursively build the tree.
    $self->build_subtree($troot, $uroot);
    # Make sure the ord attributes form a sequence 1, 2, 3, ...
    $uroot->_normalize_node_ordering();
    for my $unode (reverse $uroot->descendants) {
        my $tnode = $unode->get_tnode;
        $self->adjust_coap($unode, $tnode) if 'coap' eq $tnode->nodetype;
    }
    return 1;
}

sub build_subtree
{
    my ($self, $tparent, $uparent) = @_;
    foreach my $tnode ($tparent->get_children({ordered => 1}))
    {
        my $unode = $uparent->create_child();
        $unode = $self->add_tnode_to_unode($tnode, $unode);
        $self->build_subtree($tnode, $unode);
    }
    return;
}

sub translate_val_frame
{
    my ($self, $tnode, $unode) = @_;
    my @eps = $tnode->get_eparents;
    my %functor;
  EPARENT:
    for my $ep (@eps) {
        next unless $ep->val_frame_rf;

        if (my $valframe_id = $ep->val_frame_rf) {
            $valframe_id =~ s/^.*#//;
            if (my $pb = $self->mapping->{$valframe_id}{ $tnode->functor }) {
                ++$functor{$pb};
                next EPARENT
            }
        }
        ++$functor{ $tnode->functor };
    }
    if (1 == keys %functor) {
        $unode->set_functor((keys %functor)[0]);
    } else {
        log_warn("More than one functor: " . join ' ', keys %functor)
            if keys %functor > 1;
        $unode->set_functor($tnode->functor);
    }
    if (my $valframe_id = $tnode->val_frame_rf) {
        $valframe_id =~ s/^.*#//;
        my $mapping = $self->mapping->{$valframe_id};
        if (my $pb_concept = $mapping->{umr_id}) {
            $unode->set_concept($pb_concept);
            if (grep /ARG[0-9]/, values %$mapping) {
                $unode->set_modal_strength('full-affirmative');
                $unode->set_aspect('activity');  # TODO: Value.
            }
        }
    }
}

{   my %FUNCTOR_MAPPING = (
        'ACT'   => 'ARG0',
        'PAT'   => 'ARG1',
        'ADDR'  => 'ARG2',
        'ORIG'  => 'source',
        'EFF'   => 'effect',  #NOT in UMR
    ##### TEMPORAL ###########################
        'TWHEN' => 'temporal',
        'TFHL' => 'duration',
        'TFRWH' => 'temporal',
        'THL'   => 'duration',
        'THO' => 'frequency',
        'TOWH' => 'temporal',
        'TPAR' => 'temporal',
        'TSIN' => 'temporal',
        'TTILL' => 'temporal',
    ##### SPATIAL ###########################
        'DIR1'  => 'start',
        'DIR2'  => 'path',
        'DIR3'  => 'goal',
        'LOC'   => 'place',
    ##### CAUSAL ###########################
        'AIM'   => 'purpose',
        'CAUS'  => 'cause',
        'CNCS' => 'concession',
        'COND' => 'condition',
        'INTT' => 'purpose',
    ##### MANNER ###########################
        'ACMP'  => 'companion',
    #    'CPR' => 'compared-to',
        'CRIT' => 'according-to',  #temporarily
        'DIFF' => 'extent',
        'EXT' => 'extent',
        'MANN'  => 'manner',
        'MEANS' => 'instrument',
        'NORM' => 'according-to',  #temporarily
        'REG'  => 'manner',
        'RESL' => 'result',  # NOT in UMR
        'RESTR' => 'subtraction',
    ##### NEW ###########################
        'BEN'   => 'affectee',
        'CONTRD' => 'contrast-91',
        'HER'   => 'source',
        'SUBS' => 'substitute',
    ##### NOMINAL ###########################
        'APP'   => 'poss',  # ?? or 'part' ??
        'AUTH' => 'source',
        'ID' => 'name',
        'MAT' => 'mod',  # TODO
        'RSTR'  => 'mod',

##### coap - COORDINATION ###########################
        # relations "with-91" take ARG1, ARG2, the rest takes op1, op2...
        'ADVS' => 'but-91',        # keyword
        'CONFR' => 'contrast-91',  # event
        'CONJ' => 'and',
        'CONTRA' => 'contra',       # NOT in UMR
        'CSQ' => 'consecutive',
        'DISJ' => 'exclusive-disjunctive',
        'GRAD' => 'and',
        'REAS' => 'have-cause-91',  # event
    );
    sub translate_non_valency_functor
    {
        my ($self, $tnode, $unode) = @_;
        $unode->set_functor($FUNCTOR_MAPPING{ $tnode->{functor} }
                            // $tnode->{functor});
    }

    sub adjust_coap
    {
        my ($self, $unode, $tnode) = @_;
        my @members = $tnode->get_coap_members({direct_only => 1});
        my @functors = $self->most_frequent_functor(map $_->{functor}, @members);
        my $relation = $FUNCTOR_MAPPING{ $functors[0] } // $functors[0];
        $unode->set_concept($unode->functor);
        $unode->set_functor($relation // 'EMPTY');
        my $prefix = $relation =~ /-91/ ? 'ARG' : 'op';
        my $i = 1;
        for my $member (@members) {
            my $umember = get_corresponding_unode($unode, $member, $unode->root);
            $umember->set_functor($prefix . $i++);
        }
    }
}

{   my %DISPATCH = (
        -1 => sub {},
         0 => sub { push @{ $_[0] }, $_[1] },
         1 => sub { @{ $_[0] } = ($_[1]) });
    sub most_frequent_functor
    {
        my ($self, @functors) = @_;
        my %functor_tally;
        ++$functor_tally{$_} for @functors;
        my @maxfunctors = (each %functor_tally)[0];
        while (my ($f, $t) = each %functor_tally) {
            $DISPATCH{ $t <=> $functor_tally{ $maxfunctors[0] } }
                ->(\@maxfunctors, $f);
        }
        log_warn("More than 1 most frequent functor: @maxfunctors")
            if @maxfunctors > 1;
        return @maxfunctors
    }
}

{
    my %T_LEMMA2CONCEPT = (
        '#PersPron' => 'entity',
        '#Gen' => 'entity',
        '#Unsp' => 'entity',
    );
    sub set_concept
    {
        my ($self, $unode, $tnode) = @_;
        my $tlemma = $tnode->t_lemma;
        $unode->set_concept($T_LEMMA2CONCEPT{$tlemma} // $tlemma);
        return
    }
}

sub add_tnode_to_unode
{
    my ($self, $tnode, $unode) = @_;
    $unode->set_tnode($tnode);
    # Set u-node attributes based on the t-node.
    $unode->_set_ord($tnode->ord());
    $self->set_concept($unode, $tnode);
    $self->translate_val_frame($tnode, $unode);
    $self->translate_non_valency_functor($tnode, $unode);
    $unode->copy_alignment($tnode);
    return $unode
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2U::BuildUtree

=head1 DESCRIPTION

A skeleton of the UMR tree is created from the tectogrammatical tree.

=head1 PARAMETERS

Required:

=over

=item language

=back

Optional:

Currently none.

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

Jan Stepanek <stepanek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
