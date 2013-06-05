package Treex::Block::Write::NERHighlightWriter;

=pod

=head NAME
Treex::Block::Write::NERHighlightWriter - Writes the analyzed text with marked types of named entities.

=head SYNOPSIS

  

=head DESCRIPTION



=cut

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

use Data::Dumper;



=pod

=over 4

=item I<process_zone>

  $dsaf = pre;

popis

=cut

my %entities;

sub read_named_entities {
    my ($n_node) = @_;
    return if not $n_node;

    my @a_ids;

    if (! $n_node->get_children) {
        # leaf node

        my $a_nodes_ref = $n_node->get_deref_attr('a.rf');

        if ($a_nodes_ref) {

            @a_ids = sort map { $_->id } @{$a_nodes_ref};
            my $aIDString = join " ", @a_ids;

            if (!defined $entities{$aIDString}) {
                $entities{$aIDString} = [];
            }

            push @{$entities{$aIDString}}, $n_node if $n_node->get_attr("ne_type");
        }

    } else {
        # internal node

        my @children = $n_node->get_children;

        @a_ids = sort map { read_named_entities($_) } @children;

        my $aIDString = join " ", @a_ids;

        if (!defined $entities{$aIDString}) {
            $entities{$aIDString} = [];
        }

        push @{$entities{$aIDString}}, $n_node if $n_node->get_attr('ne_type');
    }

    return @a_ids;
}




sub process_zone {
    my ($self, $zone) = @_;

    log_fatal "ERROR: There is a zone without n_root" and die if !$zone->has_ntree;

    my $n_root = $zone->get_ntree();
    my $a_root = $zone->get_atree();
    my @anodes = $a_root->get_descendants({ordered => 1});

    %entities = ();
    my @entity_ids = read_named_entities($n_root);
    print Dumper @entity_ids;
    print Dumper keys %entities;

    

    for my $anode (@anodes) {

	

	print $anode->get_attr("form");
	print " " unless $anode->get_attr("no_space_after");

    }

    print "\n";



    # my @anodes_with_entity = read_named_entities($n_root);


    

    # foreach (@anodes_with_entity) {

    #     foreach(@{$entities{$_}}) {
    #         print $_->get_attr("ne_type") . "\n";
    #     }
    # }

}


=pod

=back

=cut

1;
