package Treex::Block::Eval::ListNonProjTrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

my $n_nodes;
my %n_nonproj;

#------------------------------------------------------------------------------
# Counts nonprojective dependencies in the a-tree of a zone.
#------------------------------------------------------------------------------
sub process_bundle {
	my $self   = shift;
	my $bundle = shift;
	my @zones  = $bundle->get_all_zones();
	foreach my $zone (@zones) {
		my $label       = $zone->get_label();
		my $count_nodes = $label eq $self->language();
		my $root        = $zone->get_atree();
		my @nodes =
		  $root->get_descendants( { 'add_self' => 1, 'ordered' => 1 } );
		my $n = $#nodes;

        # Beware: There is no guarantee that the $node->ord() atributes 
        # constitute a contiguous sequence of integers usable as 
        # array indices! We must work with node references instead.
		for ( my $i = 0 ; $i <= $n ; $i++ ) {
			$nodes[$i]->set_attr( 'i', $i );
		}
		foreach my $node (@nodes) {
			next if ( $node == $root );
			if ($count_nodes) {
				$n_nodes++;
			}

			# Is this node attached nonprojectively?
			my $parent = $node->parent();
			next unless ($parent);
			my $nord = $node->get_attr('i');
			my $pord = $parent->get_attr('i');
			die("$nord not in <0;$n>")
			  if ( !defined($nord) || $nord < 0 || $nord > $n );
			die("$pord not in <0;$n>")
			  if ( !defined($pord) || $pord < 0 || $pord > $n );
			my ( $x, $y );

			if ( $pord > $nord ) {
				$x = $nord;
				$y = $pord;
			}
			else {
				$x = $pord;
				$y = $nord;
			}
			my $projective = 1;
			for ( my $i = $x + 1 ; $i < $y ; $i++ ) {
				my $iprojective = 0;

				# Is node $i dominated by $parent?
				my $pj;
				for ( my $j = $i ; ; $j = $pj->get_attr('i') ) {
					die("$j not in <0;$n>")
					  if ( !defined($j) || $j < 0 || $j > $n );
					die("\$nodes[$j] not found") unless ( $nodes[$j] );
					if ( $j == $pord ) {
						$iprojective = 1;
						last;
					}
					$pj = $nodes[$j]->parent();
					last unless ($pj);
				}
				if ( !$iprojective ) {
					$projective = 0;
					last;
				}
			}
			if ( !$projective ) {
			    # print the address of the non-projective tree			     
			    print $node->get_address() . "\n";
			    # no need to examine the same tree further
			    last;
			}
		}
	}
}

1;

=over

=item Treex::Block::Eval::ListNonProjTrees

Lists non-projective trees from treex files.  The list can be written into
file (ex: nonprojtrees.lst) & can be viewed using the following command,

shell$ ttred -l nonprojtrees.lst
 
=back

=cut

# Copyright 2011 Daniel Zeman
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
