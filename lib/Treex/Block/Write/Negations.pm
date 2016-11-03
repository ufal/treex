package Treex::Block::Write::Negations;

use Moose;
use Treex::Core::Common;
use List::MoreUtils "uniq";
extends 'Treex::Block::Write::BaseTextWriter';

my %neg_tlemmas = (
    ne => 1,
    nikoli => 1,
    nikoliv => 1,
    '#Neg' => 1,
);

sub process_ttree {
    my ( $self, $troot ) = @_;
    
    print { $self->_file_handle } $troot->get_zone->sentence, "\n";

    my @neg_tnodes = grep {
        (defined $_->gram_negation && $_->gram_negation eq 'neg1')
        || defined $neg_tlemmas{$_->t_lemma}
    } $troot->get_descendants({ordered => 1});
    
    # foreach my $neg_tnode (@neg_tnodes) {
    foreach my $negation_id (0..$#neg_tnodes) {
        my $neg_tnode = $neg_tnodes[$negation_id];
        # TODO: now string, future structured
        my $info;
        my $cue;
        my $scope;
        
        my $neg_anode = $neg_tnode->get_lex_anode;
        my $type;
        my $moreinfo = "";
        if (defined $neg_tnode->gram_negation && $neg_tnode->gram_negation eq 'neg1') {
            # type A
            $neg_anode->wild->{negation}->{$negation_id}->{cue} = 1;
            $neg_anode->wild->{negation}->{$negation_id}->{cue_from} = 0;
            $neg_anode->wild->{negation}->{$negation_id}->{cue_to} = 1;
            $neg_anode->wild->{negation}->{$negation_id}->{scope} = 1;
            $neg_anode->wild->{negation}->{$negation_id}->{scope_from} = 2;
            $neg_anode->wild->{negation}->{$negation_id}->{scope_to} = length($neg_anode->form)-1;
            $cue = (substr $neg_anode->form, 0, 2) . "-";
            $scope = "-" . (substr $neg_anode->form, 2);
            $type = "A";
        } else {
            # type B or C
            # cue
            if ($neg_tnode->t_lemma eq '#Neg') {
                $type = "C";
                $cue = "ne-";
                
                $neg_anode = undef;
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
                    $neg_anode->wild->{negation}->{$negation_id}->{cue} = 1;
                    $neg_anode->wild->{negation}->{$negation_id}->{cue_from} = 0;
                    $neg_anode->wild->{negation}->{$negation_id}->{cue_to} = 1;
                    $neg_anode->wild->{negation}->{$negation_id}->{scope_from} = 2;
                    $neg_anode->wild->{negation}->{$negation_id}->{scope_to} = length($neg_anode->form)-1;
                } else {
                    log_warn ("negated verb not found for negation tnode " . $neg_tnode->id);
                    next;
                }
            } else {
                $neg_anode->wild->{negation}->{$negation_id}->{cue} = 1;
                $cue = $neg_anode->form;
                $type = "B";
            }

            # scope
            my @right_parents = $neg_tnode->get_eparents({following_only => 1});
            my @right_sisters = $neg_tnode->get_siblings({following_only => 1});
            my @potential_scope_tnodes = (@right_parents, @right_sisters); # TODO undefs?
            @potential_scope_tnodes = sort {$a->ord <=> $b->ord} @potential_scope_tnodes;
            my ($tfa) = map { $_->tfa } grep { $_->tfa } @potential_scope_tnodes;

            # SCOPE TNODES
            if (!defined $tfa) {
                # type 3
                $moreinfo = " TYPE 3";
                $scope = $cue;
                $neg_anode->wild->{negation}->{$negation_id}->{scope} = 1;
            } else {
                $moreinfo = " SISTER: "
                    . ($potential_scope_tnodes[0]->get_lex_anode ?
                        $potential_scope_tnodes[0]->get_lex_anode->form : "(no lex anode)")
                    . " TYPE 1/2";
                my %tfa_ok = (
                    f => {f => 1},
                    c => {c => 1},
                    t => {t => 1, c => 1}
                );
                my @scope_anodes =
                    uniq
                    sort { $a->ord <=> $b->ord }
                    map { $_->get_anodes }
                    grep { $neg_tnode->precedes($_) }
                    map { $_->get_descendants({add_self=>1}) }
                    grep {
                        defined $_->tfa && $tfa_ok{$tfa}->{$_->tfa}
                    } @potential_scope_tnodes;
                map {$_->wild->{negation}->{$negation_id}->{scope} = 1} @scope_anodes;
                $scope = join ' ', map { $_->form  } @scope_anodes;
            }
        }
        
        $info = "[$type on " . $neg_anode->ord . " " . $neg_anode->form . "$moreinfo]";

        print { $self->_file_handle } $info, " CUE: ", $cue, "  SCOPE: ", $scope, "\n";
    }

    print { $self->_file_handle } "\n";

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::Negations

=head1 DESCRIPTION

Prints out sentences together with their negation cues and their scopes.

=head1 AUTHOR

Rudolf Rosa

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
