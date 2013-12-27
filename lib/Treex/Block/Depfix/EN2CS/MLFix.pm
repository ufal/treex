package Treex::Block::Depfix::EN2CS::MLFix;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Block::Depfix::MLFix';

use Treex::Tool::Depfix::CS::FormGenerator;
use Treex::Tool::Depfix::MaxEntModel;
use Treex::Tool::Depfix::NaiveBayesModel;
use Treex::Tool::Depfix::DecisionTreesModel;

has c_gen_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_gen_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has c_num_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_num_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has c_cas_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_cas_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has model_type => ( is => 'rw', isa => 'Str', default => 'maxent' );
# allowed values: maxent, nb, dt

override '_build_form_generator' => sub {
    my ($self) = @_;

    return Treex::Tool::Depfix::CS::FormGenerator->new();
};

override '_load_models' => sub {
    my ($self) = @_;

    my $model_params_gen = {
        config_file => $self->c_gen_config_file,
        model_file  => $self->c_gen_model_file,
    };
    my $model_params_num = {
        config_file => $self->c_num_config_file,
        model_file  => $self->c_num_model_file,
    };
    my $model_params_cas = {
        config_file => $self->c_cas_config_file,
        model_file  => $self->c_cas_model_file,
    };

    if ( $self->model_type eq 'maxent' ) {
        $self->_models->{c_cas} =
        Treex::Tool::Depfix::MaxEntModel->new($model_params_cas);
    } elsif ( $self->model_type eq 'nb' ) {
        $self->_models->{c_cas} =
        Treex::Tool::Depfix::NaiveBayesModel->new($model_params_cas);
    } elsif ( $self->model_type eq 'dt' ) {
        $self->_models->{c_gen} =
        Treex::Tool::Depfix::DecisionTreesModel->new($model_params_gen);
        $self->_models->{c_num} =
        Treex::Tool::Depfix::DecisionTreesModel->new($model_params_num);
        $self->_models->{c_cas} =
        Treex::Tool::Depfix::DecisionTreesModel->new($model_params_cas);
    }

    return;
};

my @tag_parts = qw(pos sub gen num cas pge pnu per ten gra neg voi);

override 'fill_language_specific_features' => sub {
    my ($self, $features, $child, $parent, $child_orig, $parent_orig) = @_;

    # tag parts
    my @new_child_tag_split  = split //, $child->tag;
    my @new_parent_tag_split = split //, $parent->tag;
    my @orig_child_tag_split  = split //, $child_orig->tag;
    my @orig_parent_tag_split = split //, $parent_orig->tag;
    for (my $i = 0; $i < scalar(@tag_parts); $i++) {
        my $part = $tag_parts[$i];
        $features->{"new_c_tag_$part"} = $new_child_tag_split[$i];
        $features->{"new_p_tag_$part"} = $new_parent_tag_split[$i];
        $features->{"c_tag_$part"} = $orig_child_tag_split[$i];
        $features->{"p_tag_$part"} = $orig_parent_tag_split[$i];
    }

    return;
};

override '_predict_new_tags' => sub {
    my ($self, $child, $model_predictions) = @_;

    # old
    my $tag = $child->tag;
    my @categories = split //, $tag;
    my ($old_gen, $old_num, $old_cas) =
        ($categories[2], $categories[3], $categories[4]);

    # new
    my ($new_gen) = (keys %{$model_predictions->{c_gen}} );
    my ($new_num) = (keys %{$model_predictions->{c_num}} );
    my ($new_cas) = (keys %{$model_predictions->{c_cas}} );
    if ( !defined $new_gen ) {
        $new_gen = $old_gen;
    }
    if ( !defined $new_num ) {
        $new_num = $old_num;
    }
    if ( !defined $new_cas ) {
        $new_cas = $old_cas;
    }

    substr $tag, 2, 3, $new_gen.$new_num.$new_cas;

    return { $tag => 1 };
};


1;

=head1 NAME 

Depfix::EN2CS::MLFix -- fixes errors using a machine learned correction model,
with EN as the source language and CS as the target language

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

