package Treex::Block::W2A::ParseMalt;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::Malt;

has 'model' => ( is => 'rw', isa => 'Str', required => 1 );
has 'pos_attribute' => ( is => 'rw', isa => 'Str', default => 'tag' );
has 'cpos_attribute' => ( is => 'rw', isa =>'Str', default => 'tag' );
has 'feat_attribute' => ( is => 'rw', isa => 'Str', default => '_');
has 'deprel_attribute' => ( is => 'rw', isa => 'Str', default => 'conll/deprel' );
has _parser => (is=>'rw');
my %loaded_models;
#my $parser;

sub BUILD {
    my ($self) = @_;
    if (!$loaded_models{$self->model}){
    #if ( !$parser ) {
      my  $parser = Treex::Tool::Parser::Malt->new( { model => $self->model } );
$loaded_models{$self->model} = $parser;
    }
    $self->_set_parser($loaded_models{$self->model});	
    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # get factors
    my @forms    = map { $_->form } @a_nodes;
    my @lemmas   = map { $_->lemma || '_' } @a_nodes;
    my @pos      = map { $_->get_attr($self->pos_attribute) || '_' } @a_nodes;
    my @cpos     = map { $_->get_attr($self->cpos_attribute) || '_' } @a_nodes;
    my @features = map { get_feat($_, $self->feat_attribute) } @a_nodes;

    # parse sentence
    log_info("PARSING ".join(' ', @forms));
    log_info("INTRSET ".join(' ', @features));
    my ( $parents_rf, $deprel_rf ) = $self->_parser->parse( \@forms, \@lemmas, \@cpos, \@pos, \@features );

    # build a-tree
    my @roots = ();
    foreach my $a_node (@a_nodes) {
        $a_node->set_is_member(0);
        $a_node->set_is_shared_modifier(0);
        my $deprel = shift @$deprel_rf;
        if ($deprel =~ /_(M?S?C?)$/) {
             my $suffix = $1;
             $a_node->set_is_member($suffix =~ /M/ ? 1 : 0);
             $a_node->set_is_shared_modifier($suffix =~ /S/ ? 1 : 0);
             $a_node->wild->{is_coord_conjunction} = $suffix =~ /C/ ? 1 : 0;
             $deprel =~ s/_M?S?C?$//;
        }
        else {
             $a_node->set_is_member(0);
             $a_node->set_is_shared_modifier(0);
             $a_node->wild->{is_coord_conjunction} = 0;
        }
        $a_node->set_attr($self->deprel_attribute, $deprel);

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

#------------------------------------------------------------------------------
# For a given node returns the string suitable for the CoNLL FEAT column.
# Depending on required and available sources, the function returns either
# the conll/feat attribute, or concatenated Interset attributes, or '_'.
#------------------------------------------------------------------------------
sub get_feat
{
    my $node = shift;
    my $source = shift;
    my $feat;
    if($source =~ m/^conll/i && defined($node->conll_feat()))
    {
        $feat = $node->conll_feat();
    }
    elsif($source =~ m/^i(nter)?set/i && $node->get_iset_pairs_list())
    {
        $feat = $node->get_iset_conll_feat();
    }
    else
    {
        $feat = '_';
    }
    return $feat;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::ParseMalt

=head1 DECRIPTION

Malt parser (developed by Johan Hall, Jens Nilsson and Joakim Nivre, see http://maltparser.org/)
is used to determine the topology of a-layer trees and I<deprel> edge labels.

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 COPYRIGHT

Copyright 2009-2011 David Mareček, Dan Zeman
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
