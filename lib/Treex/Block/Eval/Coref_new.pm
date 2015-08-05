package Treex::Block::Eval::Coref_new;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Align::Utils;

sub process_tnode {
    my ($self, $tnode) = @_;

    return if !$tnode->wild->{in_coref_category};

    my ($src_anaph) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [{ type => 'monolingual' }]);
    if (!defined $src_anaph) {
        log_warn "Undefined monolingual alignmnet from: " . $tnode->get_address;
        return;
    }

    my @src_antes = $src_anaph->get_coref_chain();
    my @src_ref_antes = Treex::Tool::Align::Utils::aligned_transitively(\@src_antes, [{ type => 'monolingual' }]);

    my @ref_antes = $tnode->get_coref_nodes();
    my %ref_antes_hash = map {$_->id => 1} @ref_antes;

    my @matched = grep {$ref_antes_hash{$_->id}} @src_ref_antes;

    print (@matched ? 1 : 0);
    print "\t";
    print (@src_ref_antes ? 1 : 0);
    print "\t";
    print (@ref_antes ? 1 : 0);
    print "\n";
}

1;

=over

=item Treex::Block::Eval::Coref

Precision, recall and F-measure for coreference.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
