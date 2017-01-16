package Treex::Block::T2T::CS2CS::MarkNegationCueAndScope;

use Moose;
use Treex::Core::Common;
use List::MoreUtils "uniq";
extends 'Treex::Core::Block';

has type => ( is => 'rw', isa => 'Str', default => '' );

has special => ( is => 'rw', isa => 'Str', default => '' );

my %neg_tlemmas = (
    ne => 1,
    nikoli => 1,
    nikoliv => 1,
    '#Neg' => 1,
);

my %tfa_ok_hash = (
    f => {f => 1},
    c => {c => 1},
    t => {t => 1, c => 1}
);

# for coap root, get the first defined tfa of its member child (recursively)
sub tfa_ok {
    my ($tfa, $tnode) = @_;

    if (defined $tnode->tfa) {
        return $tfa_ok_hash{$tfa}->{$tnode->tfa};
    } elsif ($tnode->nodetype eq 'coap') {
        my ($member_child) = grep {$_->is_member} $tnode->get_children({ordered => 1});
        return tfa_ok($tfa, $member_child);
    } else {
        return 0;  # TODO or 1?
    }
}

sub process_ttree {
    my ( $self, $troot ) = @_;
    
    my @descendants = $troot->get_descendants();
    my $aroot = $troot->get_zone->get_atree;
    my $negation_id = 0;

    # type A
    # e.g. "nevelký"
    # cue: "ne"
    # scope: "velký"
    my @neg_tnodes_A = grep { defined $_->gram_negation && $_->gram_negation eq 'neg1' } @descendants;
    foreach my $neg_tnode (@neg_tnodes_A) {
        $negation_id++;
        my $neg_anode = $neg_tnode->get_lex_anode;
        $neg_anode->wild->{negation}->{$negation_id}->{cue} = 1;
        $neg_anode->wild->{negation}->{$negation_id}->{cue_from} = 0;
        $neg_anode->wild->{negation}->{$negation_id}->{cue_to} = 1;
        $neg_anode->wild->{negation}->{$negation_id}->{scope} = 1;
        $neg_anode->wild->{negation}->{$negation_id}->{scope_from} = 2;
        $neg_anode->wild->{negation}->{$negation_id}->{scope_to} = length($neg_anode->form)-1;
        if ( (!$self->type || $self->type eq 'A') && !$self->special) {
            push @{$aroot->wild->{negation}->{negation_ids}}, $negation_id;
        }
    }

    # type B/C
    my @neg_tnodes_BC = grep { defined $neg_tlemmas{$_->t_lemma} && $_->functor eq 'RHEM' } @descendants;
    foreach my $neg_tnode (@neg_tnodes_BC) {
        $negation_id++;
        my $type_ok;
        my $spec_ok;
        # CUE
        my $neg_anode = $neg_tnode->get_lex_anode;
        if (defined $neg_anode) {
            # type B
            # e.g. "ne nadarmo se říká..."
            # cue: "ne"
            $type_ok = !$self->type || $self->type eq 'B';
            $neg_anode->wild->{negation}->{$negation_id}->{cue} = 1;
        } else {
            # type C
            # e.g. "nepřijel na koncert" ("#Neg přijet koncert")
            # cue: "ne"
            $type_ok = !$self->type || $self->type eq 'C';
            my @nodes = ($neg_tnode);
            do {
                my @eparents = grep { !$_->is_root } map { $_->get_eparents } @nodes;
                my @negated_verb_anodes =
                    grep { $_->tag =~ /^V.{9}N/ }
                    map { $_->get_anodes  }
                    grep { $_->gram_sempos eq 'v' } @eparents;
                if (@negated_verb_anodes) {
                    $neg_anode = $negated_verb_anodes[0];
                } else {
                    @nodes = @eparents;
                }
            } while (@nodes && !defined $neg_anode);

            if (defined $neg_anode) {
                $neg_anode->wild->{negation}->{$negation_id}->{cue} = 1;
                $neg_anode->wild->{negation}->{$negation_id}->{cue_from} = 0;
                $neg_anode->wild->{negation}->{$negation_id}->{cue_to} = 1;
                $neg_anode->wild->{negation}->{$negation_id}->{scope_from} = 2;
                $neg_anode->wild->{negation}->{$negation_id}->{scope_to} = length($neg_anode->form)-1;
            } else {
                log_warn ("negated verb not found for negation tnode " . $neg_tnode->id);
                next;
            }
        }

        # SCOPE
        # Note: RHEM is never child of a coap root
        # Following parent and esiblings
        my @scope_candidates = grep { $_->follows($neg_tnode) }
            $neg_tnode->get_parent->get_echildren( {add_self => 1} );
        # First defined tfa
        my ($tfa) = map { $_->tfa }
            sort { $a->ord <=> $b->ord }
            grep { defined $_->tfa }
            @scope_candidates;
        if (defined $tfa) {
            # type 1/2
            # Add topological siblings (i.e. incl. coap root siblings)
            push @scope_candidates, $neg_tnode->get_siblings( {following_only => 1} );
            if ($self->special eq 'notfa' && !grep { !defined $_->tfa } @scope_candidates) {
                $spec_ok = 0;
            } elsif ($self->special eq 'coord' && !grep { $_->is_member || $_->nodetype eq 'coap' } @scope_candidates) {
                $spec_ok = 0;
            } else {
                $spec_ok = 1;
            }
            # Add all nodes with correct tfa and their descendants
            map { $_->wild->{negation}->{$negation_id}->{scope} = 1 }
                map  { $_->get_anodes }
                grep { $_->follows($neg_tnode) }
                map  { $_->get_descendants({add_self=>1}) }
                grep { tfa_ok($tfa, $_) }
                @scope_candidates;
        } else {
            # type 3
            $spec_ok = !$self->special;
            $neg_anode->wild->{negation}->{$negation_id}->{scope} = 1;
        }
        if ($type_ok && $spec_ok) {
            push @{$aroot->wild->{negation}->{negation_ids}}, $negation_id;
        }
    }

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::MarkNegationCueAndScope

=head1 DESCRIPTION

Detects and marks negation cues and scopes.

  # Node is the cue of a negation. As there can be multiple negations
  # in a sentence, they are given ids: 0, 1, 2...
  $cue_anode->wild->{negation}->{$negation_id}->{cue} = 1

  # Node is (part of) the scope of a negation.
  $scope_anode->wild->{negation}->{$negation_id}->{scope} = 1

  # Only first two characters are the cue (similarly for scope)
  $partial_cue_anode->wild->{negation}->{$negation_id}->{cue} = 1
  $partial_cue_anode->wild->{negation}->{$negation_id}->{cue_from} = 0
  $partial_cue_anode->wild->{negation}->{$negation_id}->{cue_to} = 1

=head1 AUTHOR

Rudolf Rosa

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
