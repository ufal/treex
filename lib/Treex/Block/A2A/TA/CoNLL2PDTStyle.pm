package Treex::Block::A2A::TA::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the TamilTB CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);

    # Loop over tree nodes.
    foreach my $node ( $a_root->get_descendants() )
    {
        my $conll_cpos = $node->conll_cpos;
        my $conll_pos  = $node->conll_pos;
        my $conll_feat = $node->conll_feat;
        my $conll_tag  = "$conll_cpos\t$conll_pos\t$conll_feat";

        # fine grained positional tag
        my $pdt_tag = $node->conll_pos;

        ## Tamil POS tag has 9 positions
        ## Assigning first 2 positions: 1. POS and 2. SUBPOS
        #my $pdt_tag = "$conll_cpos$conll_pos";
        #
        ## Identify the remaining 7 positions
        #if ($conll_feat eq '_') {
        #    $pdt_tag = $pdt_tag . '-------';
        #}
        #else {
        #    my @feats = split /\|/, $conll_feat;
        #    my %feats_hash;
        #    my $feats_str = q{};
        #
        #    foreach my $feat (@feats) {
        #        my @f = split /\=/, $feat;
        #        $feats_hash{$f[0]} = $f[1];
        #    }
        #
        #    # 3rd position - Case
        #    if (exists $feats_hash{'Cas'}) {
        #        $feats_str = $feats_str . $feats_hash{'Cas'};
        #    }
        #    else  {
        #        $feats_str = $feats_str . '-';
        #    }
        #
        #    # 4th position - Tense
        #    if (exists $feats_hash{'Ten'}) {
        #        $feats_str = $feats_str . $feats_hash{'Ten'};
        #    }
        #    else  {
        #        $feats_str = $feats_str . '-';
        #    }
        #
        #    # 5th position - Person
        #    if (exists $feats_hash{'Per'}) {
        #        $feats_str = $feats_str . $feats_hash{'Per'};
        #    }
        #    else  {
        #        $feats_str = $feats_str . '-';
        #    }
        #
        #    # 6th position - Number
        #    if (exists $feats_hash{'Num'}) {
        #        $feats_str = $feats_str . $feats_hash{'Num'};
        #    }
        #    else  {
        #        $feats_str = $feats_str . '-';
        #    }
        #
        #    # 7th position - Gender
        #    if (exists $feats_hash{'Gen'}) {
        #        $feats_str = $feats_str . $feats_hash{'Gen'};
        #    }
        #    else  {
        #        $feats_str = $feats_str . '-';
        #    }
        #
        #    # 8th position - Voice
        #    if (exists $feats_hash{'Voi'}) {
        #        $feats_str = $feats_str . $feats_hash{'Voi'};
        #    }
        #    else  {
        #        $feats_str = $feats_str . '-';
        #    }
        #
        #    # 9th position - Negation
        #    if (exists $feats_hash{'Voi'}) {
        #        $feats_str = $feats_str . $feats_hash{'Voi'};
        #    }
        #    else  {
        #        $feats_str = $feats_str . '-';
        #    }
        #
        #    # Positional tag of length 9
        #    $pdt_tag = $pdt_tag . $feats_str;
        #
        #}
        #
        #my $f = tagset::ar::conll::decode($conll_tag);
        #my $pdt_tag = tagset::cs::pdt::encode($f, 1);

        my $len = length($pdt_tag);
        if ( $len != 9 ) {
            die "Something wrong with the positional tag: $pdt_tag\n";
        }

        #$node->set_iset($f);
        $node->set_tag($pdt_tag);
    }
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;
        if ( $afun =~ s/_M$// )
        {
            $node->set_is_member(1);
        }
        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::A2A::TA::CoNLL2PDTStyle

Converts TamilTB.v0.1 (Tamil Dependency Treebank) from CoNLL to the style of
the Prague Dependency Treebank. Morphological tags are of length 9. At present
no structural transformations have been done.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
