package Treex::Tool::TranslationModel::Factory;

use Moose;

use Treex::Core::Common;

use Treex::Tool::TranslationModel::Static::Model;
use Treex::Tool::TranslationModel::Rulebased::Model;
use Treex::Tool::TranslationModel::ML::Model;

use Treex::Tool::TranslationModel::Static::RelFreq::Learner_new;
use Treex::Tool::TranslationModel::ML::Learner;

sub create_model {
    my ($self, $model_type) = @_;

    my $model;
    if ($model_type eq 'static') {
        $model = Treex::Tool::TranslationModel::Static::Model->new();
    }
    elsif ($model_type eq 'rulebased') {
        # TODO make skip_names parametrizable
        $model = Treex::Tool::TranslationModel::Rulebased::Model->new({skip_names => 1});
    }
    else {
        $model = Treex::Tool::TranslationModel::ML::Model->new({ model_type => $model_type });
    }
    
    return $model;
}

sub create_learner {
    my ($self, $model_type, $learner_params) = @_;

    my $learner;
    if ($model_type eq 'static') {
        $learner = Treex::Tool::TranslationModel::Static::RelFreq::Learner_new->new($learner_params);
    }
    else {
        $learner_params->{learner_type} = $model_type;
        $learner = Treex::Tool::TranslationModel::ML::Learner->new($learner_params);
    }

    return $learner;
}

1;
