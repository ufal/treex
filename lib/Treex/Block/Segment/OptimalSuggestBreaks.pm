package Treex::Block::Segment::OptimalSuggestBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Segment::SuggestSegmentBreaks';

my $debug = 1;


sub _find_breaks {
    my ($self, $scores) = @_;

    my $first_item = shift @$scores;
    if ($first_item != 0) {
        return log_fatal "the first element in segment interlinks shoul be 0: in " . ref($self);
    }

    my $n = scalar(@$scores);
    my $chart = $self->_ensure_covered($scores, undef, 0, $n);
    my $best = $self->_getbest($chart, 0, $n);

    return (0, @{$best->{'splits'}});
}

# ensure that the chart contains all items covering sentences a..b
sub _ensure_covered {
    my ($self, $scores, $chart, $a, $b) = @_;

    $self->_infoprint($scores, "?", $a, $b) if $debug;
    
    # print STDERR "Called for $a .. $b\n";
    if (defined $chart->[$a]->[$b]) {
        # print STDERR "  done.\n";
        return $chart;
    }

    my $spanlen = $b-$a+1;
    if ($spanlen <= 1) {
        $self->_infoprint($scores, $spanlen, $a, $b) if $debug;
        $chart->[$a]->[$b]->{$spanlen}->{$spanlen}
            = { splits=> [], brokenlinks=>0, headlen=>$spanlen, taillen=>$spanlen };
        # push @{$chart->[$a]->[$b]},
        # { splits=> [], brokenlinks=>0, headlen=>$spanlen, taillen=>$spanlen };
    } 
    else {
        foreach my $c ($a .. $b-1) {
            $chart = $self->_ensure_covered($scores, $chart, $a, $c);
            $chart = $self->_ensure_covered($scores, $chart, $c+1, $b);
            
            # add all methods to cover a-b using a split at c
            foreach my $leftitem ( $self->_getitems($chart, $a, $c) ) { #@{$chart->[$a]->[$c]} ) {
                foreach my $rightitem ( $self->_getitems($chart, $c+1, $b) ) { #@{$chart->[$c+1]->[$b]} ) {
  
                    my $newitem;
                    my $canmerge = ($leftitem->{'taillen'} + $rightitem->{'headlen'}
                        <= $self->max_size);
                    my @maysplit_at_c = $canmerge ? () : ($c+1);
                    my $maybroken = $canmerge ? 0 : $scores->[$c];
                    my $newbrokenlinks = $leftitem->{'brokenlinks'} + $maybroken
                                                          + $rightitem->{'brokenlinks'};
                    my @newsplits = (@{$leftitem->{'splits'}}, @maysplit_at_c,
                                                       @{$rightitem->{'splits'}});
                    my $headlen;
                    my $taillen;
                    if ( 0 == scalar @newsplits) {
                        $headlen = $spanlen;
                        $taillen = $spanlen;
                    } else {
                        $headlen = $newsplits[0]-$a;
                        $taillen = $b - $newsplits[-1]+1;
                    }
                    $newitem = { splits=>[ @newsplits ],
                                 brokenlinks => $leftitem->{'brokenlinks'}
                                                + $maybroken
                                                + $rightitem->{'brokenlinks'},
                                 headlen => $headlen,
                                 taillen => $taillen
                               };

                    print STDERR "  push $a..$b ($newitem->{brokenlinks}): "
                        .join(" ", @{$newitem->{splits}})
                        .":   head $newitem->{headlen}, tail $newitem->{taillen};"
                        ."  from LEFT h$leftitem->{headlen}, t$leftitem->{taillen}"
                        ." RIGHT h$rightitem->{headlen}, t$rightitem->{taillen}\n"
                        if $debug;

                    if (! defined $chart->[$a]->[$b]->{$headlen}->{$taillen}
                          || $newbrokenlinks
                             < $chart->[$a]->[$b]->{$headlen}->{$taillen}->{'brokenlinks'}
                         ) {
                        $self->_infoprint($scores, "N", $a, $b) if $debug;
                        $chart->[$a]->[$b]->{$headlen}->{$taillen} = $newitem;
                    } 
                    else {
                        $self->_infoprint($scores, "o", $a, $b) if $debug;
                    }
                    # push @{$chart->[$a]->[$b]}, $newitem;
                    # should remove all with identical head & tail len but equal or worse
                    # score
                }
            }
        }
    }
    if ($debug) {
        my $best = $self->_getbest($chart, $a, $b);
        print STDERR "$a..$b\tBest splits:  ".join(" ", @{$best->{'splits'}})."\n";
        print STDERR "\tBroken links: ".$best->{'brokenlinks'}."\n";
    }

    return $chart;
}

sub _getitems {
    my ($self, $chart, $a, $b) = @_;
    my @out = ();
    my $byheadarr = $chart->[$a]->[$b];
    foreach my $bytailarr (values %$byheadarr) {
        foreach my $item (values %$bytailarr) {
            push @out, $item;
        }
    }
    return @out;
}

sub _infoprint {
    my ($self, $scores, $char, $a, $b) = @_;
    print STDERR "." x $a;
    print STDERR $char x ($b-$a+1);
    print STDERR "." x (scalar(@$scores)-$b);
    print STDERR "\n";
}

sub _getbest {
    my ($self, $chart, $a, $b) = @_;
    my $bestsofar = undef;
    my $scoresofar = undef;
    foreach my $item ($self->_getitems($chart, $a, $b)) { #@{$chart->[$a]->[$b]}) {
        if (!defined $scoresofar || $scoresofar > $item->{'brokenlinks'}) {
            $bestsofar = $item;
            $scoresofar = $item->{'brokenlinks'};
        }
    }
    return $bestsofar;
}

1;

# TODO POD
