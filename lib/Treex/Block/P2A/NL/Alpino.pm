package Treex::Block::P2A::NL::Alpino;
use Moose;
use Treex::Core::Common;
use utf8;
use tagset::nl::cgn;

extends 'Treex::Core::Block';

my %HEAD_SCORE = ('hd' => 6, 'cmp' => 5, 'crd' => 4, 'dlink' => 3, 'rhd' => 2, 'whd' => 1);

sub convert_pos {
    my ($self, $node, $postag) = @_;
    
    # convert to Interset (TODO would need CoNLL encoding capability to set CoNLL POS+feat)
    my $iset = tagset::nl::cgn::decode($postag);
    $node->set_iset($iset);
}

sub create_subtree {
    my ($self, $p_root, $a_root) = @_;
    my @children = sort {($HEAD_SCORE{$b->wild->{rel}} || 0) <=> ($HEAD_SCORE{$a->wild->{rel}} || 0)} grep {!defined $_->form || $_->form !~ /^\*\-/} $p_root->get_children();
    #my @children = sort {($HEAD_SCORE{$b->wild->{rel}} || 0) <=> ($HEAD_SCORE{$a->wild->{rel}} || 0)} $p_root->get_children();
    my $head = $children[0];
    foreach my $child (@children) {
        my $new_node;
        if ($child == $head) {
            $new_node = $a_root;
        }
        else {
            $new_node = $a_root->create_child();
        }
        if (defined $child->form) { # the node is terminal
            $self->fill_attribs($child, $new_node);
        }
        elsif (defined $child->phrase) { # the node is nonterminal
            $self->create_subtree($child, $new_node);
        }
    }
}

# fill newly created node with attributes from source
sub fill_attribs {
    my ($self, $source, $new_node) = @_;

    $new_node->set_form($source->form);
    $new_node->set_lemma($source->lemma);
    $new_node->set_tag($source->tag);
    $new_node->set_attr('ord', $source->wild->{pord});
    $new_node->set_conll_deprel($source->wild->{rel});
    $self->convert_pos($new_node, $source->wild->{postag});
    foreach my $attr (keys %{$source->wild}) {
        next if $attr =~ /^(pord|rel)$/;
        $new_node->wild->{$attr} = $source->wild->{$attr};
    }
}


sub process_zone {
    my ($self, $zone) = @_;
    my $p_root = $zone->get_ptree;
    my $a_root = $zone->create_atree();
    foreach my $child ($p_root->get_children()) {
        my $new_node = $a_root->create_child();
        if ($child->phrase) {
            $self->create_subtree($child, $new_node);
        }
        else {
            $self->fill_attribs($child, $new_node);
        }
    }
}

1;

=over

=item Treex::Block::P2A::NL::Alpino

Converts phrase-based Dutch Alpino Treebank to dependency format.

=back

=cut

# Copyright 2014 David Mareček <marecek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
