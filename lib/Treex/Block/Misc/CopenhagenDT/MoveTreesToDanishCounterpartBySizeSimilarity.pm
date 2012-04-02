package Treex::Block::Misc::CopenhagenDT::MoveTreesToDanishCounterpartBySizeSimilarity;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Misc::CopenhagenDT::MoveTreesToDanishCounterpartByAlignment';

sub process_document {
    my ( $self, $document ) = @_;

    my @bundles = $document->get_bundles;

    my $first_bundle = shift @bundles;
    my @da_trees = map {my $zone = $_->get_zone('da'); $zone->get_atree;} @bundles;

  ZONE:
    foreach my $unaligned_zone (grep {$_->get_atree->descendants} $first_bundle->get_all_zones) {

        next ZONE if $document->wild->{annotation}{$unaligned_zone->language}{alignment};

        my @xx_trees = $unaligned_zone->get_atree->get_children;

        if (@da_trees > 4*@xx_trees or @xx_trees > 4*@da_trees) {
            log_warn "Too different numbers of trees, given up: da:". 
                scalar(@da_trees). "  ".$unaligned_zone->language.":".scalar(@xx_trees);
            next ZONE;
        }

        $self->_align_tree_sequences(\@da_trees, \@xx_trees);

        my $bundle_number=0;
        my $language = $unaligned_zone->language;
        foreach my $bundle (@bundles) {
            if (not $bundle->get_zone($language)) {
                my $empty_zone = $bundle->create_zone($language);
                $empty_zone->create_atree;
            }
        }
        foreach my $bundle (@bundles) {
            $bundle_number++;
#            print "da$bundle_number: ". (join ' ',map {$_->form} ($bundle->get_zone('da')->get_atree->get_descendants({ordered=>1})))."\n";
#            print "$language$bundle_number: ".(join ' ',map {$_->form} ($bundle->get_zone($language)->get_atree->get_descendants({ordered=>1})))."\n";
#            print "\n";
        }
    }
#    print "\n\n";

    return;
}

sub _align_tree_sequences {
    my ( $self, $da_trees_rf, $xx_trees_rf) = @_;

    if (@$da_trees_rf ==1 or @$xx_trees_rf==1) {

        my ($winner_bundle) = map {$_->get_bundle} @$da_trees_rf;

        foreach my $xx_tree (@$xx_trees_rf) {
            $self->move_tree_to_bundle($xx_tree,$winner_bundle);
        }

        return;
    }

#    print "RECURSION\n";
#    print "Number of trees: ".($#$da_trees_rf+1)."  ".  ($#$xx_trees_rf+1)."\n";

    if (@$da_trees_rf == 0 or @$xx_trees_rf == 0) {
        log_fatal "This should never happen";
    }


    my @all_da_nodes = map {$_->get_descendants({add_self=>1,ordered=>1})} @$da_trees_rf;
    my @all_xx_nodes = map {$_->get_descendants({add_self=>1,ordered=>1})} @$xx_trees_rf;


    my @da_sentence_starts_absolute;
    my @da_sentence_starts_relative;
    my @xx_sentence_starts_absolute;
    my @xx_sentence_starts_relative;

    foreach my $index ( 0..$#all_da_nodes ) {
        if ($all_da_nodes[$index]->is_root) {
            push @da_sentence_starts_absolute, $index;
            push @da_sentence_starts_relative, $index / scalar @all_da_nodes;
        }
    }

    foreach my $index ( 0..$#all_xx_nodes ) {
        if ($all_xx_nodes[$index]->parent->is_root) {
            push @xx_sentence_starts_absolute, $index;
            push @xx_sentence_starts_relative, $index / scalar @all_xx_nodes;
        }
    }

#    print "size: ".scalar(@da_sentence_starts_relative). "  ".scalar(@xx_sentence_starts_relative)."\n";

    my ($winner_da,$winner_xx);
    my $min_difference = 10000;
    foreach my $da_index (1 .. $#da_sentence_starts_relative) {
#        print "X";
        foreach my $xx_index (1 .. $#xx_sentence_starts_relative) {
#            print "Y";
            my $difference = abs($da_sentence_starts_relative[$da_index] - $xx_sentence_starts_relative[$xx_index]);
#            print "difference: $difference\n";
            if ( $difference < $min_difference) {
                $min_difference = $difference;
                $winner_da = $da_index;
                $winner_xx = $xx_index;
            }
        }
    }
#    print "\nWinner boundary pair da: $winner_da  xx: $winner_xx  diff: $min_difference\n";

    $self->_align_tree_sequences([map {$all_da_nodes[$da_sentence_starts_absolute[$_]]} (0..$winner_da-1)],
                          [map {$all_xx_nodes[$xx_sentence_starts_absolute[$_]]} (0..$winner_xx-1)]);

    $self->_align_tree_sequences([map {$all_da_nodes[$da_sentence_starts_absolute[$_]]} ($winner_da..$#da_sentence_starts_absolute)],
                          [map {$all_xx_nodes[$xx_sentence_starts_absolute[$_]]} ($winner_xx..$#xx_sentence_starts_absolute)]);

}


1;

=over

=item Treex::Block::Misc::CopenhagenDT::MoveTreesToDanishCounterpartBySizeSimilarity

Greedy recursive alignment of sentence boundaries based on similarity of
sentence lenghts. This block applies only on languages for which annotated alignment
is available in the file.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
