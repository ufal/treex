package Treex::Block::W2A::EN::RehangZparToPdtStyle;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $conj ) = @_;

    # Skip all but coordinating conjunctions
    return if $conj->tag ne 'CC';
    return if $conj->ord == 1;

    # $h_member is the member of coordination that was selected
    # as a head in the original annotation
    my $h_member = $conj->parent;
    return if $h_member->is_root();
    my $coord_parent = $h_member->parent;

    # @mix contains
    # * all members of the coordintion (including $h_member)
    # * real dependency children of $h_member
    # * commas and the conjunction ($conj, usually "and" or "or", tagged as CC)
    # Let's distinguish these three categories and create groups, e.g.:
    # $m1 "," $m2 $conj $c1 $c2 $h_member $c3 $c4
    # will result in @groups = ([$m1], [$m2], [$c1,$c2,$h_member,$c3,$c4] );
    my @mix = $h_member->get_children( { ordered => 1, add_self => 1 } );
    my @commas;
    my @groups = ( [] );
    foreach my $n (@mix) {
        if ( $n->form =~ /^[,()]$/ ) {
            push @commas, $n;
            push @groups, [];
        }
        elsif ( $n == $conj ) {
            push @groups, [];
        }
        else {
            push @{ $groups[-1] }, $n;
        }
    }

    $conj->set_parent($coord_parent);
    foreach my $comma (@commas) {
        $comma->set_parent($conj);
    }

    foreach my $group (@groups) {
        my @nodes = @$group;

        # If the group contains $h_member,
        # then the rest of the @nodes are real dependency children of $h_member
        if ( grep { $_ == $h_member } @nodes ) {
            ## Nothing to be done here (@nodes are already hanging on $h_member)
        }
        else {

            # @nodes should contain just one node (but what should we do if not?)
            # and it should be a member of the coordination.
            log_warn "Strange coordination members near " . $conj->id if @nodes > 1;
            foreach my $node (@nodes) {
                $nodes[0]->set_parent($conj);
                $nodes[0]->set_conll_deprel('COORD');
            }
        }
    }
    $h_member->set_parent($conj);
    $h_member->set_conll_deprel('COORD');
    return;
}

1;

__END__

=over

=item Treex::Block::W2A::EN::RehangZparToPdtStyle

Modifies the way of hanging coordinations
from the Zpar parser (with the default pre-trained model) style
to PDT a-level style. 

In ZPar the head of a coordination is the last member of coordination.
In PDT the head of a coordination is the conjunction.


C<W2A::EN::RehangConllToPdtStyle> must be used also to handle auxiliary verbs.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
