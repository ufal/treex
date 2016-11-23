package Treex::Block::T2T::CS2CS::MarkNegationCueAndScope;

use Moose;
use Treex::Core::Common;
use List::MoreUtils "uniq";
extends 'Treex::Core::Block';

my %neg_tlemmas = (
    ne => 1,
    nikoli => 1,
    nikoliv => 1,
    '#Neg' => 1,
);

my %tfa_ok = (
    f => {f => 1},
    c => {c => 1},
    t => {t => 1, c => 1}
);

sub process_ttree {
    my ( $self, $troot ) = @_;
    
    my @descendants = $troot->get_descendants();

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
    }

    # type B/C
    my @neg_tnodes_BC = grep { defined $neg_tlemmas{$_->t_lemma} } @descendants;
    foreach my $neg_tnode (@neg_tnodes_BC) {
        # CUE
        my $neg_anode = $neg_tnode->get_lex_anode;
        if (defined $neg_anode) {
            # type B
            # e.g. "ne nadarmo se říká..."
            # cue: "ne"
            $negation_id++;
            $neg_anode->wild->{negation}->{$negation_id}->{cue} = 1;
        } else {
            # type C
            # e.g. "nepřijel na koncert" ("#Neg přijet koncert")
            # cue: "ne"
            my @nodes = ($neg_tnode);
            do {
                my @eparents = map { $_->get_eparents } @nodes;
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
                $negation_id++;
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
        my @potential_scope_tnodes;
        push @potential_scope_tnodes, $neg_tnode->get_eparents({following_only => 1});
        push @potential_scope_tnodes, $neg_tnode->get_siblings({following_only => 1});
        @potential_scope_tnodes = sort {$a->ord <=> $b->ord} @potential_scope_tnodes;
        my ($tfa) = map { $_->tfa } grep { $_->tfa } @potential_scope_tnodes;

        # SCOPE TNODES
        if (defined $tfa) {
            # type 1/2
            map  { $_->wild->{negation}->{$negation_id}->{scope} = 1 }
                uniq
                sort { $a->ord <=> $b->ord }
                map  { $_->get_anodes }
                map  { $_->get_descendants({add_self=>1}) }
                grep { defined $_->tfa && $tfa_ok{$tfa}->{$_->tfa} }
                @potential_scope_tnodes;
        } else {
            # type 3
            $neg_anode->wild->{negation}->{$negation_id}->{scope} = 1;
        }
    }

    $troot->get_zone->get_atree->wild->{negation}->{negations_count} = $negation_id;

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
