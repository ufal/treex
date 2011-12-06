package Treex::Block::Sample::Trees;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Parallel::MessageBoard;

extends 'Treex::Block::Sample::Base';

has iterations => (is => 'rw', isa => 'Int', default => 10); 

has other_languages => ( is => 'rw', isa => 'Str', default => '');

sub process_documents {
    my ( $self, $documents_rf ) = @_;

    my $ALPHA = 0.01;
    my $C_ALPHA = 1000;

    my $ALIGNMENT_PENALTY = 0.000001;
    my $PUNCTUATION_PENALTY = 0.01;

    my %count;
    my %diff_count;

    my @other_languages = split /-/, $self->other_languages;

    # compute initial counts
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            foreach my $lang ($self->language, @other_languages) {
                foreach my $node ($bundle->get_tree($lang, 'a', $self->selector)->get_descendants) {
                    my $tag = $node->tag;
                    my $parent_tag = $node->get_parent->is_root ? '<root>' : $node->get_parent->tag;
                    my $direction = $node->ord < $node->get_parent->ord ? 'L' : 'R';
                    $count{"$lang $tag $parent_tag $direction"}++;
                }
            }
        }
    }

    if ($self->_parallel_execution) {
        
        # send the initial count of this job to the others
        $self->message_board->write_message( { initial_count => \%count } );

        # let's wait for all blocks to send their initial counts
        $self->message_board->synchronize;

        # collect counts
        foreach my $message ( $self->message_board->read_messages ) {
            my %new_counts = %{$message->{initial_count}};
            foreach my $edge ( keys %new_counts ) {
                $count{$edge} += $new_counts{$edge};
            }
        }
    }

    # compute initial logprob
    my $logprob = 0;
    my $total_count = 0;
    foreach my $edge (keys %count) {
        foreach my $i (0 .. $count{$edge} - 1) {
            $logprob += log(($i + $ALPHA) / ($total_count + $C_ALPHA));
        }
    }

    # precompute alignment links
    my %alignment;
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            foreach my $lang (@other_languages) {
                foreach my $node ($bundle->get_tree($lang, 'a', $self->selector)->get_descendants) {
                    my ($nodes, $types) = $node->get_aligned_nodes();
                    foreach my $i (0 .. $#$nodes) {
                        if ($$types[$i] =~ /int/) {
                            $alignment{$lang}{$node} = $$nodes[$i];
                            $alignment{$self->language}{$$nodes[$i]} = $node;
                        }
                    }
                }
            }
        }
    }

    # add penalties for not aligned edges to the logprob
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            foreach my $lang1 ($self->language, $other_languages[0]) {
                my $lang2 = $lang1 eq $self->language ? $other_languages[0] : $self->language;
                foreach my $node ($bundle->get_tree($lang1, 'a', $self->selector)->get_descendants) {
                    $logprob += log($ALIGNMENT_PENALTY) if !aligned_edge($node, $node->get_parent, $lang2, \%alignment);
                    $logprob += log($PUNCTUATION_PENALTY) if ($node->get_parent->form || 'undef') =~ /^[\.,!\?;]$/;
                }
            }
        }
    }

    # Gibbs sampling
    foreach my $iteration (1 .. $self->iterations) {
    log_info "Iteration $iteration, logprob $logprob";
        foreach my $document (@$documents_rf) {
            foreach my $bundle ($document->get_bundles) {
                foreach my $lang1 ($self->language, $other_languages[0]) {
                    my $lang2 = $lang1 eq $self->language ? $other_languages[0] : $self->language;
                    my $aroot = $bundle->get_tree($lang1, 'a', $self->selector);
                    foreach my $node ($aroot->get_descendants) {
                        my $tag = $node->tag;
                        my $parent_tag = $node->get_parent->is_root ? '<root>' : $node->get_parent->tag;
                        my $direction = $node->ord < $node->get_parent->ord ? 'L' : 'R';
                        my $distance = $node->get_parent->is_root ? 20 : $node->ord - $node->get_parent->ord;
                        my $edge = "$lang1 $tag $parent_tag $direction";
                        $diff_count{$edge}--;
                        my $new_logprob = $logprob - log(($count{$edge} || 0) + ($diff_count{$edge} || 0) + $ALPHA) - log( 1 / (abs($distance)**2));
                        $new_logprob -= log($ALIGNMENT_PENALTY) if !aligned_edge($node, $node->parent, $lang2, \%alignment);
                        $new_logprob -= log($PUNCTUATION_PENALTY) if ($node->get_parent->form || 'undef') =~ /^[\.,!\?;]$/;
                        my %is_descendant;
                        map {$is_descendant{$_} = 1} $node->get_descendants;
                        my @possible_parents = grep {!$is_descendant{$_} && $_ ne $node} ($aroot->get_descendants, $aroot);
                        my @new_logprob;
                        my @weight;
                        my @new_edge;
                        my $sum_weight = 0;
                        foreach my $p (0 .. $#possible_parents) {
                            my $new_direction = $node->ord < $possible_parents[$p]->ord ? 'L' : 'R';
                            my $new_parent_tag = $possible_parents[$p] eq $aroot ? '<root>' : $possible_parents[$p]->tag;
                            my $new_distance = $possible_parents[$p]->is_root ? 20 : $node->ord - $possible_parents[$p]->ord;
                            $new_edge[$p] = "$lang1 $tag $new_parent_tag $new_direction";
                            $new_logprob[$p] = $new_logprob + log(($count{$new_edge[$p]} || 0) + ($diff_count{$new_edge[$p]} || 0) + $ALPHA) + log( 1 / (abs($new_distance)**2));
                            $new_logprob[$p] += log($ALIGNMENT_PENALTY) if !aligned_edge($node, $p, $lang2, \%alignment);
                            $new_logprob[$p] += log($PUNCTUATION_PENALTY) if ($possible_parents[$p]->form || 'undef') =~ /^[\.,!\?;]$/;
                            $weight[$p] = exp($new_logprob[$p] - $logprob);
                            $sum_weight += $weight[$p];
                        }
                        my $random_value = rand($sum_weight);
                        my $current_value = 0;
                        foreach my $p (0 .. $#possible_parents) {
                            $current_value += $weight[$p];
                            if ($current_value >= $random_value) {
                                $logprob = $new_logprob[$p];
                                $diff_count{$new_edge[$p]}++;
                                $node->set_parent($possible_parents[$p]);
                                last;
                            }
                        }
                    }
                }
            }
        }

        if ($self->_parallel_execution) {

            # send count differences to the other jobs
            $self->message_board->write_message( { diff_count => \%diff_count } );
        }
        # update counts of this job
        foreach my $edge ( keys %diff_count ) {
             $count{$edge} += $diff_count{$edge};
        }
        %diff_count = ();
        
        if ($self->_parallel_execution) {
            # let's wait for all blocks to send their diff counts
            $self->message_board->synchronize;
        
            # collect update of counts from the other jobs
            foreach my $message ( $self->message_board->read_messages ) {
                my %new_counts = %{$message->{diff_count}};
                foreach my $edge ( keys %new_counts ) {
                    $count{$edge} += $new_counts{$edge};
               }
            }
        }
    }
    # save documents # TEMPORARY HACK !!!
    foreach my $document (@$documents_rf) {
        $document->save($document->full_filename . '.treex');
    }
}

sub aligned_edge {
    my ($node, $parent, $language, $alignment) = @_;
    return ( $$alignment{$language}{$node}
          && $$alignment{$language}{$parent}
          && $$alignment{$language}{$node}->get_parent eq $$alignment{$language}{$parent} ) ? 1 : 0;
}

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

