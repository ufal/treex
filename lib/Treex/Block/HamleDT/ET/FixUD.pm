package Treex::Block::HamleDT::ET::FixUD;
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
# relation accordingly. The Estonian EWT data is unusual in that acl:relcl is
# already identified in the basic tree but the corresponding edge in the
# enhanced graph is labeled only acl. We need to fix the enhanced label because
# without it the enhanced relations will not be correctly transformed in
# AddEnhancedUD.
#------------------------------------------------------------------------------
sub identify_acl_relcl
{
    my $self = shift;
    my $node = shift;
    return unless($node->deprel() =~ m/^acl:relcl$/);
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

=item Treex::Block::HamleDT::ET::FixUD

Estonian-specific post-processing. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2020 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
