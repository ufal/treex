package Treex::Tool::Parser::MSTperl::MultiModelParser;
use Moose;
use Carp;
extends 'Treex::Tool::Parser::MSTperl::Parser';
use List::Util "sum";

has '+model' => (
    isa => 'Maybe[ArrayRef[Treex::Tool::Parser::MSTperl::ModelUnlabelled]]',
);

# empty build
override '_build_model' => sub {
    return [];
};

override 'load_model' => sub {
    my ( $self, $filename, $weight ) = @_;

    $weight = 1 if !defined $weight;
    my $model = Treex::Tool::Parser::MSTperl::ModelUnlabelled
        ->new(config => $self->config, weight => $weight);
    push @{$self->model}, $model;
    $model->load($filename);
    $model->normalize();
    return $model;
};

override 'parse_sentence_full' => sub {
    my ($self, $sentence_working_copy) = @_;

    if ( @{$self->model} == 0 ) {
        croak "MSTperl parser error: There is no model for unlabelled parsing!";
    }

    my $sentence_length = $sentence_working_copy->len();

    # first, get the model scores
    my %scores = ();
    foreach my $child ( @{ $sentence_working_copy->nodes } ) {
        foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
            if ( $child == $parent ) {
                next;
            }

            my $edge = Treex::Tool::Parser::MSTperl::Edge->new(
                child    => $child,
                parent   => $parent,
                sentence => $sentence_working_copy
            );

            my $features = $self->config->unlabelledFeaturesControl
                ->get_all_features($edge);

            foreach my $model (@{$self->model} ) {
                $scores{$model}->{$child->ord}->{$parent->ord} =
                    $model->score_features($features)
            }
        }
    }

    # next, normalize them
    # TODO: also try to use a running sum average for ind*
    my %normalization = ();
    use List::Util "sum";
    foreach my $model (@{$self->model} ) {
        if ($self->config->normalization_type eq 'inddivsumabs') {
            $normalization{$model} = 1 / sum( map {
                    sum (map {abs} values %{$scores{$model}->{$_}})
                } keys(%{$scores{$model}}) );
        } elsif ($self->config->normalization_type eq 'inddivabssum') {
            $normalization{$model} = 1 / abs( sum(
                    map { sum values %{$scores{$model}->{$_}} } keys(%{$scores{$model}})
                ) );
        } elsif ($self->config->normalization_type eq 'childdivabssum') {
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                $normalization{$model}->{$child->ord} = 1 / abs( sum(
                    values %{$scores{$model}->{$child->ord}}
                ) );
            }
        } elsif ($self->config->normalization_type eq 'childdivsumabs') {
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                $normalization{$model}->{$child->ord} = 1 / sum( map {abs} (
                    values %{$scores{$model}->{$child->ord}}
                ) );
            }
        } elsif ($self->config->normalization_type eq 'childdivstddev') {
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                my $sum = sum( values %{$scores{$model}->{$child->ord}} );
                my $avg = $sum/$sentence_length;
                my $var = 1/$sentence_length
                    * sum( map {$_*$_} (values %{$scores{$model}->{$child->ord}}))
                    - $avg*$avg;
                $normalization{$model}->{$child->ord} = 1 / sqrt($var);
            }
        }
    }

    # finally, score the edges
    my $graph = Graph->new(
        vertices => [ ( 0 .. $sentence_length ) ]
    );
    foreach my $child ( @{ $sentence_working_copy->nodes } ) {
        foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
            if ( $child == $parent ) {
                next;
            }

            # HERE THE MODEL COMBINATION HAPPENS
            # sum of feature weights
            my $score = 0;
            # model-based individual normalization
            if ( $self->config->normalization_type =~ /^ind/) {
                foreach my $model (@{$self->model} ) {
                    $score += $scores{$model}->{$child->ord}->{$parent->ord}
                    * $normalization{$model} * $model->weight;
                }
            # model- and child-based individual normalization
            } elsif ( $self->config->normalization_type =~ /^child/) {
                foreach my $model (@{$self->model} ) {
                    $score += $scores{$model}->{$child->ord}->{$parent->ord}
                    * $normalization{$model}->{$child->ord} * $model->weight;
                }
            # some other non-individual normalization, not happening here
            } else {
                foreach my $model (@{$self->model} ) {
                    $score += $scores{$model}->{$child->ord}->{$parent->ord}
                    * $model->weight;
                }
            }

            # MaxST needed but MinST is computed
            #  -> need to normalize score as -$score
            $graph->add_weighted_edge($parent->ord, $child->ord, -$score);
        }
    }

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

Treex::Tool::Parser::MSTperl::MultiModelParser -- extension of
L<Treex::Tool::Parser::MSTperl::Parser> that combines multiple models.

To be used for multisource delexicalized parser transfer.

Note: this parser cannot be used for training! Train the individual models using 
L<Treex::Tool::Parser::MSTperl::Parser> and then combine them using the
MultiModelParser.

At the moment, the models are required to have identical configuration, because
it is not only a configuration of the model but also of the parser -- and this
parser does support having multiple models, but does not support having multiple
configurations!

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
