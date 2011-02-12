package SEnglishT_to_TCzechT::Delete_superfluous_tnodes;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my $DEBUG = 0;

#use Report;
#my $filename = $ENV{TMT_ROOT}."/share/data/models/translation/en2cs/tnodes_to_delete.tsv";
#open F,"<:utf8",$filename or Report::fatal $!;
#my %child_to_delete;
#while (<F>) {
#    chomp;
#    next if /when/; # this is due to errors in recognizing preposition and adverb in CzEng
#    my ($child_tlemma, $parent_tlemma, $precision) = split /\t/;
#    $child_to_delete{$child_tlemma}{$parent_tlemma} = 1;
#}

my %child_to_delete; #= map {my($child,$parent) = split/_/;($child }

foreach my $pair (
    qw(all_right ahead_go place_take down_sit
       much_very well_as little_bit air_conditioning
       real_estate ice_cream away_throw prime_minister
       floppy_disk raw_material away_turn down_lay any_one
       away_pass very_much round_turn around_turn
       machine_gun fairy_tale down_lie good_sense honey_bee how_much
       how_many both_and)) {
    my ($child_tlemma, $parent_tlemma) = split /_/,$pair;
    $child_to_delete{$child_tlemma}{$parent_tlemma} = 1;
}

sub process_bundle {

    my ( $self, $bundle ) = @_;

    foreach my $tnode ( grep {not $_->get_children}
                            map {$_->get_descendants}
                                $bundle->get_tree('TCzechT')->get_children) {

        my $child_tlemma = $tnode->get_attr('t_lemma');
        my $parent_tlemma = $tnode->get_parent->get_attr('t_lemma');
        if ($child_to_delete{$child_tlemma}{$parent_tlemma}) {
            warn "_DELETED_\t$child_tlemma\t".$bundle->get_attr('english_source_sentence').
                "\t".$bundle->get_attr('czech_source_sentence')."\t".
                    $bundle->get_attr('czech_target_sentence')."\t"
                        .$tnode->get_parent->get_fposition."\n" if $DEBUG;
            $tnode->disconnect;
        }
    }
}

1;

=over

=item SEnglishT_to_TCzechT::Delete_superfluous_tnodes

Deleting t-nodes that should have no counterparts on the Czech side,
such as 'place' in 'take place' or 'down' in 'sit down', and can be
deleted without any loss. Lemma pairs were manually selected from
pairs extracted from CzEng.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
