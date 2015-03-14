package Treex::Tool::Parser::MSTperl::MultiHeteroModelParser;
use Moose;
use Carp;
extends 'Treex::Tool::Parser::MSTperl::MultiModelParser';
use List::Util qw(sum);

has normalized => ( is => 'rw', isa => 'Bool', default => 0 );

override 'load_model' => sub {
    my ( $self, $filestem, $weight ) = @_;

    $weight = 1 if !defined $weight;
    my $config = Treex::Tool::Parser::MSTperl::Config->new(
        config_file => $filestem.'.config');
    my $model = Treex::Tool::Parser::MSTperl::ModelUnlabelled
        ->new(config => $config, weight => $weight);
    push @{$self->model}, $model;
    $model->load($filestem.'.model');
    return $model;
};

# TODO
# sub load_model_posfact {
#     my ( $self, $filestem, $weights ) = @_;
# 
#     my $config = Treex::Tool::Parser::MSTperl::Config->new(
#         config_file => $filestem.'.config');
#     my $model = Treex::Tool::Parser::MSTperl::ModelUnlabelled
#         ->new(config => $config, posweights => $weights);
#     push @{$self->model}, $model;
#     $model->load($filestem.'.model');
#     $model->normalize();
#     return $model;
# }

# normalize models
sub normalize {
    my ($self) = @_;

    if ( @{$self->model} == 0 ) {
        croak "MSTperl parser error: There is no model for unlabelled parsing!";
    }
    
    foreach my $model (@{$self->model}) {
        $model->normalize();
    }

    # TODO: also normalize POS factored model weights

    $self->normalized(1);
    return ;
}

override 'parse_sentence_full' => sub {
    my ($self, $sentence_working_copy) = @_;
    
    # normalize() has to be called once before parse_sentence_full(),
    # but after loading all models by load_model() or load_model_posfact(),
    # and I don't know how to ensure that nicely
    if (!$self->normalized) {
        $self->normalize();
    }

    # to-be complete graph (now only vertices)
    my $graph = Graph->new(
        vertices => [ ( 0 .. $sentence_working_copy->len() ) ]
    );

    # create weighted edges
    foreach my $child ( @{ $sentence_working_copy->nodes } ) {
        foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {

            next if ($child->ord == $parent->ord);

            my $edge = Treex::Tool::Parser::MSTperl::Edge->new(
                child    => $child,
                parent   => $parent,
                sentence => $sentence_working_copy
            );

            # score_edge() returns already weighted edge score
            # (other scoring methods require weighting ex post)
            my $score = sum( map { $_->score_edge($edge) } @{$self->model} );

            # MaxST needed but MinST is computed -> using -$score
            $graph->add_weighted_edge($parent->ord, $child->ord, -$score);
        }
    }

    # find MST and return it
    my $msts = $graph->MST_ChuLiuEdmonds($graph);
    my @edges = $msts->edges;
    return \@edges;
};

1;

__END__


=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::MultiHeteroModelParser -- extension of
L<Treex::Tool::Parser::MSTperl::MultiModelParser> that combines multiple models that have different configs.

To be used for multisource delexicalized parser transfer.

Note: this parser cannot be used for training! Train the individual models using 
L<Treex::Tool::Parser::MSTperl::Parser> and then combine them using the
MultiHeteroModelParser.

At the moment. this parser does not support online model normalization!
(But the standard normalization is divstddev, which is offline anyway.)

Also, does not support POS factorization (but this will be added soon).

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
