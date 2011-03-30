package Treex::Block::W2A::CS::ParseMST;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tools::Parser::MST;

has 'model' => ( is => 'rw', isa => 'Str' );

my $parser;

sub BUILD {
    my ($self) = @_;
    if ( !$self->model ) {
        $self->set_model("$ENV{TMT_ROOT}/share/data/models/mst_parser/cs/pdt2_non-proj_ord2_0.05.model");
    }
    $parser = Treex::Tools::Parser::MST->new( { model => $self->model, decodetype => 'non-proj', order => 2, memory => '1000m' } );
    return;
}

sub get_short_tag {
    my ( $self, $full_tag ) = @_;
    my ( $p1, $p2, $p5 ) = $full_tag =~ /(.)(.)..(.)/;
    return $p1 . $p2 if $p5 eq '-';
    return $p1 . $p5;
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );

    # delete old topology
    foreach my $a_node (@a_nodes) {
        $a_node->set_parent($a_root);
    }

    my @words      = map { $_->form } @a_nodes;
    my @tags       = map { $_->tag } @a_nodes;
    my @short_tags = map { $self->get_short_tag($_) } @tags;

    my ( $parents_rf, $deprel_rf, $matrix_rf ) = $parser->parse_sentence( \@words, \@short_tags );

    foreach my $a_node (@a_nodes) {

        my $deprel = shift @$deprel_rf;
        $a_node->set_afun($deprel);

        if ($matrix_rf) {
            my $scores = shift @$matrix_rf;
            $a_node->set_attr( 'mst_scores', join( " ", @$scores ) );
        }

        my $parent_index = shift @$parents_rf;
        if ($parent_index) {
            my $parent = $a_nodes[ $parent_index - 1 ];
            $a_node->set_parent($parent);
        }
    }
    return;
}

1;

__END__
 
=over

=item Treex::Block::W2A::CS::ParseMST

Reparse Czech analytical trees using McDonald's MST parser.

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
