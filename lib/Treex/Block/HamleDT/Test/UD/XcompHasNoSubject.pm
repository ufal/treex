package Treex::Block::HamleDT::Test::UD::XcompHasNoSubject;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $deprel = $node->deprel();
    $deprel = '' if(!defined($deprel));
    if($deprel eq 'xcomp')
    {
        # Check whether there is a subject among my children.
        my @children = $node->children();
        if(any {$_->deprel() =~ m/^[nc]subj(pass)?(:|$)/} (@children))
        {
            $self->complain($node);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::XcompHasNoSubject

Controlled clausal complements (C<xcomp>) inherit their subject from the verb
that controls them (from its subject or object). They cannot have their own
subject. The subject is always attached to the controlling verb.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
