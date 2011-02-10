package SEnglishA_to_SEnglishT::Rehang_shared_attr;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);


sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $t_root = $bundle->get_tree('SEnglishT');

    foreach my $attr (grep {$_->get_attr('formeme') =~ /attr|poss/
                                and not $_->get_attr('is_member')
                                    and $_->get_attr('t_lemma') ne 'both'
                            }
                          reverse map {$_->get_descendants({ordered=>1})}
                              reverse $t_root->get_children({ordered=>1})) {

        my @coord_members = grep {$_->get_attr('is_member') and $_ ne $attr->get_parent}
                                 $attr->get_eff_parents;

        my ($nearest_member) = sort {$a->get_ordering_value<=>$b->get_ordering_value}
            grep {$_->precedes($_->get_parent)}
                grep {$attr->precedes($_)} @coord_members;

        # and there are no intermediate nodes
        if ($nearest_member and
                not grep {$_->precedes($nearest_member) and $attr->precedes($_)}
                    $nearest_member->get_parent->get_children) {
#            print $attr->get_fposition."\n";
            $attr->set_parent($nearest_member);
        }


    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Rehang_shared_attr

Rehanging shared attr/poss modifiers below the nearest following
coordination member (usually there is a mess in the
coordination structure anyway).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
