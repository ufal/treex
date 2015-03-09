package Treex::Tool::Parser::MSTperl::MultiModelParser;
use Moose;
use Carp;
extends 'Treex::Tool::Parser::MSTperl::Parser';
use List::Util qw(sum max min);

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

sub load_model_posfact {
    my ( $self, $filename, $weights ) = @_;

    my $model = Treex::Tool::Parser::MSTperl::ModelUnlabelled
        ->new(config => $self->config, posweights => $weights);
    push @{$self->model}, $model;
    $model->load($filename);
    $model->normalize();
    return $model;
}

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
    foreach my $model (@{$self->model} ) {
        
        # model-based individual normalization
        # (stores dividents to %normalization)
        if ($self->config->normalization_type eq 'inddivsumabs') {
            # -> sum abs(w) = 1
            $normalization{$model} = sum( map {
                    sum (map {abs} values %{$scores{$model}->{$_}})
                } keys(%{$scores{$model}}) );
        } elsif ($self->config->normalization_type eq 'inddivabssum') {
            # -> abs sum(w) = 1
            $normalization{$model} = abs( sum(
                    map { sum values %{$scores{$model}->{$_}} } keys(%{$scores{$model}})
                ) );

        # other  individual normalization
        } elsif ($self->config->normalization_type eq 'childdivabssum') {
            # -> abs sum(w) = 1
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                # compute normalization
                my $norm = abs( sum(
                    values %{$scores{$model}->{$child->ord}}
                ) );
                # apply normalization
                foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
                    next if ($child->ord == $parent->ord);
                    $scores{$model}->{$child->ord}->{$parent->ord} /= $norm;
                }
            }
        } elsif ($self->config->normalization_type eq 'childdivsumabs') {
            # -> sum abs(w) = 1
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                # compute normalization
                my $norm = sum( map {abs} (
                    values %{$scores{$model}->{$child->ord}}
                ) );
                # apply normalization
                foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
                    next if ($child->ord == $parent->ord);
                    $scores{$model}->{$child->ord}->{$parent->ord} /= $norm;
                }
            }
        } elsif ($self->config->normalization_type eq 'childdivstddev') {
            # -> standard deviation = 1
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                # compute normalization
                my $avg = sum( values %{$scores{$model}->{$child->ord}} ) / $sentence_length;
                my $norm = sqrt(
                    1/$sentence_length
                    * sum( map {$_*$_} (values %{$scores{$model}->{$child->ord}}) )
                    - $avg*$avg
                ) || 1; # avoid 0 -- will be dividing by it
                # apply normalization
                foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
                    next if ($child->ord == $parent->ord);
                    $scores{$model}->{$child->ord}->{$parent->ord} /= $norm;
                }
            }
        } elsif ($self->config->normalization_type eq 'childminmax') {
            # -> min = 0, max = 1
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                # compute normalization
                my $min = min( values %{$scores{$model}->{$child->ord}} );
                my $max = max( values %{$scores{$model}->{$child->ord}} );
                my $divby = ($max - $min) || 1;
                # apply normalization
                foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
                    next if ($child->ord == $parent->ord);
                    $scores{$model}->{$child->ord}->{$parent->ord}
                        = ($scores{$model}->{$child->ord}->{$parent->ord} - $min)
                        / $divby;
                }
            }
        } elsif ($self->config->normalization_type eq 'childminmax2') {
            # -> min = 0, max = 1, ^2
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                # compute normalization
                my $min = min( values %{$scores{$model}->{$child->ord}} );
                my $max = max( values %{$scores{$model}->{$child->ord}} );
                my $divby = ($max - $min)*($max - $min) || 1;
                # apply normalization
                foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
                    next if ($child->ord == $parent->ord);
                    $scores{$model}->{$child->ord}->{$parent->ord}
                        = ($scores{$model}->{$child->ord}->{$parent->ord} - $min)
                        / $divby;
                }
            }
        } elsif ($self->config->normalization_type eq 'childminmax3') {
            # -> min = 0, max = 1, ^3
            foreach my $child ( @{ $sentence_working_copy->nodes } ) {
                # compute normalization
                my $min = min( values %{$scores{$model}->{$child->ord}} );
                my $max = max( values %{$scores{$model}->{$child->ord}} );
                my $divby = ($max - $min)**3 || 1;
                # apply normalization
                foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
                    next if ($child->ord == $parent->ord);
                    $scores{$model}->{$child->ord}->{$parent->ord}
                        = ($scores{$model}->{$child->ord}->{$parent->ord} - $min)
                        / $divby;
                }
            }
        }
    }

    # finally, score the edges
    my $graph = Graph->new(
        vertices => [ ( 0 .. $sentence_length ) ]
    );
    foreach my $child ( @{ $sentence_working_copy->nodes } ) {
        foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
            next if ($child->ord == $parent->ord);

            # HERE THE MODEL COMBINATION HAPPENS
            # sum of feature weights
            my $score = 0;
            if ( $self->config->normalization_type =~ /^ind/) {
                # model-based individual normalization
                foreach my $model (@{$self->model} ) {
                    $score += $scores{$model}->{$child->ord}->{$parent->ord}
                    / $normalization{$model} * $model->weight;
                }
            } elsif ($self->config->posfact_field != -1) {
                # POS-factorization
                my $pos = $child->fields->[$self->config->posfact_field];
                # normalization
                my $divby = 1;
                if ( $self->config->posfact_normalization_type eq 'divsum' ) {
                    $divby = sum( map { $_->posweights->{$pos} } @{$self->model} );
                } elsif ( $self->config->posfact_normalization_type eq 'divmax' ) {
                    $divby = max( map { $_->posweights->{$pos} } @{$self->model} );
                }
                # compute edge score
                foreach my $model (@{$self->model} ) {
                    $score += $scores{$model}->{$child->ord}->{$parent->ord}
                    * $model->posweights->{$pos} / $divby;
                }
                # now does not allow combining individual normalization with
                # POS-factorization (but individual normalization seems not to
                # be the best thing anyway, and is not currently used)
            } else {
                # the basic version with no funny bussiness
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
