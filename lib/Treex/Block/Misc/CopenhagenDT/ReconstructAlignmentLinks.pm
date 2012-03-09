package Treex::Block::Misc::CopenhagenDT::ReconstructAlignmentLinks;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my %linenumber2node;
    foreach my $zone ($bundle->get_all_zones) {
        foreach my $anode ($zone->get_atree->get_descendants) {
            $linenumber2node{$zone->language}{$anode->wild->{linenumber}} = $anode;
        }
    }

    foreach my $language (keys %{$bundle->wild}) {

        foreach my $align (@{$bundle->wild->{$language}}) {
            my $danish_line_numbers = $align->{out};
            my $other_lang_line_numbers = $align->{in};
            print "$danish_line_numbers $other_lang_line_numbers\n";

            if ($danish_line_numbers =~ s/a//g
                    and $other_lang_line_numbers =~ s/b//g) {
                print "Danish: $danish_line_numbers  $language: $other_lang_line_numbers\n";

              DANISH_NODE:
                foreach my $danish_line_number ( split / /,$danish_line_numbers ) {
                    my $danish_node = $linenumber2node{da}{$danish_line_number};
                    if (not defined $danish_node) {
                        log_warn "No node defined for language 'da' (in alignment da-$language) and line number $danish_line_number";
                        next DANISH_NODE;
                    }

                  OTHER_LANG_NODE:
                    foreach my $other_lang_line_number ( split / /,$other_lang_line_numbers ) {
                        my $other_lang_node = $linenumber2node{$language}{$other_lang_line_number};
                        if (not defined $other_lang_node) {
                            log_warn "No node defined for language '$language' (in alignment da-$language) and line number $danish_line_number";
                            next OTHER_LANG_NODE;
                        }

                        print $danish_node->form."\t".$other_lang_node->form."\n";
                        $other_lang_node->add_aligned_node($danish_node,"whatever");
                    }
                }
            }
        }
    }

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::ReconstructAlignmentLinks

Create proper alignment links between a-node. Direction: from other languages to Danish.
Links are extracted from the first bundle's wild attributes.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
