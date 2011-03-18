package Treex::Block::Align::A::CS2CS::GreedyHeur;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

my $min_score_limit = 4;

my %weight = (
    same_form              => 10,
    same_3letter_prefix    => 4,
    same_3letter_suffix    => 4,
    aligned_left_neighbor  => 3,
    aligned_right_neighbor => 3,
    ord_similarity         => 7,
);

sub score {
    my ( $ref_node, $tst_node ) = @_;
    my %feature_vector;

    if ( $ref_node->form eq $tst_node->form ) {
        $feature_vector{same_form} = 1;
    }

    else {
        if ( substr( lc( $ref_node->form ), 0, 3 ) eq substr( lc( $tst_node->form ), 0, 3 ) ) {
            $feature_vector{same_3letter_prefix} = 1;
        }
        if ( substr( lc( $ref_node->form ), -3 ) eq substr( lc( $tst_node->form ), -3 ) ) {
            $feature_vector{same_3letter_suffix} = 1;
        }
    }

    my $tst_prev = $tst_node->get_prev_node;
    my $tst_next = $tst_node->get_next_node;
    my $ref_prev = $ref_node->get_prev_node;
    my $ref_next = $ref_node->get_next_node;

    if ( $tst_prev and $ref_prev and ( $tst_prev->get_attr('align') || '' ) eq $ref_prev->id ) {
        $feature_vector{aligned_left_neighbor} = 1;

        #        print "LEFT\n";
    }

    if ( $tst_next and $ref_next and ( $tst_next->get_attr('align') || '' ) eq $ref_next->id ) {
        $feature_vector{aligned_right_neighbor} = 1;

        #        print "RIGHT\n";
    }

    $feature_vector{ord_similarity} = 1 / ( 1 + abs( $ref_node->ord - $tst_node->ord ) );

    my $score = 0;
    foreach my $feature_name ( keys %feature_vector ) {
        $score += $feature_vector{$feature_name}
            * ( $weight{$feature_name} or log_fatal "Unknown feature $feature_name" );
    }
    return $score;
}

sub find_links {
    my ( $ref_unaligned, $tst_unaligned ) = @_;

    while (1) {
        my $max_score = 0;
        my ( $ref_winner, $tst_winner );

        foreach my $tst_node (@$tst_unaligned) {
            foreach my $ref_node (@$ref_unaligned) {
                my $score = score( $ref_node, $tst_node );
                if ( $score > $max_score ) {
                    $max_score  = $score;
                    $ref_winner = $ref_node;
                    $tst_winner = $tst_node;
                }
            }
        }

        if ( $max_score >= $min_score_limit ) {

            #            print "link found: ".$tst_winner->form." -> ".$ref_winner->form." score=$max_score\n";
            $tst_winner->set_attr( 'align', $ref_winner->id );
            $ref_unaligned = [ grep { $_ ne $ref_winner } @$ref_unaligned ];
            $tst_unaligned = [ grep { $_ ne $tst_winner } @$tst_unaligned ];
        }
        else {
            return;
        }
    }
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $ref_zone = $bundle->get_zone( 'cs', 'ref' );
    return if not $ref_zone;    # possible nonexistent zone because of resegmentation

    # ------ tokenization should be removed from here and replaced by an ordinary tok. block
    my $ref_sentence = $ref_zone->sentence;

    $ref_sentence =~ s/([^\s[:alnum:]])/ $1 /g;
    $ref_sentence =~ s/\s+/ /g;
    $ref_sentence =~ s/^\s*//g;
    $ref_sentence =~ s/\s*$//g;

    my $ref_aroot = $ref_zone->create_atree;
    my $ord       = 0;
    foreach my $form ( split / /, $ref_sentence ) {
        $ord++;
        $ref_aroot->create_child( { form => $form, ord => $ord } );
    }

    # ------ end of tokenization

    my @ref_unaligned = $bundle->get_zone( 'cs', 'ref' )->get_atree->get_descendants( { ordered => 1 } );
    my @tst_unaligned = $bundle->get_zone( 'cs', 'tst' )->get_atree->get_descendants( { ordered => 1 } );

    print "REF: " . $bundle->get_zone( 'cs', 'ref' )->sentence . "\n";
    print "TST: " . $bundle->get_zone( 'cs', 'tst' )->sentence . "\n\n";

    find_links( \@ref_unaligned, \@tst_unaligned );

    my $doc = $bundle->get_document;
    foreach my $tst_node ( $bundle->get_zone( 'cs', 'tst' )->get_atree->get_descendants( { ordered => 1 } ) ) {
        my $aligned_word = '';
        if ( $tst_node->get_attr('align') ) {
            $aligned_word = $doc->get_node_by_id( $tst_node->get_attr('align') )->form;
        }
        print $tst_node->form . " --> " . $aligned_word . "\n";
    }
    print "\n";
}

1;
