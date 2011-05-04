package Treex::Block::W2A::EN::ParseMalt;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tools::Parser::Malt;

has 'model' => ( is => 'rw', isa => 'Str', default => 'en.mco' );

my $parser;

sub BUILD {
    my ($self) = @_;
    if (!$parser) {
        $parser = Treex::Tools::Parser::Malt->new( { model => $self->model } );
    }
    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # get factors
    my @forms    = map { $_->form } @a_nodes;
    my @lemmas   = map { $_->lemma } @a_nodes;
    my @subpos   = map { $_->tag } @a_nodes;
    my @pos      = map { substr($_, 0, 2) } @subpos;
    my @features = map { '_' } @subpos;

    # parse sentence
    my ( $parents_rf, $deprel_rf ) = $parser->parse( \@forms, \@lemmas, \@pos, \@subpos, \@features );

    # build a-tree
    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $deprel = shift @$deprel_rf;
        $a_node->set_conll_deprel($deprel);

        my $parent_index = shift @$parents_rf;
        if ($parent_index) {
            my $parent = $a_nodes[ $parent_index - 1 ];
            $a_node->set_parent($parent);
        }
        else {
            push @roots, $a_node;
        }
    }
    return @roots;
}

1;

__END__
 
=head1 NAME

Treex::Block::W2A::EN::ParseMalt

=head1 DECRIPTION

Malt parser (developed by Johan Hall, Jens Nilsson and Joakim Nivre, see http://maltparser.org)
is used to determine the topology of a-layer trees and I<deprel> edge labels.

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 COPYRIGHT

Copyright 2009-2011 David Mareček
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
