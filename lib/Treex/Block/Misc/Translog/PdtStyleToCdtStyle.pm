package Treex::Block::Misc::Translog::PdtStyleToCdtStyle;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $node (map {$_->get_descendants}
        $bundle->get_zone('en')->get_atree->get_children) {

        if ($node->tag =~ /^(DT|PRP\$)$/) {
            _rehang_above_parent($node);
        }

        elsif ($node->tag eq 'IN' and $node->get_parent->tag=~/^V/
           and $node->precedes($node->get_parent)) {
            _rehang_above_parent($node)
        }

    }
    return;
}

sub _rehang_above_parent {
    my ($node) = @_;
    my $parent = $node->get_parent;
    $node->set_parent($parent->get_parent);
    $parent->set_parent($node);
    print "rehanging ".$node->form."\n";
}


1;


=over

=item Treex::Block::Misc::Translog::PdtStyleToCdtStyle

Substitutes deprel values (dependency lables) delivered by MST parser
by their CDT counterparts.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
