package Treex::Block::HamleDT::Test::UD::MaxOneSubject;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my @children = $node->children();
    # Note that we intentionally ignore language-specific subtypes of subject.
    # In Finnish, they allow clauses as predicates with copula and they distinguish the additional subject by 'nsubj:cop'.
    my @subjects = grep {$_->deprel() =~ m/^[nc]subj(pass)?$/} (@children);
    if(scalar(@subjects) > 1)
    {
        $self->complain($node, 'No predicate can have more than one subject.');
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::MaxOneSubject

No predicate has more than one subject. Note that constructions with copula
where the predicate would be a finite clause are kept with the copula as head,
unlike all other copula constructions. Otherwise we would have one subject
from the copula construction and another from the predicate-clause.

=back

=cut

# Copyright 2016 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
