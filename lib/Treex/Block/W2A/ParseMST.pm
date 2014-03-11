package Treex::Block::W2A::ParseMST;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Core::Config;
use Treex::Tool::Parser::Factory;

has model => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'filename of the model to be used relative to model_dir',
);

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/parser/mst',
    documentation => 'path to the model relative to Treex resource_path',
);

has memory => (
    is            => 'ro',
    isa           => 'Str',
    lazy_build    => 1,
    documentation => 'How much memory should be alocated for the Java, e.g. 4000m',
);

sub _build_memory {
    return '4000m';
}

has detect_attributes_from_deprel => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'fill is_member, is_shared_modifier and is_coord_conjunction according to deprel =~ /_[MSC]$/',
);

has order            => ( is => 'ro', isa => 'Str', default => '2' );
has decodetype       => ( is => 'ro', isa => 'Str', default => 'non-proj' );
has pos_attribute    => ( is => 'ro', isa => 'Str', default => 'tag' );
has deprel_attribute => ( is => 'ro', isa => 'Str', default => 'conll/deprel' );

has robust => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'try to recover from MST failures by paring 2 more times and returning flat tree at least'
);

# other possible values: '0.5.0'
has version		=>	(isa => 'Str', is => 'ro', default => '0.4.3b');


#TODO: loading each model only once should be handled in different way
has _parser => ( is => 'rw' );
my %loaded_models;

sub BUILD {
    my ($self)  = @_;

    return;
}

sub process_start {
    my ($self)  = @_;
    my ($model) = $self->require_files_from_share( $self->model_dir . '/' . $self->model );
    my $use_services = Treex::Core::Config->use_services || 0;
    my $key = "$use_services-$model";

    if ( !$loaded_models{$key} ) {
        my $parser = Treex::Tool::Parser::Factory->create(
            'MST',
            model      => $model,
            memory     => $self->memory,
            order      => $self->order,
            decodetype => $self->decodetype,
            robust     => $self->robust,
            version	   => $self->version,
        );
        $loaded_models{$key} = $parser;
    }
    $self->_set_parser( $loaded_models{$key} );

    $self->SUPER::process_start();

    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    my @words = map { $_->form } @a_nodes;
    my @tags  = map { $_->get_attr( $self->pos_attribute ) } @a_nodes;

    my ( $parents_rf, $deprel_rf, $matrix_rf ) = $self->_parser->parse_sentence( \@words, \@tags);

    my @scores;
    if ($matrix_rf) {
    	@scores = @$matrix_rf;
    }

    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $deprel = shift @$deprel_rf;

        if ( $self->detect_attributes_from_deprel ) {
            $a_node->set_is_member(0);
            $a_node->set_is_shared_modifier(0);
            $a_node->wild->{is_coord_conjunction} = 0;
            if ( $deprel =~ /_(M?S?C?)$/ ) {
                my $suffix = $1;
                $a_node->set_is_member( $suffix          =~ /M/ ? 1 : 0 );
                $a_node->set_is_shared_modifier( $suffix =~ /S/ ? 1 : 0 );
                $a_node->wild->{is_coord_conjunction} = $suffix =~ /C/ ? 1 : 0;
                $deprel =~ s/_M?S?C?$//;
            }
        }
        $a_node->set_attr( $self->deprel_attribute, $deprel );

        if ($matrix_rf) {
            my $score = shift @scores;
            if ($score) {
                $a_node->set_attr( 'mst_score', $score );
                $a_node->wild()->{'mst_score'} = $score;
            }
        }

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

Treex::Block::W2A::ParseMST

=head1 DECRIPTION

MST parser (maximum spanning tree dependency parser by R. McDonald)
is used to determine the topology of a-layer trees and I<deprel> edge labels.

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
