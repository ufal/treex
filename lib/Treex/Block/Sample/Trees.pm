package Treex::Block::Sample::Trees;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Parallel::MessageBoard;
use Graph;
use Graph::Directed;
use Graph::ChuLiuEdmonds;

extends 'Treex::Block::Sample::Base';

has iterations => (is => 'rw', isa => 'Int', default => 10); 
has other_languages => ( is => 'rw', isa => 'Str', default => '');
has alpha => (is => 'rw', default => 0.01);
has beta => (is => 'rw', default => 0.01);
has gamma => (is => 'rw', default => 1000);
has punctuation_penalty => (is => 'rw', default => 0.01);
has alignment_penalty => (is => 'rw', default => 1);
has nonprojectivity_penalty => (is => 'rw', default => 0.5);
has deletability_penalty => (is => 'rw', default => '0.1');
has priors_from => (is => 'rw', isa => 'Str', default => '');
has temperature => (is => 'rw', isa => 'Num', default => 1);
has _alignment => (is => 'rw', default => sub { my %hash; return \%hash; });
has _count => (is => 'rw', default => sub { my %hash; return \%hash; });
has _diff_count => (is => 'rw', default => sub { my %hash; return \%hash; });
has _other_languages => (is => 'rw');
has _prior_probabilities => (is => 'rw');
has _deletability => (is => 'rw');
has deletability_from => (is => 'rw', isa => 'Str', default => '');
has _dependency_counter => (is => 'rw', default => sub { my %hash; return \%hash; });


sub BUILD {
    my ($self) = @_;
    my %priors;
    if ($self->priors_from) {
        open (PRIORS, "<:utf8", $self->priors_from) or log_fatal "File ".$self->priors_from." doesn't exsist.";
        while (<PRIORS>) {
            chomp;
            my ($label, $prior) = split /\t/;
            $priors{$label} = $prior;
        }
        close PRIORS;
    }
    $self->_set_prior_probabilities(\%priors);
    my %del = ();
    if ($self->deletability_from) {
        open (DELETABILITY, "<:utf8", $self->deletability_from) or log_fatal "File ".$self->deletability_from." doesn't exsist.";
        while (<DELETABILITY>) {
            chomp;
            my ($tag, $score) = split /\t/;
            $del{$tag} = $score;
        }
        close DELETABILITY;
    }
    $self->_set_deletability(\%del);
}


sub get_prior {
    my ($self, $key) = @_;
    return $self->_prior_probabilities->{$key} || 0.5;
}


sub increase_count {
    my ($self, $type, $label, $value) = @_;
    $self->_diff_count->{$type}->{$label} += $value;
}


sub get_count {
    my ($self, $type, $label) = @_;
    return ($self->_count->{$type}->{$label} || 0) + ($self->_diff_count->{$type}->{$label} || 0);
}

sub reset_counts {
    my ($self) = @_;
    my %hash;
    $self->_set_diff_count(\%hash);
}

sub decrease_temperature {
    my ($self) = @_;
    my $t = $self->temperature;
    $self->set_temperature(0.97 * $t);
}

sub update_counts {
    my ($self) = @_;
    
    # send the initial count of this job to the others
    $self->message_board->write_message( { count => $self->_diff_count } );
    
    # let's wait for all blocks to send their initial counts
    $self->message_board->synchronize;

    # collect count changes of others
    foreach my $message ( $self->message_board->read_messages ) {
        my $new_counts = $message->{count};
        foreach my $type ( keys %{$new_counts} ) {
            foreach my $label (keys %{$new_counts->{$type}}) {
                $self->_count->{$type}->{$label} += $new_counts->{$type}->{$label};
            }
        }
    }
    # collect my count changes
    my $new_counts = $self->_diff_count;
    foreach my $type ( keys %{$new_counts} ) {
        foreach my $label (keys %{$new_counts->{$type}}) {
            $self->_count->{$type}->{$label} += $new_counts->{$type}->{$label};
        }
    }

    # delete count changes
    %{$self->_diff_count} = ();
}


sub make_change {
    my ($self, $node, $parent, $type, $change_counts, $language) = @_;
    my $tag = $node->tag;
    my $parent_tag = $parent->is_root ? '<root>' : $parent->tag;
    my $form = $node->form;
    my $parent_form = $parent->is_root ? '<root>' : $parent->form;
    my $direction = $node->ord < $parent->ord ? 'L' : 'R';
    my $distance = $parent->is_root ? 50 : $node->ord - $parent->ord;
    my $edge = "$language $tag $parent_tag $direction";
    my $child_dist = "$tag $distance";
    my $non_projective = 0;
    my $wrong_order = 0;
    if (defined $self->_deletability->{$tag} && defined $self->_deletability->{$parent_tag} && $self->_deletability->{$parent_tag} > $self->_deletability->{$tag}) {
        $wrong_order = 1;
    }
#    if (!$parent->is_root) {
#        my $descendants_between = 0;
#        foreach my $n ($node->get_descendants) {
#            if (   ($direction eq 'L' && $n->ord > $node->ord && $n->ord < $parent->ord)
#                || ($direction eq 'R' && $n->ord < $node->ord && $n->ord > $parent->ord)) {
#                    $descendants_between++;
#            }
#        }
#        $non_projective = 1 if $descendants_between < abs($node->ord - $parent->ord) - 1;
#    }
    my $diff_logprob = 0;
    if ($type eq 'del') {
        $diff_logprob -= log($self->get_count('ctag-ptag-dir', $edge) - 1 + $self->alpha);# - log($self->get_count('ptag', "$parent_tag") - 1 + $self->alpha*60);
#        $diff_logprob -= log($self->get_count('ctag-dist', $child_dist) - 1 + $self->beta);
#        $diff_logprob -= log($self->get_count('cform-pform', "$form $parent_form") - 1 + $self->gamma) - log($self->get_count('pform', "$parent_form") - 1 + $self->gamma*10000);
        $diff_logprob -= log( 1 / (abs($distance)**2));
        $diff_logprob -= log($self->deletability_penalty) if $wrong_order;
        $diff_logprob -= log($self->punctuation_penalty) if ($parent->form || 'undef') =~ /^[\.,!\?;\-]$/;
#        $diff_logprob -= log($self->alignment_penalty) if !$self->aligned_edge($node, $node->get_parent);
#        $diff_logprob -= log($self->nonprojectivity_penalty) if $non_projective;
        if ($change_counts) {
            $self->increase_count('ctag-ptag-dir', $edge, -1);
#            $self->increase_count('ctag-dist', $child_dist, -1);
#            $self->increase_count('cform-pform', "$form $parent_form", -1);
#            $self->increase_count('pform', "$parent_form", -1);
#            $self->increase_count('ptag', "$parent_tag", -1);
        }
    }
    elsif ($type eq 'ins') {
        $diff_logprob += log($self->get_count('ctag-ptag-dir', $edge) + $self->alpha);# - log($self->get_count('ptag', "$parent_tag") + $self->alpha*60);
#        $diff_logprob += log($self->get_count('ctag-dist', $child_dist) + $self->beta);
#        $diff_logprob += log($self->get_count('cform-pform', "$form $parent_form") + $self->gamma) - log($self->get_count('pform', "$parent_form") + $self->gamma*10000);
        $diff_logprob += log( 1 / (abs($distance)**2));
        $diff_logprob += log($self->deletability_penalty) if $wrong_order;
        $diff_logprob += log($self->punctuation_penalty) if ($parent->form || 'undef') =~ /^[\.,!\?;\-]$/;
#        $diff_logprob += log($self->alignment_penalty) if !$self->aligned_edge($node, $node->get_parent);
#        $diff_logprob += log($self->nonprojectivity_penalty) if $non_projective;
        if ($change_counts) {
            $self->increase_count('ctag-ptag-dir', $edge, +1);
#            $self->increase_count('ctag-dist', $child_dist, +1);
#            $self->increase_count('cform-pform', "$form $parent_form", +1);
#            $self->increase_count('pform', "$parent_form", +1);
#            $self->increase_count('ptag', "$parent_tag", +1);
        }
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
            foreach my $language ($self->language, @{$self->_other_languages}) {
                foreach my $node ($bundle->get_tree($language, 'a', $self->selector)->get_descendants) {
                    $logprob += $self->make_change($node, $node->get_parent, 'ins', 1, $language) - log($total + 10000);
                    $total++;
                }
            }
        }
    }
    return $logprob;
}


sub choose_edge {
    my ($self, $nodes, $parents, $type, $language) = @_;
    log_fatal "Number of nodes an parents doesn't match" if $#$nodes != $#$parents;
    my @logprob;
    my $sum_prob = 0;
    foreach my $i (0 .. $#$nodes) {
        $logprob[$i] = $self->make_change($$nodes[$i], $$parents[$i], $type, 0, $language);
        $sum_prob += exp($logprob[$i])**(1/$self->temperature);
    }
    my $random_value = rand($sum_prob);
    my $current_value = 0;
    foreach my $i (0 .. $#$nodes) {
        $current_value += exp($logprob[$i])**(1/$self->temperature);
        if ($current_value >= $random_value) {
            $self->make_change($$nodes[$i], $$parents[$i], $type, 1, $language);
            return ($i, $logprob[$i]);
        }
    }
    return undef;
}


sub precompute_alignment {
    my ($self, $documents_rf) = @_;
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            foreach my $node ($bundle->get_tree($self->language, 'a', $self->selector)->get_descendants) {
                my ($nodes, $types) = $node->get_directed_aligned_nodes();
                foreach my $i (0 .. $#$nodes) {
                    if ($$types[$i] =~ /int/) {
                        $self->_alignment->{$node} = $$nodes[$i];
                        $self->_alignment->{$$nodes[$i]} = $node;
                    }
                }
            }
        }
    }
}


sub aligned_edge {
    my ($self, $node, $parent) = @_;
    my $n = $self->_alignment->{$node};
    my $p = $self->_alignment->{$parent};
    return (defined $n && defined $p && $n->get_parent eq $p ? 1 : 0);
}


sub process_documents {
    my ( $self, $documents_rf ) = @_;

    my @ol = split /-/, $self->other_languages;
    $self->_set_other_languages(\@ol);

    my $logprob = $self->compute_counts_and_logprob($documents_rf);
    log_info "Initial logprob: $logprob";
    
    $self->update_counts if $self->_parallel_execution;

    # precompute alignment links
    $self->precompute_alignment($documents_rf);

    # Gibbs sampling
    foreach my $iteration (1 .. $self->iterations) {
        foreach my $document (@$documents_rf) {
            foreach my $bundle ($document->get_bundles) {
                foreach my $language ($self->language, @{$self->_other_languages}) {
                    my $aroot = $bundle->get_tree($language, 'a', $self->selector);
                    my @shuffled_nodes = List::Util::shuffle $aroot->get_descendants;
                    foreach my $node (@shuffled_nodes) {
                        $logprob += $self->make_change($node, $node->get_parent, 'del', 1, $language);
                        my @parents = grep {$node ne $_} (@shuffled_nodes, $aroot);
                        my @nodes = map{$node} @parents;
                        my ($winner, $logprob_change) = $self->choose_edge(\@nodes, \@parents, 'ins', $language);
                        my $chosen_parent = $parents[$winner];
                        $logprob += $logprob_change;
                        my %is_descendant;
                        map {$is_descendant{$_} = 1} $node->get_descendants;
                        my $chosen_from_cycle;
                        if ($is_descendant{$chosen_parent}) {
                            my @nodes_in_cycle;
                            my @parents_in_cycle;
                            my $n = $chosen_parent;
                            while ($n ne $node) {
                                push @nodes_in_cycle, $n;
                                $n = $n->get_parent;
                                push @parents_in_cycle, $n;
                            }
                            push @nodes_in_cycle, $node;
                            push @parents_in_cycle, $chosen_parent;
                            ($winner, $logprob_change) = $self->choose_edge(\@nodes_in_cycle, \@parents_in_cycle, 'del', $language);
                            $chosen_from_cycle = $nodes_in_cycle[$winner];
                            $logprob += $logprob_change;
                            my @possible_parents = grep {$node ne $_ && !$is_descendant{$_}} (@shuffled_nodes, $aroot);
                            my @possible_nodes = map{$chosen_from_cycle} @possible_parents;
                            ($winner, $logprob_change) = $self->choose_edge(\@possible_nodes, \@possible_parents, 'ins', $language);
                            $chosen_from_cycle->set_parent($possible_parents[$winner]);
                            $logprob += $logprob_change;
                        }
                        $node->set_parent($chosen_parent) if (!defined $chosen_from_cycle || $chosen_from_cycle ne $node);
                        $self->collect_counts($documents_rf) if rand() < 0.01 && $iteration > 5;
                    }
                }
            }
        }
        log_info "Iteration $iteration, logprob $logprob, temperature ".$self->temperature;
        $self->update_counts if $self->_parallel_execution;
#        $self->decrease_temperature();
    }

    # compute counts and logprob
    $logprob = $self->compute_counts_and_logprob($documents_rf);
    log_info "Final logprob: $logprob";

    # run maximum spanning tree algorithm
    log_info "Computing maximum spanning trees.";
    $self->run_mst($documents_rf);


    # save documents # TEMPORARY HACK !!!
    foreach my $document (@$documents_rf) {
        $document->save($document->full_filename . '.treex.gz');
    }
}


sub collect_counts {
    my ($self, $documents_rf) = @_;
    my $dep_counter = $self->_dependency_counter;
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            foreach my $node ($bundle->get_tree($self->language, 'a', $self->selector)->get_descendants) {
#                my $label = $bundle->id." ".$node->ord." ".$node->get_parent->ord;
#print STDERR "$label ";
                $dep_counter->{$node}{$node->get_parent}++;
            }
        }
    }
}



sub run_mst {
    my ($self, $documents_rf) = @_;
    my $dep_counter = $self->_dependency_counter;
    foreach my $document (@$documents_rf) {
        foreach my $bundle ($document->get_bundles) {
            my $aroot = $bundle->get_tree($self->language, 'a', $self->selector);
            my @nodes = ($aroot, $aroot->get_descendants);
            my $graph = Graph::Directed->new( vertices => \@nodes );
            foreach my $n ( 1 .. $#nodes ) {
                $nodes[$n]->set_parent($aroot);
                foreach my $p ( 0 .. $#nodes) {
                    next if $n == $p;
#                    my $weight = -($dep_counter->{$bundle->id." ".$nodes[$n]->ord." ".$nodes[$p]->ord} || 0);
                    my $weight = -($dep_counter->{$nodes[$n]}{$nodes[$p]} || 0);
#                    print "$weight ";
                    $graph->add_weighted_edge($p, $n, $weight);
                }
            }
            my $mst = $graph->MST_ChuLiuEdmonds($graph);
            foreach my $edge ($mst->edges) {
                $nodes[$edge->[1]]->set_parent($nodes[$edge->[0]]);
            }
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

