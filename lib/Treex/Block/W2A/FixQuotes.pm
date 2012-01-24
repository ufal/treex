package Treex::Block::W2A::FixQuotes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# function similar to grep, but it deletes the selected items from the array
# So instead of
#   my @picked = grep {/a/} @rest;
#   @rest = grep {!/a/} @rest;
# you can write just
#   my @picked = pick {/a/} @rest;
sub pick(&\@) {
    my ( $code, $array_ref ) = @_;
    my ( @picked, @notpicked );
    foreach (@$array_ref) {
        if ( $code->($_) ) {
            push @picked, $_;
        }
        else {
            push @notpicked, $_;
        }
    }
    @$array_ref = @notpicked;
    return @picked;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    # This block applies only to sentences with even number of quotation marks
    my @nodes = $atree->get_descendants( { ordered => 1 } );
    my @quotes = grep { $_->form =~ /^(["“”„‟«»]|''|``)$/ } @nodes;
    return if @quotes < 2 || @quotes % 2;

    while (@quotes) {
        my $left_q  = shift @quotes;
        my $right_q = shift @quotes;

        # We rather leave this sentence unchanged if non-matching quotes found
        return if !$self->can_be_pair_quotes( $left_q->form, $right_q->form );
        my $parent = $left_q->get_parent();

        # I don't know how to solve it when left and right quote have different parents
        next if $right_q->get_parent() != $parent;

        # If the parent is inside the quotation, it's probably OK
        next if $parent->precedes($right_q) && $left_q->precedes($parent);

        my @siblings = $parent->get_children( { ordered => 1 } );
        my @between = grep { $left_q->precedes($_) && $_->precedes($right_q) } @siblings;
        next if !@between;
        my @commas;

        if ( @between > 1 ) {
            @commas = pick { $_->afun eq 'AuxX' } @between;
        }
        if ( @between == 1 ) {
            $left_q->set_parent( $between[0] );
            $right_q->set_parent( $between[0] );
            foreach my $comma (@commas) {
                $comma->set_parent( $between[0] );
            }
        }
    }

    return;
}

sub can_be_pair_quotes {
    my ( $self, $l, $r ) = @_;
    return 1 if $l eq q{``} && $r eq q{''};     # LaTeX-like
    return 1 if $l eq q{"}  && $r eq q{"};      # vertical ASCII
    return 1 if $l eq q{“}  && $r eq q{”};      # English,...
    return 1 if $l eq q{«}  && $r eq q{»};      # French,... guillemets
    return 1 if $l eq q{„}  && $r eq q{‟};      # German, Czech,...
    return 1 if $l eq q{»}  && $r eq q{«};      # Danish
    return 0;
}

1;

=over

=item Treex::Block::W2A::FixQuotes

In a-trees, quotation marks should depend on the root of the quoted subtree.
E.g. in I<He said "I sleep"> the quotes should depend on I<sleep>, not on I<said>.

=back

=cut

# Copyright 2012 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
