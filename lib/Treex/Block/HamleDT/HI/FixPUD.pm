package Treex::Block::HamleDT::HI::FixPUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Core::Block';



sub process_anode
{
    my $self = shift;
    my $node = shift;
    # Obl:poss is a conversion error, it should be nmod:poss (unless it is also an annotation error).
    if ($node->deprel() eq 'obl:poss')
    {
        $node->set_deprel('nmod:poss');
    }
    # Ref attaches a relative pronoun to its antecedent. Instead, it should be part of the relative clause.
    elsif ($node->deprel() eq 'ref')
    {
        my $form = $node->form();
        # The right sibling should be an acl:relcl.
        my $rs = $node->get_right_siblinig();
        if (defined($rs) && $rs->deprel() eq 'acl:relcl')
        {
            my @children = $rs->get_children({'ordered' => 1});
            my $candidate = scalar(@children) > 0 ? $children[0] : $rs;
            if ($form =~ m/^(जिसने|जिन्होंने)$/)
            {
                $node->set_parent($rs);
                $node->set_deprel('nsubj');
            }
            elsif ($form =~ m/^(जिसे|जिन्हें)$/)
            {
                $node->set_parent($rs);
                $node->set_deprel('obj');
            }
            # Note that इसमें is probably an annotation error.
            elsif ($form =~ m/^(जिसमें|जिनमें|जिससे|जिनसे|जिसपर|जहां|जब|इसमें)$/)
            {
                $node->set_parent($rs);
                $node->set_deprel('obl');
            }
            elsif ($form =~ m/^(जिसका|जिसकी|जिनकी|जिसके|जिनके)$/)
            {
                $node->set_parent($candidate);
                $node->set_deprel('nmod:poss');
                ###!!! set MISC ToDo=RelPoss?
            }
            elsif ($form eq 'जो')
            {
                $node->set_parent($rs);
                $node->set_deprel('nsubj');
                my @misc;
                @misc = split(/\|/, $node->wild()->{misc}) if (exists($node->wild()->{misc}) && defined($node->wild()->{misc}));
                push(@misc, 'ToDo=जो');
                $node->wild()->{misc} = join('|', @misc);
            }
            # थे is an annotation error.
            elsif ($form eq 'थे')
            {
                $node->set_parent($rs);
                $node->set_deprel('aux');
            }
        }
        else
        {
            ###!!! We don't have the candidate for the new parent. So what?
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HI::FixPUD

Fixes certain known problems with Google annotation of the Hindi part of the parallel treebank.

=back

=cut

# Copyright 2017 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
