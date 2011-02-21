package SCzechM_to_SCzechA::McD_parser;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

use Treex::Tools::Parser::MST;

my $parser;

sub BUILD {
    my ($self) = @_;
    my $model = $self->get_parameter('MODEL');
    $model = "$ENV{TMT_ROOT}/share/data/models/mst_parser/cs/pdt2_non-proj_ord2_0.05.model" if !$model;
    $parser = Treex::Tools::Parser::MST->new({model => $model, decodetype => 'non-proj', order => 2, memory => '1800m'});
    print STDERR $model;
    return;
}


sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $a_root = $bundle->get_tree('SCzechA');
    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );
        
    # delete old topology
    foreach my $a_node (@a_nodes){
        $a_node->set_parent($a_root);
    }

    my @words = map { $_->get_attr('m/form') } @a_nodes;
    my @tags  = map { $_->get_attr('m/tag') } @a_nodes;
    my @short_tags = map { /(.)(.)..(.)/; ( ( $3 eq "-" ) ? ( $1 . $2 ) : ( $1 . $3 ) ); } @tags;

    my ( $parents_rf, $deprel_rf, $matrix_rf ) = $parser->parse_sentence( \@words, \@short_tags );

    foreach my $a_node (@a_nodes) {

        my $deprel = shift @$deprel_rf;
        $a_node->set_attr( 'afun', $deprel );

        if ($matrix_rf) {
            my $scores = shift @$matrix_rf;
            $a_node->set_attr('mst_scores', join(" ", @$scores));
        }

        my $parent_index = shift @$parents_rf;
        if ($parent_index) {
            my $parent = $a_nodes[ $parent_index - 1 ];
            $a_node->set_parent($parent);
        }
        else {
            $a_node->set_parent($a_root);
        }
    }
    return;
}

1;

__END__
 
=over

=item SCzechM_to_SCzechA::McD_parser

Reparse Czech analytical trees using McDonald's MST parser.

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
