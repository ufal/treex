package SEnglishA_to_SEnglishT::Fix_either_or;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('SEnglishT');

    foreach my $or (grep {$_->get_attr('t_lemma')=~/^n?or$/}
                        $t_root->get_descendants) {

        my ($either) = grep {$_->get_attr('t_lemma') =~ /^n?either$/} $or->get_descendants
                or next;

        foreach my $child ($either->get_children) { #there should be none, but who knows...
            $child->set_parent($either->get_parent);
        }

        # tlemmas such as 'either_or' are created
        $or->set_attr('t_lemma', $either->get_attr('t_lemma')."_".$or->get_attr('t_lemma'));
        $or->add_aux_anodes($either->get_anodes);
        $or->set_attr('functor','DISJ');
        $or->set_attr('nodetype', 'coap');
        $either->disconnect;

#        print $or->get_attr('t_lemma')."\t". $or->get_fposition."\n";
    }

    return;
}

1;

=over

=item SEnglishA_to_SEnglishT::Fix_either_or

Creates a single t-node from 'either' and 'or' pair (as well as from neither/or
and neither/nor).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
