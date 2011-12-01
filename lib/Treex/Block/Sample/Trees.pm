package Treex::Block::Sample::Trees;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Parallel::MessageBoard;

extends 'Treex::Block::Sample::Base';

sub process_documents {
    my ( $self, $documents_rf ) = @_;

    my $ALPHA = 0.01;
    my $C_ALPHA = 1000;

    my %count;
    my %diff_count;

    # compute initial counts
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            foreach my $node ($bundle->get_tree($self->language, 'a', $self->selector)->get_descendants) {
                my $tag = $node->tag;
                my $parent_tag = $node->get_parent->is_root ? '<root>' : $node->get_parent->tag;
                my $direction = $node->ord < $node->get_parent->ord ? 'L' : 'R';
                $count{"$tag $parent_tag $direction"}++;
            }
        }
    }
    # send the initial count of this job to the others
    $self->message_board->write_message( { initial_count => \%count } );

    # let's wait for all blocks to send their initial counts
    $self->message_board->synchronize;

    # collect counts
    foreach my $message ( $self->message_board->read_messages ) {
        foreach my $edge ( keys %{$message->{initial_count}} ) {
            $count{$edge} += $message->initial_count->{$edge};
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
    foreach my $iteration (1 .. 20) {
    log_info "Iteration $iteration, logprob $logprob";
        foreach my $document (@$documents_rf) {
            foreach my $bundle ($document->get_bundles) {
                my $aroot = $bundle->get_tree($self->language, 'a', $self->selector);
                foreach my $node ($aroot->get_descendants) {
                    my $tag = $node->tag;
                    my $parent_tag = $node->get_parent->is_root ? '<root>' : $node->get_parent->tag;
                    my $direction = $node->ord < $node->get_parent->ord ? 'L' : 'R';
                    my $edge = "$tag $parent_tag $direction";
                    $diff_count{$edge}--;
                    my $new_logprob = $logprob - log(($count{$edge} || 0) + ($diff_count{$edge} || 0) + $ALPHA);
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
                        $new_edge[$p] = "$tag $new_parent_tag $new_direction";
                        $new_logprob[$p] = $new_logprob + log(($count{$new_edge[$p]} || 0) + ($diff_count{$new_edge[$p]} || 0) + $ALPHA);
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
        # send count differences to the other jobs
        $self->message_board->write_message( { diff_count => \%diff_count } );

        # update counts of this job
        foreach my $edge ( keys %diff_count ) {
             $count{$edge} += $diff_count{$edge};
        }
        %diff_count = ();
        
        # collect update of counts from the other jobs
        foreach my $message ( $self->message_board->read_messages ) {
            foreach my $edge ( keys %{$message->{diff_count}} ) {
                $count{$edge} += $message->diff_count->{$edge};
            }
        }

        # save documents # TEMPORARY HACK !!!
        foreach my $document (@$documents_rf) {
            $document->save($document->full_filename . '.treex');
        }
    }
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

