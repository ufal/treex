package Treex::Block::A2A::EN::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    $self->backup_zone($zone);
    fix_coordination($zone->get_atree);
}

sub fix_coordination{
    my ($root) = @_;

    foreach my $last_member (grep {$_->conll_deprel eq 'CONJ'} $root->get_descendants) {
        $last_member->set_is_member(1);

        if ($last_member->get_parent->conll_deprel eq 'COORD') {
            my $coord_root = $last_member->get_parent;

            my @members = ($last_member);

            my $node = $coord_root;

            while ($node->conll_deprel eq 'COORD') {
                $node = $node->get_parent;
                push @members, $node;
            }

            $coord_root->set_parent($members[-1]->get_parent);
            foreach my $member (@members) {
                $member->set_parent($coord_root);
                $member->set_is_member(1);
                $member->set_conll_deprel($members[-1]->conll_deprel);
            }

        }
    }
}


1;

=over

=item Treex::Block::A2A::EN::Harmonize

Backuping original trees and adding iset.
The rest of conll->pdt conversion is implemented
in separated blocks.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
