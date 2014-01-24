package Treex::Block::Filter::Generic::ReorderingQuantity;
use Moose;
use Treex::Core::Common;
use List::Util qw( min max );

extends 'Treex::Block::Filter::Generic::Common';

my @bounds = ( 0, 0.1, 0.2, 0.35, 0.5, 0.75, 1 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @tgt = $bundle->get_zone($self->to_language)->get_atree->get_descendants( { ordered => 1 } );

    my %tgt2src;
    my %src2tgt;

    my $tgt_index = -1;

    ### load alignment from Treex representation into hashes tgt2en, en2tgt
    
    # over all nodes
    for my $links_ref (map { $_->get_attr( "alignment" ) } @tgt) {
        $tgt_index++;
        next if ! $links_ref;

        # over all node links
        for my $link ( @$links_ref ) {
            # only care about points included in GDFA alignment
            my $in_gdfa = grep { $_ eq "gdfa" } split /\./, $link->{"type"};
            next if ! $in_gdfa;

            # get the node index
            my $node_id = $link->{"counterpart.rf"};
            $node_id =~ m/-n(\d+)$/;
            my $src_index = $1 - 1; # zero based

            push @{ $tgt2src{$tgt_index} }, $src_index;
            push @{ $src2tgt{$src_index} }, $tgt_index;
        }
    }

    ## extract all reorderings
    my $reordered_spans_length = 0;

    # over all words
    for (my $i = 1; $i < $source_length; $i++) { 

        # initial A, B of length 1
        my ($a_begin, $a_length, $b_begin, $b_length) = ($i - 1, 1, $i, 1);
        my ($a_begin_opp, $a_length_opp) = _get_opposite_span(\%src2tgt, $a_begin, $a_length);
        my ($b_begin_opp, $b_length_opp) = _get_opposite_span(\%src2tgt, $b_begin, $b_length);
        
        if ($debug) {
            print STDERR "Span of A: $a_begin-", $a_begin+$a_length-1, "\n";
            print STDERR "Opposite span of A: $a_begin_opp-", $a_begin_opp+$a_length_opp-1, "\n";
            print STDERR "Span of B: $b_begin-", $b_begin+$b_length-1, "\n";
            print STDERR "Opposite span of B: $b_begin_opp-", $b_begin_opp+$b_length_opp-1, "\n";
        }

        # A or B are not aligned to anything
        next if ! defined($a_begin_opp) || ! defined($b_begin_opp);

        next if $a_begin_opp < $b_begin_opp + $b_length_opp; # no reordering

        # grow block A to the left
        #     
        # XXX this is not exactly described in the paper
        # the most "likely" correct solution is implemented here, i.e.:
        #     - allow A to grow to the first consistent span
        #     - after that, each extension of A must be consistent

        print STDERR "Growing A\n" if $debug;
        while ($a_begin > 0) { 
            if (_is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length)) { 
                last if ! _is_consistent_span(\%src2tgt, \%tgt2src, $a_begin - 1, $a_length + 1);
            }     
            my ($a_ext_begin_opp, $a_ext_length_opp) = 
                _get_opposite_span(\%src2tgt, $a_begin - 1, $a_length + 1); 
            if ($a_ext_begin_opp >= $b_begin_opp + $b_length_opp) { 
                $a_begin--;
                $a_length++;
                $a_begin_opp = $a_ext_begin_opp;
                $a_length_opp = $a_ext_length_opp;
            } else {
                last;
            }     
        }     

        # never reached a consistent block A
        next if ! is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length);

        # grow B to the right, keep span AB consistent
        print STDERR "Growing B\n" if $debug;
        while ($b_begin + $b_length <= $source_length) { 
            last if _is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length + $b_length);
            my ($b_ext_begin_opp, $b_ext_length_opp) = 
                _get_opposite_span(\%src2tgt, $b_begin, $b_length + 1); 
            if ($a_begin_opp >= $b_ext_begin_opp + $b_ext_length_opp) { 
                $b_length++;
                $b_begin_opp = $b_ext_begin_opp;
                $b_length_opp = $b_ext_length_opp;
            } else {
                last;
            }     
        }            
        
        # never reached a consistent block AB
        next if ! _is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length + $b_length);

        print STDERR "Adding reordered span of length ", $a_length + $b_length, "\n" if $debug;

        $reordered_spans_length += $a_length + $b_length;
    }     

    ## compute the RQuantity
    my $rquantity = $reordered_spans_length / $source_length;
    printf "%.03f\n", $rquantity if $verbose;
    $tot_rquantity += $rquantity;
}

printf "%.04f (%.02f / %d)\n", $tot_rquantity / $linecount, $tot_rquantity, $linecount;
 
# given a source block, return the span of its links on the target side
sub _get_opposite_span {
    my ($links, $begin, $length) = @_; 
        
    my %points_to;

    for (my $i = $begin; $i != $begin + $length; $i++) {
        next if ! $links->{$i};
        map { $points_to{$_} = 1 } @{ $links->{$i} };
    }

    return undef if ! keys %points_to;

    my $opposite_begin = min(keys %points_to);
    my $opposite_length = max(keys %points_to) - $opposite_begin + 1;

    return ($opposite_begin, $opposite_length);
}

# check span consistency (i.e. no target words are aligned outside source span)
sub _is_consistent_span {
    my ($src2tgt, $tgt2src, $begin, $length) = @_;
    print STDERR "Checking span $begin-",$begin+$length-1, "\n" if $debug;

    my ($opposite_begin, $opposite_length) = get_opposite_span($src2tgt, $begin, $length);

    for (my $i = $opposite_begin; $i != $opposite_begin + $opposite_length; $i++) {
        my $has_link_outside = grep {
            $_ < $begin || $_ >= $begin + $length
        } @{ $tgt2src->{$i} };
        print STDERR "Inconsisent\n" if $debug && $has_link_outside;
        return 0 if $has_link_outside;
    }

    print STDERR "Consistent\n" if $debug;
    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::ReorderingQuantity

=back

The amount of reordering between source and target -- the RQuantity as
described in Birch et al.: Predicting Success in Machine Translation.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
