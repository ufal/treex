package Treex::Block::HamleDT::TA::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Base'; # provides get_node_spanstring()



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        #$self->fix_morphology($node);
        #$self->classify_numerals($node);
    }
    # Do not call syntactic fixes from the previous loop. First make sure that
    # all nodes have correct morphology, then do syntax (so that you can rely
    # on the morphology you see at the parent node).
    foreach my $node (@nodes)
    {
        $self->identify_acl_relcl($node);
    }
    # It is possible that we changed the form of a multi-word token.
    # Therefore we must re-generate the sentence text.
    #$root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Figures out whether an adnominal clause is a relative clause, and changes the
# relation accordingly.
#------------------------------------------------------------------------------
sub identify_acl_relcl
{
    my $self = shift;
    my $node = shift;
    return unless($node->deprel() =~ m/^acl(:|$)/);
    # There are no overt relative pronouns in Tamil relative clauses.
    # A relative clause is headed by a participle (typically with the -a suffix).
    # It modifies a noun or a pronoun that immediately follows. I don't know
    # how strict the "immediately" is; other pre-modifiers of the noun seem possible.
    # Example (dev-s56):
    # 2008-ம் ஆண்டு ஏற்பட்ட சர்வதேச பொருளாதார நெருக்கடியைத் தொடர்ந்து ...
    # 2008-m āṇṭu ērpaṭṭa carvatēca poruḷātāra nerukkaṭiyait toṭarntu ...
    # Following the 2008 international economic crisis ...
    # lit.: 2008 year occurred-REL international economic crisis following ...
    return unless($node->is_verb() && $node->is_participle());
    my $parent = $node->parent();
    return unless($parent->is_noun() && $parent->ord() > $node->ord());
    # While we have not banned right siblings of the participle, we will ban right children.
    my @rchildren = $node->get_children({'following_only' => 1});
    return if(scalar(@rchildren) > 0);
    $node->set_deprel('acl:relcl');
    # If the enhanced graph exists, we should replace 'acl' by 'acl:relcl' there as well.
    my $wild = $node->wild();
    if(exists($wild->{enhanced}))
    {
        my @edeps = @{$wild->{enhanced}};
        foreach my $edep (@edeps)
        {
            ###!!! This approach will not catch the collapsed paths through empty nodes such as 'acl>37.1>nsubj'.
            if($edep->[0] == $node->parent()->ord() && $edep->[1] =~ m/^acl(:|$)/ && $edep->[1] !~ m/^acl:relcl(:|$)/)
            {
                $edep->[1] =~ s/^acl/acl:relcl/;
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::TA::FixUD

Tamil-specific post-processing. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
