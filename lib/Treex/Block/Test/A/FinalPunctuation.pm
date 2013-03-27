package Treex::Block::Test::A::FinalPunctuation;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_zone
{
    my $self  = shift;
    my $zone  = shift;
    my $root  = $zone->get_atree();
    my @nodes = $root->get_descendants({'ordered' => 1});
    return if(!@nodes);
    my $last  = $nodes[-1];
    # Is it a punctuation mark?
    return unless($last->get_iset('pos') eq 'punc');
    # Is it attached where we expect and how we expect?
    if($last->parent() != $root)
    {
        $self->complain($last, 'parent is not root');
    }
    elsif(!defined($last->afun()) || $last->afun() ne 'AuxK')
    {
        $self->complain($last, 'afun is '.$last->afun().' instead of AuxK');
    }
}

1;

=over

=item Treex::Block::Test::A::FinalPunctuation

Sentence-final punctuation should be attached directly to root, with the AuxK afun.

There will be exceptions, e.g. if the sentence ends with a period and a quotation mark (in that order),
the current annotation scheme of PDT attaches the period as AuxK of the root, and the quotation mark
as AuxG of the main predicate (non-projectively!) We may want to change this in HamleDT.

=back

=cut

# Copyright 2013 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

