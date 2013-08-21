package Treex::Tool::ML::Factory;

use Moose;

use Treex::Core::Common;
use Treex::Tool::ML::MaxEnt::Model;
#use Treex::Tool::ML::VowpalWabbit::Model;
use Treex::Tool::ML::ScikitLearn::Model;
use Treex::Tool::ML::Classifier::Linear;
use Treex::Tool::ML::MaxEnt::Learner;
#use Treex::Tool::ML::VowpalWabbit::Learner;

sub create_classifier_model {
    my ($self, $model_type) = @_;

    my $model;
    if ($model_type eq 'maxent') {
        $model = Treex::Tool::ML::MaxEnt::Model->new();
    }
#    elsif ($model_type eq 'vw') {
#        #$model = Treex::Tool::ML::VowpalWabbit::Model->new();
#        $model = Treex::Tool::ML::Classifier::Linear->new();
#    }
    # TODO dirty hack, class labels must be encapsulated within the model
    elsif ($model_type eq 'sklearn') {
        $model = Treex::Tool::ML::ScikitLearn::Model->new({classes => ['1','2','3','4']});
    }
    else {
        log_fatal "Unsupported classifier type: $model_type";
    }

    return $model;
}

sub create_learner {
    my ($self, $model_type, $params) = @_;

    my $model;
    if ($model_type eq 'maxent') {
        $model = Treex::Tool::ML::MaxEnt::Learner->new($params);
    }
#    elsif ($model_type eq 'vw') {
#        $model = Treex::Tool::ML::VowpalWabbit::Learner->new($params);
#    }
    else {
        log_fatal "Unsupported classifier type: $model_type";
    }

    return $model;
}

1;
