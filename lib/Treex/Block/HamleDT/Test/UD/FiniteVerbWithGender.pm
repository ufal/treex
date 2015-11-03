package Treex::Block::HamleDT::Test::UD::FiniteVerbWithGender;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        if($node->is_finite_verb() && $node->iset()->gender() =~ m/(masc|fem)/)
        {
            my $form = lc($node->form());
            my $lemma = $node->lemma();
            my $tag = $node->tag();
            my $features = join('|', $node->iset()->get_ufeatures());
            my $deprel = $node->deprel();
            my $nchildren = scalar($node->children());
            my $children = $nchildren;
            if($nchildren>0)
            {
                my $string = join('_', map {$_->form()} ($node->get_children({'ordered' => 1, 'add_self' => 1})));
                $children .= "[$string]";
            }
            $self->complain($node, "$form\t$lemma\t$tag\t$features\t$deprel\t$children");
            # cat test.log | grep FiniteVerbWithGender | grep es-ud12 | cut -f3-8 | perl -e 'while(<>){$h{$_}++} @k=sort(keys(%h)); foreach my $k (@k) { printf("%3d %s", $h{$k}, $k); }' | less
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::FiniteVerbWithGender

This test is useful only in certain languages; it has been created because of Spanish.
Spanish verbs may have gender (masculine or feminine) if the verb form is participle.
Finite verbs should not have gender, yet it happens and usually it signals wrong POS
tag.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
