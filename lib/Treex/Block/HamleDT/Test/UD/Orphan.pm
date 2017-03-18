package Treex::Block::HamleDT::Test::UD::Orphan;
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
        if($node->is_verb())
        {
            my @nconjuncts = grep {$_->deprel() eq 'conj' && $_->is_noun()} ($node->children());
            if(scalar(@nconjuncts)>=1)
            {
                # The nouns could be nominal predicates. Check for copulas (but note that some
                # languages do not have copulas).
                @nconjuncts = grep {my $n = $_; !any {$_->deprel() eq 'cop'} ($n->children())} (@nconjuncts);
                if(scalar(@nconjuncts)>=1)
                {
                    # The remaining conjuncts could be promoted orphans of an elided verb.
                    # If they have other nouns as children, are these attached via the orphan relation?
                    foreach my $nc (@nconjuncts)
                    {
                        # Also ignore nmod relations. A noun can be modified by another noun via nmod, regardless whether it is an orphan.
                        my @nchildren = grep {$_->is_noun() && $_->deprel() !~ m/^(orphan|nmod|appos|conj)$/} ($nc->children());
                        foreach my $nch (@nchildren)
                        {
                            $self->complain($nch, 'Candidate for the orphan relation?');
                        }
                    }
                }
            }
        }
    }
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Test::UD::Orphan

=head1 DESCRIPTION

If a verb has a conj child that is a noun and is not a nonverbal predicate
(there is no copula), chances are that it is a promoted orphaned argument of
a conjunct verb. If there is another argument, it should be attached as orphan.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
