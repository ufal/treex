# -*- encoding: utf-8 -*-
package Treex::Block::T2U::BuildUtree;
use Moose;
use Treex::Core::Common;
use Treex::Tool::UMR::Common qw{ maybe_set };
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

sub build_subtree {
    my ($self, $tparent, $uparent) = @_;
    for my $tnode ($tparent->get_children({ordered => 1})) {
        if ('#Neg' eq $tnode->t_lemma && 'RHEM' eq $tnode->functor) {
            log_warn("Skipping " . $tnode->t_lemma . " children "
                     . $tnode->id)
                if $tnode->children;
            $self->negate_parent($uparent);
            if (my $lex = $tnode->get_lex_anode) {
                $uparent->add_to_alignment($lex);
            }

        } else {
            my $unode = $uparent->create_child();
            $unode = $self->add_tnode_to_unode($tnode, $unode);
            $self->build_subtree($tnode, $unode);
        }
    }
    return
}

sub negate_parent
{
    my ($self, $uparent) = @_;
    $uparent->set_polarity;
    return
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
        }
    }
}

{   my %FUNCTOR_MAPPING = (
    ##### ROOT NODES ###########################
    # Only applies when not in the root position
        'PAR' => 'parenthesis',
        'PARTL' => 'interjection',
        'VOCAT' => 'vocative',

    ##### ACTANTS ##############################
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
        'CNCS' => 'but-91',  # sub->coord!
        'COND' => 'condition',
        'INTT' => 'purpose',
    ##### MANNER ###########################
        'ACMP'  => 'companion',
        'CPR' => 'comparison',
        'CRIT' => 'regard',
        'DIFF' => 'extent',
        'EXT' => 'extent',
        'MANN'  => 'manner',
        'MEANS' => 'instrument',
        # 'NORM' => 'according-to',  #temporarily
        'REG'  => 'regard',
        'RESL' => 'result',  # NOT in UMR
        'RESTR' => 'subtraction',
    ##### NEW ###########################
        'BEN'   => 'affectee',
        'CONTRD' => 'contrast-91', # sub->coord!
        'HER'   => 'source',
        'SUBS' => 'substitute',
    ##### NOMINAL ###########################
        # COMPL done in AdjustStructure
        'APP'   => 'possessor',  # ?? or 'part' ??
        'AUTH' => 'source',
        'ID' => 'name', # ??
        'MAT' => 'mod',
        'RSTR'  => 'mod',
    ##### NOMINAL ###########################
        'CPHR' => 'predicative-noun',
        'DPHR' => 'part-of-phraseme',
        # 'FPHR' => '', # ??

##### coap - COORDINATION ###########################
        # relations with "-91" take ARG1, ARG2, the rest takes op1, op2...
        'ADVS' => 'but-91',        # keyword
        'CONFR' => 'contrast-91',  # event
        'CONJ' => 'and',
        'CONTRA' => 'contra-entity',       # NOT in UMR
        'CSQ' => 'have-result-91',
        'DISJ' => 'or', # exclusive-disjunctive
        'GRAD' => 'gradation',
        'REAS' => 'have-cause-91',  # event
        'OPER' => 'math',
        'APPS' => 'identity-91', # ??

        'CM' => 'clausal-marker',
        'ATT' => 'clausal-marker',
        # 'INTF' => '',
        'MOD' => 'clausal-marker',
        'PREC' => 'clausal-marker',
        'RHEM' => 'clausal-marker',
    );
    sub translate_non_valency_functor
    {
        my ($self, $tnode, $unode) = @_;
        $unode->set_functor($FUNCTOR_MAPPING{ $tnode->{functor} }
                            // ('!!' . $tnode->{functor}));
    }

    sub adjust_coap
    {
        my ($self, $unode, $tnode) = @_;

        # To find the functor, we need all members, not just the direct ones.
        my @functors = map {
            ($_->functor =~ /^(?:PRED|DENOM|PAR(?:TL)?|VOCAT)$/
             && $tnode->root
                == ($tnode->_get_transitive_coap_root // $tnode)->parent)
            ? '*ROOT*'  # Will be ignored in root position, anyway.
            : $_->functor
        } $tnode->get_coap_members;
        my @relations = $self->most_frequent_relation(
            map $FUNCTOR_MAPPING{$_} // $_, @functors);

        log_warn("Coordination of different relations: @relations")
            if @relations > 1;
        my $relation = $relations[0];
        $unode->set_concept($unode->functor);
        $unode->set_functor($relation // 'EMPTY');
        my $prefix = $unode->concept =~ /-91/ ? 'ARG' : 'op';

        my @members = $tnode->get_coap_members({direct_only => 1});
        @members = reverse @members if 'ARG' eq $prefix
                                    && $self->should_reverse($tnode, @members);
        my $i = 1;
        for my $member (@members) {
            my ($umember) = $member->get_referencing_nodes('t.rf');
            log_warn("ARG$i under " . $unode->concept)
                if 'ARG' eq $prefix && $i > 2;
            $umember->set_functor($prefix . $i++);
        }
    }
}

sub should_reverse {
    my ($self, $tnode, @members) = @_;
    my $is_coord_before_all = @members == grep $tnode->ord < $_->ord,
                                          @members;
    my $should_reverse = $is_coord_before_all;
    return $should_reverse
}

{   my %DISPATCH = (
        -1 => sub {},
         0 => sub { push @{ $_[0] }, $_[1] },
         1 => sub { @{ $_[0] } = ($_[1]) });
    sub most_frequent_relation
    {
        my ($self, @relations) = @_;
        my %relation_tally;
        ++$relation_tally{$_} for @relations;
        log_warn('Coordination of different relations: '
                 . join ' ', keys %relation_tally)
            if 1 < keys %relation_tally;
        my @maxrelations = (each %relation_tally)[0];
        while (my ($f, $t) = each %relation_tally) {
            $DISPATCH{ $t <=> $relation_tally{ $maxrelations[0] } }
                ->(\@maxrelations, $f);
        }
        log_warn("More than 1 most frequent relation: @maxrelations")
            if @maxrelations > 1;
        return @maxrelations
    }
}

{
    my %T_LEMMA2CONCEPT = (
        '#PersPron' => 'entity',
        '#Gen'      => 'entity',
        '#Unsp'     => 'entity',
        '#Oblfm'    => 'entity',
        '#Benef'    => 'entity',
        '#EmpNoun'  => 'entity',
        '#EmpVerb'  => 'event',
    );
    sub set_concept
    {
        my ($self, $unode, $tnode) = @_;
        my $tlemma = $tnode->t_lemma;
        $unode->set_concept($T_LEMMA2CONCEPT{$tlemma} // $tlemma);
        return
    }
}

{   my %EVENT;
    @EVENT{qw{
        belong-91 correlate-91 emit-sound-91 exist-91 have-91 have-actor-91
        have-affectee-91 have-age-91 have-cause-91 have-causer-91 have-color-91
        have-companion-91 have-configuration-91 have-degree-91 have-degree-92
        have-direction-91 have-duration-91 have-example-91 have-experience-91
        have-extent-91 have-force-91 have-frequency-91 have-goal-91
        have-group-91 have-instrument-91 have-manner-91 have-material-91
        have-medium-91 have-mod-91 have-org-role-92 have-orientation-91
        have-other-role-91 have-part-91 have-path-91 have-place-91
        have-purpose-91 have-quant-91 have-reason-91 have-recipient-91
        have-rel-role-92 have-result-91 have-role-91 have-size-91
        have-source-91 have-start-91 have-temporal-91 have-theme-91
        have-topic-91 have-undergoer-91 have-vocative-91 identity-91 include-91
        infer-91 mean-91 resemble-91 say-91 }} = ();
    sub set_nodetype
    {
        my ($self, $unode, $tnode) = @_;
        return if 'ref' eq ($unode->nodetype // "");

        my $nodetype =
            ('v' eq ($tnode->attr('gram/sempos') // "")
             || '#EmpVerb' eq $tnode->{t_lemma}
             || exists $EVENT{ $unode->concept })   ? 'event'

            : ('coap' eq $tnode->nodetype
               && $unode->concept !~ /-91$/)        ? 'keyword'

                                                    : 'entity';
        $unode->set_nodetype($nodetype);
        return
    }
}

{   my %ASPECT_STATE;
    @ASPECT_STATE{qw{ muset musit mít chtít hodlat moci moct dát_se smět
                      dovést umět lze milovat nenávidět prefereovat přát_si
                      myslet myslit znát vědět souhlasit věřit pochybovat
                      hádat představovat_si znamenat pamatovat_si podezřívat
                      rozumět porozumět vonět zdát_se vidět slyšet znít
                      vlastnit patřit }} = ();
    sub deduce_aspect {
        my ($self, $unode, $tnode) = @_;

        return 'state' if exists $ASPECT_STATE{ $tnode->t_lemma };

        my $a_node = $tnode->get_lex_anode or return 'state';

        my $tag = $a_node->tag;
        my $m_aspect = substr $tag, -3, 1;
        return 'performance' if 'P' eq $m_aspect;

        my $m_lemma = $a_node->lemma;
        return 'habitual' if 'I' eq $m_aspect && $m_lemma =~ /_\^\(\*4[ai]t\)/;
        return 'activity' if 'I' eq $m_aspect;
        return 'process'  if 'B' eq $m_aspect;
        return 'state'
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
    $unode->copy_alignment($tnode) unless $tnode->is_generated;
    $self->set_nodetype($unode, $tnode);
    maybe_set(person => $unode, $tnode);
    maybe_set(number => $unode, $tnode);
    $unode->set_aspect($self->deduce_aspect($unode, $tnode))
        if 'event' eq $unode->nodetype;
    $unode->set_polarity
        if 'neg1' eq ($tnode->gram_negation // "")
        || 'negat' eq ($tnode->gram_indeftype // "")
        || $self->negated_with_missing_gram($tnode);

    return $unode
}

sub negated_with_missing_gram {
    my ($self, $tnode) = @_;
    my %gram ;
    @gram{ keys %{ $tnode->get_attr('gram') // {} } } = ();
    delete $gram{sempos};
    return if keys %gram;

    my $alex = $tnode->get_lex_anode or return;

    log_debug("POLARITY guess on morph $tnode->{id}"),
            return 1
        if 'N' eq substr $alex->tag, 10, 1;
    return
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
