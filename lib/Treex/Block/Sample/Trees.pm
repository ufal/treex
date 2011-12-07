package Treex::Block::Sample::Trees;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Parallel::MessageBoard;

extends 'Treex::Block::Sample::Base';

has iterations => (is => 'rw', isa => 'Int', default => 10); 
has other_languages => ( is => 'rw', isa => 'Str', default => '');
has alpha => (is => 'rw', default => 0.01);
has punctuation_penalty => (is => 'rw', default => 0.01);
has _alignment => (is => 'rw', default => sub { my %hash; return \%hash; });
has _count => (is => 'rw', default => sub { my %hash; return \%hash; });
has _diff_count => (is => 'rw', default => sub { my %hash; return \%hash; });


sub increase_count {
    my ($self, $key, $value) = @_;
    $self->_diff_count->{$key} += $value;
}


sub get_count {
    my ($self, $key) = @_;
    return ($self->_count->{$key} || 0) + ($self->_diff_count->{$key} || 0);
}

sub reset_counts {
    my ($self) = @_;
    my %hash;
    $self->_set_diff_count(\%hash);
}

sub update_counts {
    my ($self) = @_;
    
    # send the initial count of this job to the others
    $self->message_board->write_message( { count => $self->_diff_count } );
    
    # let's wait for all blocks to send their initial counts
    $self->message_board->synchronize;

    # collect count changes of others
    foreach my $message ( $self->message_board->read_messages ) {
        my %new_counts = %{$message->{count}};
        foreach my $edge ( keys %new_counts ) {
            $self->_count->{$edge} += $new_counts{$edge};
        }
    }
    # collect my count changes
    foreach my $edge (keys %{$self->_diff_count}) {
        $self->_count->{$edge} += $self->_diff_count->{$edge};
    }

    # delete count changes
    %{$self->_diff_count} = ();
}


sub make_change {
    my ($self, $node, $parent, $type, $change_counts, $language) = @_;
    my $tag = $node->tag;
    my $parent_tag = $parent->is_root ? '<root>' : $parent->tag;
    my $direction = $node->ord < $parent->ord ? 'L' : 'R';
    my $distance = $parent->is_root ? 20 : $node->ord - $parent->ord;
    my $edge = "$language $tag $parent_tag $direction";
    my $diff_logprob = 0;
    if ($type eq 'del') {
        $diff_logprob -= log($self->get_count($edge) - 1 + $self->alpha) + log( 1 / (abs($distance)**2));
        $diff_logprob -= log($self->punctuation_penalty) if ($parent->form || 'undef') =~ /^[\.,!\?;]$/;
        $self->increase_count($edge, -1) if $change_counts;
    }
    elsif ($type eq 'ins') {
        $diff_logprob += log($self->get_count($edge) + $self->alpha) + log( 1 / (abs($distance)**2));
        $diff_logprob += log($self->punctuation_penalty) if ($parent->form || 'undef') =~ /^[\.,!\?;]$/;
        $self->increase_count($edge, +1) if $change_counts;
    }
    return $diff_logprob;
}


sub compute_counts_and_logprob {
    my ($self, $documents_rf) = @_;
    my $total = 0;
    my $logprob = 0;
    $self->reset_counts();
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            foreach my $node ($bundle->get_tree($self->language, 'a', $self->selector)->get_descendants) {
                $logprob += $self->make_change($node, $node->get_parent, 'ins', 1, $self->language) - log($total + 10000);
                $total++;
            }
        }
    }
    return $logprob;
}

sub process_documents {
    my ( $self, $documents_rf ) = @_;

    my $ALPHA = 0.01;
    my $C_ALPHA = 1000;

    my $ALIGNMENT_PENALTY = 0.01;
    my $PUNCTUATION_PENALTY = 0.01;

    my @other_languages = split /-/, $self->other_languages;

    my $logprob = $self->compute_counts_and_logprob($documents_rf);
    print STDERR "Initial logprob: $logprob\n";
    
    $self->update_counts if $self->_parallel_execution;

    # precompute alignment links
#    foreach my $document (@$documents_rf) {
#        foreach my $bundle ($document->get_bundles) {
#                foreach my $node ($bundle->get_tree($self->language, 'a', $self->selector)->get_descendants) {
#                    my ($nodes, $types) = $node->get_aligned_nodes();
#                    foreach my $i (0 .. $#$nodes) {
#                        if ($$types[$i] =~ /int/) {
#                            $alignment{$node} = $$nodes[$i];
#                            $alignment{$$nodes[$i]} = $node;
#                        }
#                    }
#            }
#        }
#    }

#    # add penalties for not aligned edges to the logprob
#    if (@other_languages) {
#        foreach my $document (@$documents_rf) {
#            foreach my $bundle ($document->get_bundles) {
#                foreach my $lang1 ($self->language, $other_languages[0]) {
#                    my $lang2 = $lang1 eq $self->language ? $other_languages[0] : $self->language;
#                    foreach my $node ($bundle->get_tree($lang1, 'a', $self->selector)->get_descendants) {
#                        $logprob += log($ALIGNMENT_PENALTY) if !aligned_edge($node, $node->get_parent->id);
#                        $logprob += log($PUNCTUATION_PENALTY) if ($node->get_parent->form || 'undef') =~ /^[\.,!\?;]$/;
#                    }
#                }
#            }
#        }
#    }

    # Gibbs sampling
    foreach my $iteration (1 .. $self->iterations) {
        foreach my $document (@$documents_rf) {
            foreach my $bundle ($document->get_bundles) {
                foreach my $lang1 ($self->language, @other_languages) {
                    my $lang2;
                    if (@other_languages) {
                        $lang2 = $lang1 eq $self->language ? $other_languages[0] : $self->language;
                    }
                    my $aroot = $bundle->get_tree($lang1, 'a', $self->selector);
                    my @shuffled_nodes = List::Util::shuffle $aroot->get_descendants;
                    foreach my $node (@shuffled_nodes) {
#print STDERR "$logprob ";
                        my $new_logprob = $logprob + $self->make_change($node, $node->get_parent, 'del', 1, $lang1);
#print STDERR "$new_logprob ";
                        my %is_descendant;
                        map {$is_descendant{$_} = 1} $node->get_descendants;
                        my @possible_parents = grep {!$is_descendant{$_} && $_ ne $node} ($aroot->get_descendants, $aroot);
                        my @new_logprob;
                        my @weight;
                        my $sum_weight = 0;
                        foreach my $p (0 .. $#possible_parents) {
                            $new_logprob[$p] = $new_logprob + $self->make_change($node, $possible_parents[$p], 'ins', 0, $lang1);
                            $weight[$p] = exp($new_logprob[$p] - $logprob);
                            $sum_weight += $weight[$p];
                        }
                        my $random_value = rand($sum_weight);
                        my $current_value = 0;
                        my $chosen_parent = 0;
                        foreach my $p (0 .. $#possible_parents) {
                            $current_value += $weight[$p];
                            if ($current_value >= $random_value) {
                                $logprob = $new_logprob[$p];
#print STDERR "$logprob\n";
                                $self->make_change($node, $possible_parents[$p], 'ins', 1, $lang1);
                                $node->set_parent($possible_parents[$p]);
                                last;
                            }
                        }
=c
                        if ($is_descendant{$chosen_parent}) {
                            my $n = $chosen_parent;
                            my @nodes_in_cycle;
                            while ($n ne $node) {
                                push @nodes_in_cycle, $n;
                                $n = $n->get_parent;
                            }
                            push @nodes_in_cycle, $node;
                            @new_logprob = ();
                            foreach my $n (@nodes_in_cycle) {
                                my $d_direction = $n->ord < $n->get_parent->ord ? 'L' : 'R';
                                my $d_parent_tag = $n-possible_parents[$p] eq $aroot ? '<root>' : $possible_parents[$p]->tag;
                                my $d_distance = $possible_parents[$p]->is_root ? 20 : $node->ord - $possible_parents[$p]->ord;

=cut

                    }
                }
            }
        }
        log_info "Iteration $iteration, logprob $logprob";
        $self->update_counts if $self->_parallel_execution;
    }

    # compute counts and logprob
    $logprob = $self->compute_counts_and_logprob($documents_rf);
    print STDERR "Final logprob: $logprob\n";


    # save documents # TEMPORARY HACK !!!
    foreach my $document (@$documents_rf) {
        $document->save($document->full_filename . '.treex');
    }
}
=c
sub aligned_edge {
    my ($node, $parent) = @_;
    return (defined $alignment{$node}
        && defined $alignment{$parent}
        && $alignment{$node}->get_parent eq $alignment{$parent}
        ? 1 : 0);
}
=cut
1;

=encoding utf-8

=head1 NAME

Treex::Block::Sample::Trees

=head1 DESCRIPTION

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

