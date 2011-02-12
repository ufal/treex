package SEnglishT_to_TCzechT::Move_PersPron_next_to_verb;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $cs_troot->get_descendants ) {

        my $formeme = $cs_tnode->get_attr('formeme');
        my $parent = $cs_tnode->get_parent;

        if ( $cs_tnode->get_attr('t_lemma') eq '#PersPron'
          && $parent ne $cs_troot  
          && $parent->get_attr('formeme') =~ /^v:/
          && $cs_tnode->get_attr('formeme') !~ /^n:1/
          && $cs_tnode->get_attr('deepord') > $parent->get_attr('deepord') ) {
            $cs_tnode->shift_after_node($parent);
        }
    }
    return;
}

1;

=over

=item SEnglishT_to_TCzechT::Move_PersPron_next_to_verb

No-subject #PersProns which are governed by a verb are shifted nex to the verb.

=back

=cut

# Copyright 2010 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
