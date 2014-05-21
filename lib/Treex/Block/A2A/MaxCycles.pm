package Treex::Block::A2A::MaxCycles;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'to_language' => ( is => 'rw', isa => 'Str', default => '' );
has 'to_selector' => ( is => 'rw', isa => 'Str', default => '' );

sub copy_array {
    my ($array1, $array2) = @_;
    $array2 = [];
    foreach my $i (0 .. $#$array1) {
        foreach my $j (0 .. $#{$$array1[$i]}) {
            $$array2[$i][$j] = $$array1[$i][$j];
        }
    }
}

sub find_shortest_paths {
    my ($scores, $paths, $max_length) = @_;
    my $size = $#$scores;
    foreach my $i (0 .. $size) {
        foreach my $j (0 .. $size) {
            $$paths[$i][$j] = '';
        }
    }
    foreach my $d (1 .. $max_length - 1) {
        my @new_paths;
        my @new_scores;
        copy_array($paths, \@new_paths);
        copy_array($scores, \@new_scores);
        foreach my $i (1 .. $size) {
            foreach my $j (0 .. $size) {
                next if $i == $j;
                my $best_score = $scores->[$i][$j];
                my $best_path = $paths->[$i][$j];
                foreach my $k (1 .. $size) {
                    next if $k == $i || $k == $j;
                    if ($scores->[$i][$k] + $scores->[$k][$j] > $best_score) {
                        $best_score = $scores->[$i][$k] + $scores->[$k][$j];
                        $best_path = "$paths->[$i][$k] $k $paths->[$k][$j]";
                    }
                }
                $new_scores[$i][$j] = $best_score;
                $new_paths[$i][$j] = $best_path;
            }
        }
        copy_array(\@new_paths, $paths);
        copy_array(\@new_scores, $scores);
    }
}

sub find_shortest_halfcycles {
    my ($lr_scores, $lr_paths, $rl_scores, $rl_paths, $left_scores, $left_paths, $right_scores, $right_paths, $alignment_scores) = @_;
    my $left_size = $#$left_scores;
    my $right_size = $#$right_scores;
    foreach my $l (0 .. $left_size) {
        foreach my $r (0 .. $right_size) {
            foreach my $l2 (0 .. $left_size) {
                next if $l == $l2 || $l == 0;
                if (!defined $$lr_scores[$l][$r] || ($$lr_scores[$l][$r] < $$left_scores[$l][$l2] + $$alignment_scores[$l2][$r])) {
                    $$lr_scores[$l][$r] = $$left_scores[$l][$l2] + $$alignment_scores[$l2][$r];
                    $$lr_paths[$l][$r] = "$$left_paths[$l][$l2] $l2"; 
                }
            }
            foreach my $r2 (0 .. $right_size) {
                next if $r == $r2 || $r == 0;
                if (!defined $$rl_scores[$r][$l] || ($$rl_scores[$r][$l] < $$right_scores[$r][$r2] + $$alignment_scores[$l][$r2])) {
                    $$rl_scores[$r][$l] = $$right_scores[$r][$r2] + $$alignment_scores[$l][$r2];
                    $$rl_paths[$r][$l] = "$$right_paths[$r][$r2] $r2"; 
                }
            }
        }
    }
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $source_tree = $bundle->get_tree( $self->language, 'a', $self->selector);
    my $target_tree = $bundle->get_tree( $self->to_language, 'a', $self->to_selector);
    my @source_nodes = $source_tree->get_descendants({'ordered' => 1});
    my @target_nodes = $target_tree->get_descendants({'ordered' => 1});
    my $source_length = scalar @source_nodes;
    my $target_length = scalar @target_nodes;
    return if $source_length < 2 || $target_length < 2;

    # get source matrix
    my @source_matrix;
    my $source_minimum = 0;
    my $source_total = 0; 
    foreach my $node (@source_nodes) {
        my @mst_scores = map {sprintf("%.2f",$_)} @{$node->wild()->{'mst_score'} || [0]};
        if ($#mst_scores != $source_length) {
            log_warn("mst-scores not filled properly at ".$node->id.".");
            @mst_scores = map {0} (0 .. $source_length);
        }
        foreach my $score (@mst_scores) {
            $source_minimum = $score if $score < $source_minimum;
            $source_total += $score;
        }
        $source_matrix[$node->ord] = \@mst_scores;
    }

    # get target matrix
    my @target_matrix;
    my $target_minimum = 0;
    my $target_total = 0;
    foreach my $node (@target_nodes) {
        my @mst_scores = map {sprintf("%.2f",$_)} @{$node->wild()->{'mst_score'} || [0]};
        if ($#mst_scores != $target_length) {
            log_warn("mst-scores not filled properly at ".$node->id.".");
            @mst_scores = map {0} (0 .. $target_length);
        }
        foreach my $score (@mst_scores) {
            $target_minimum = $score if $score < $target_minimum;
            $target_total += $score;
        }
        $target_matrix[$node->ord] = \@mst_scores;
    }

    # get alignment matrix
    my @alignment_matrix;
    my $alignment_total = 0;
    my $BASE_WEIGHT = 0;
    my $BONUS = 2;
    foreach my $s_ord (0 .. $source_length) {
        foreach my $t_ord (0 .. $target_length) {
            $alignment_matrix[$s_ord][$t_ord] = $BASE_WEIGHT;
            $alignment_total += $BASE_WEIGHT;
        }
        next if $s_ord == 0;
        my ($alinodes, $alitypes) = $source_nodes[$s_ord - 1]->get_aligned_nodes();
        foreach my $n (0 .. $#$alinodes) {
            my $t_ord = $$alinodes[$n]->ord;
            my $weight = $$alitypes[$n] =~ /left/ ? $BONUS : 0;
            $weight += $$alitypes[$n] =~ /right/ ? $BONUS : 0;
            $weight += $BASE_WEIGHT;
            $alignment_matrix[$s_ord][$t_ord] = $weight;
            $alignment_total += $weight - $BASE_WEIGHT;
        }
    }

    my @left_paths;
    my @left_scores = @source_matrix;
    find_shortest_paths(\@left_scores, \@left_paths, 5);
   
    my @right_paths;
    my @right_scores = @target_matrix;
    find_shortest_paths(\@right_scores, \@right_paths, 5);

    my @lr_scores;
    my @lr_paths;
    my @rl_scores;
    my @rl_paths;
    find_shortest_halfcycles(\@lr_scores, \@lr_paths, \@rl_scores, \@rl_paths, \@left_scores, \@left_paths, \@right_scores, \@right_paths, \@alignment_matrix);

    # normalize matrices
    my $to_add_total = max(-$source_minimum * $source_length**2, -$target_minimum * $target_length**2);
    my $source_shift = $to_add_total / $source_length**2;
    my $target_shift = ($to_add_total + $source_total - $target_total) / $target_length**2;
    my $alignment_shift = ($to_add_total + $source_total - $alignment_total) / ($target_length + 1) / ($source_length + 1);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::MaxCycles

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


