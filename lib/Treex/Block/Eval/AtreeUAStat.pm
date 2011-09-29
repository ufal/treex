package Treex::Block::Eval::AtreeUAStat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
has '+language' => ( required => 1 );

use List::MoreUtils qw(indexes each_array);

my @TYPES = qw(member shared and other participant);

my %count;
my %correct;

sub is_type {
    my ( $self, $type, $node ) = @_;
    my $m = $node->is_member || 0;
    my $s = $node->is_shared_modifier || 0;
    my $a = $node->wild->{is_coord_conjunction} || 0;
    my $o = !$m && !$s && !$a;
    my $p = $m || $s || $a;
    return $m if $type eq 'member';
    return $s if $type eq 'shared';
    return $a if $type eq 'and';
    return $o if $type eq 'other';
    return $p if $type eq 'participant';
    log_fatal "Unknown type $type";
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $ref_zone = $bundle->get_zone( $self->language, $self->selector );
    my @hyp_zones = grep { $_ ne $ref_zone && $_->language eq $self->language } $bundle->get_all_zones();
    my @ref_nodes = $ref_zone->get_atree->get_descendants( { ordered => 1 } );

    my %indices;
    foreach my $type (@TYPES) {
        my @ind = indexes { $self->is_type( $type, $_ ) } @ref_nodes;
        $indices{$type} = \@ind;
        $count{$type} += @ind;
    }

    foreach my $hyp_zone (@hyp_zones) {
        my @hyp_nodes = $hyp_zone->get_atree->get_descendants( { ordered => 1 } );
        if ( @hyp_nodes != @ref_nodes ) {
            log_fatal 'There must be the same number of nodes in compared trees';
        }

        my $label = $hyp_zone->get_label;
        for my $type (@TYPES) {
            my @ind    = @{ $indices{$type} };
            my @ref_n  = @ref_nodes[@ind];
            my @hyp_n  = @hyp_nodes[@ind];
                my $ea = each_array( @ref_n, @hyp_n );
            while ( my ( $r_node, $h_node ) = $ea->() ) {
                my $same_parent = ( $r_node->get_parent->ord == $h_node->get_parent->ord );
                my $same_type = ( $self->is_type( $type, $r_node ) == $self->is_type( $type, $h_node ) );
                $correct{"$label-$type-parent"} += $same_parent;
                $correct{"$label-$type-type"} += $same_type;
                $correct{"$label-$type-both"} += ($same_parent * $same_type);
            }
        }
    }
}

END {
    foreach my $name ( sort keys %correct ) {
        my ($label, $type, $parent) = split /-/, $name;
        my $all = $count{$type};
        my $ok = $correct{$name};
        my $ratio = $ok / $all; 
        print "$name\t$ok/$all\t$ratio\n";
    }
}

1;

=over

=item Treex::Block::Eval::AtreeUAStat

Measure similarity (in terms of unlabeled attachment score) of a-trees in all zones
(of a given language) with respect to the reference zone specified by selector
for different types of nodes:
  member (of a coordination)
  shared (modifier)
  and (coordinating conjunction)
  other (!member && !shared && !and)
  participant (member || shared || and)
 
Three scores are reported for each type:
  parent -- whether the correct parent was assigned
  type   -- whether the correct type (member, shared, and) was assigned
  both   -- both parent and type is correct 

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
