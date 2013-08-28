package Treex::Block::A2A::GuessIsMember;

use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode {
    
    my ($self, $anode) = @_;
    
    # the identify_coap_members method is called on each coap root node
    if ($anode->afun =~ m/^(Coord|Apos)$/) {
        $self->identify_coap_members($anode);
    }
    
    return;
}



#------------------------------------------------------------------------------
# This method is called for coordination and apposition nodes whose members do
# not have the is_member attribute set (e.g. in Arabic and Slovene treebanks
# the information was lost in conversion to CoNLL). It estimates, based on
# afuns, which children are members and which are shared modifiers.
#------------------------------------------------------------------------------
sub identify_coap_members {

    my ($self, $coap) = @_;
    
    # We should not estimate coap membership if it is already known!
    foreach my $child ($coap->children())
    {
        if($child->is_member())
        {
            log_warn('Trying to estimate CoAp membership of a node that is already marked as member.');
        }
    }

    # Get the list of nodes involved in the structure.
    my @involved = $coap->get_children({'ordered' => 1, 'add_self' => 1});
    # Get the list of potential members and modifiers, i.e. drop delimiters.
    # Note that there may be more than one Coord|Apos node involved if there are nested structures.
    # We simplify the task by assuming (wrongly) that nested structures are always members and never modifiers.
    # Delimiters can have the following afuns:
    # Coord|Apos ... the root of the structure, either conjunction or punctuation
    # AuxY ... other conjunction
    # AuxX ... comma
    # AuxG ... other punctuation
    my @memod = grep {$_->afun() !~ m/^Aux[GXY]$/ && $_!=$coap} (@involved);
    # If there are only two (or fewer) candidates, consider both members.
    if(scalar(@memod)<=2)
    {
        foreach my $m (@memod)
        {
            $m->set_is_member(1);
        }
    }
    else
    {
        # Hypothesis: all members typically have the same afun.
        # Find the most frequent afun among candidates.
        # For the case of ties, remember the first occurrence of each afun.
        # Do not count nested 'Coord' and 'Apos': these are jokers substituting any member afun.
        # Same for 'ExD': these are also considered members (in fact they are children of an ellided member).
        my %count;
        my %first;
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            next if($afun =~ m/^(Coord|Apos|ExD)$/);
            $count{$afun}++;
            $first{$afun} = $m->ord() if(!exists($first{$afun}));
        }
        # Get the winning afun.
        my @afuns = sort
        {
            my $result = $count{$b} <=> $count{$a};
            unless($result)
            {
                $result = $first{$a} <=> $first{$b};
            }
            return $result;
        }
        (keys(%count));
        # Note that there may be no specific winning afun if all candidate afuns were Coord|Apos|ExD.
        my $winner = @afuns ? $afuns[0] : '';
        ###!!! If the winning afun is 'Atr', it is possible that some Atr nodes are members and some are shared modifiers.
        ###!!! In such case we ought to check whether the nodes are delimited by a delimiter.
        ###!!! This has not yet been implemented.
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            if($afun eq $winner || $afun =~ m/^(Coord|Apos|ExD)$/)
            {
                $m->set_is_member(1);
            }
        }
    }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::GuessIsMember

=head1 DESCRIPTION

This module tries to set correctly the is_member attribute.
It is based on Treex::Block::A2A::CoNLL2PDTStyle/identify_coap_members()

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
