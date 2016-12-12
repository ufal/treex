package Treex::Block::W2A::LA::ParsingLatin;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::ParsingLatin;


    
has model  => ( is  => 'rw',  isa => 'Str', default => '1' );
has _parser => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;
    my $parser = Treex::Tool::Parser::ParsingLatin->new( model => $self->model );
    $self->_set_parser( $self->model );
    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # get factors
    my @forms  = map { $_->form } @a_nodes;
    my @lemmas = map { $_->lemma || '_' } @a_nodes;
    my @pos    = map { $_->conll_pos || '_' } @a_nodes;
    my @cpos   = map { $_->conll_cpos || '_' } @a_nodes;
    my @feats  = map { $_->conll_feat || '_' } @a_nodes;

    # parse sentence
    my ( $parents_rf, $deprel_rf ) = $self->_parser->parse_sentence( \@forms, \@lemmas, \@cpos, \@pos, \@feats );


    # build a-tree
    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $deprel = shift @$deprel_rf;
        my $parent = shift @$parents_rf;

        $a_node->set_conll_deprel($deprel);
        if ($parent) {
            $a_node->set_parent($a_nodes[ $parent - 1 ]);
        } else {
            push @roots, $a_node;
        }
    }
    return @roots;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::LA::ParsingLatin

=head1 DESCRIPTION

Uses a combined parsing pipeline [DeSR (right, MPL) + DeSR (left, SVM) + DeSR (l, MLP) + Joint + MTGB]

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>


=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.