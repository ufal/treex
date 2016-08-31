package Treex::Block::HamleDT::Test::UD::MaxOneDirectObject;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my @children = $node->children();
    # Note that we intentionally ignore language-specific subtypes because the rule may not apply to them.
    my @subjects = grep {$_->deprel() =~ m/^(dobj|[cx]comp)$/} (@children);
    if(scalar(@subjects) > 1)
    {
        $self->complain($node, 'No predicate can have more than one direct object.');
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::MaxOneDirectObject

No predicate has more than one direct object.
Clausal complements count as direct objects.

=back

=cut

# Copyright 2016 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
