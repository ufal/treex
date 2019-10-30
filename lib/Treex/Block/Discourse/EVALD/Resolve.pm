package Treex::Block::Discourse::EVALD::Resolve;
use Moose;
use Treex::Core::Common;
use Data::Printer;
use Treex::Tool::Python::RunFunc;

use Treex::Tool::ML::Weka::Util;
use Treex::Tool::ML::ScikitLearn::Classifier;

extends 'Treex::Core::Block';
with 'Treex::Block::Discourse::EVALD::Base';
#=> {
#    -alias => { build_aligned_feats => 'build_aligned_feats_base' },
#    -excludes => 'build_aligned_feats',
#};

has '+ns_filter' => ( default => '' );

has 'model' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
    documentation => 'path to a trained model',
);

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/discourse/CS',
    documentation => 'path to the models relative to Treex resource_path',
);

has classifier => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
#    default       => 'weka.classifiers.trees.RandomForest',
    default       => 'weka.classifiers.functions.SMO',
#    default       => 'sklearn.SVC',
    documentation => 'classifier to be used, e.g. sklearn.SVC, weka.classifiers.trees.RandomForest',
);

has _classifier => ( is => 'ro', builder => '_build_classifier', lazy => 1 );

my %filters_to_featset = (
  '' => 'all',
  '+spell' => 'spelling',
  '+morph' => 'morphology',
  '+vocab' => 'vocabulary',
  '+syntax' => 'syntax',
  '+conn_qua' => 'connectives_quantity',
  '+conn_div' => 'connectives_diversity',
  '+conn_qua,+conn_div' => 'connectives',
  '+pron,+coref' => 'coreference',
  '+tfa' => 'tfa',
  '+readability' => 'readability',
);

my %old_to_new_l2b_labels = (
    'A' => 'A1',
    'B' => 'b-line',
    'C' => '0',
);

sub BUILD {
    my ($self) = @_;
    $self->_feat_extractor;
    $self->_classifier if ($self->classifier =~ /^sklearn/);
}

sub _build_classifier {
    my ($self) = @_;
    my $model_name = $self->model;
    # try finding a model trained without unlabeled data features
    if (!$self->_feat_extractor->uses_unlab_models) {
        $model_name =~ s/_all\./_no_unlab./;
    }
    log_debug("Evaluating using model '$model_name'\n");
    my $model_path = Treex::Core::Resource::require_file_from_share($self->model_dir . '/' . $model_name);
    return Treex::Tool::ML::ScikitLearn::Classifier->new({model_path => $model_path});
}

sub process_document {
    my ($self, $doc) = @_;

    #log_info "EVALD RESOLVE: START";
    my $feats = $self->_feat_extractor->extract_features($doc, 0);

    #log_info "EVALD RESOLVE: INSTANCES STORED TO AN ARFF FILE";

    my ($class, $prob);
    if ($self->classifier =~ /^sklearn/) {
        ($class, $prob) = $self->evaluate_sklearn($feats, $doc);
    }
    else {
        ($class, $prob) = $self->evaluate_weka($feats, $doc);
    }

    # hacky solution of transforming old L2b labels (A, B, C) to the new ones (0, b-line, A1) - no need to retrain models
    if ($self->target eq "L2b") {
        $class = $old_to_new_l2b_labels{$class} // $class;
    }
    log_info "EVALD model results:\tfeature set: ".$self->ns_filter."\tclass: $class\tprobability: $prob";

    #log_info "EVALD RESOLVE: PREDICTIONS RETURNED";
  
    my $zone = $doc->get_zone($self->language, $self->selector);

    my $set = $filters_to_featset{$self->ns_filter} // $self->ns_filter;
    
    $zone->set_attr('set_' . $set . '_evald_class', $class);
    $zone->set_attr('set_' . $set . '_evald_class_prob', $prob);

    my $feat_hash = $doc->wild->{evald_feat_hash};
    if (defined $feat_hash) {
        my @feats_to_present = qw/
            readability^flesch_reading_ease
            readability^flesch_kincaid_grade_level
            readability^smog_index
            readability^coleman_liau_index
            readability^automated_readability_index
            vocab^simpson_index
            vocab^george_udny_yule_index
            vocab^lemmas_count
        /;
        foreach my $feat_name (@feats_to_present) {
            $zone->set_attr($feat_name, $feat_hash->{$feat_name}) if (defined $feat_hash->{$feat_name});
        }
    }

    #log_info "EVALD RESOLVE: END";
}

my $PYTHON_QUERY = <<DENSITIES_QUERY;
feat_name = "%s"
feat_value = np.array([[%f]])
if feat_name in densities:
    kde = densities[feat_name]
    res = np.exp(kde.score_samples(feat_value)) * 100
    print res[0]
DENSITIES_QUERY

sub evaluate_sklearn {
    my ($self, $feats) = @_;

    my ($class_idx, $prob) = $self->_classifier->predict($feats);
    return ($self->_feat_extractor->all_classes->[$class_idx], $prob);
}

sub evaluate_weka {
    my ($self, $feats, $doc) = @_;

    # obtaining the feature structure in a multiline format not supported yet
    my $instance_str = Treex::Tool::ML::Weka::Util::format_header($self->_feat_extractor->weka_featlist, $self->_feat_extractor->all_classes);
    $instance_str .= Treex::Tool::ML::Weka::Util::format_instance($feats, undef, $self->_feat_extractor->weka_featlist, $self->_feat_extractor->all_classes);
    print STDERR $instance_str;
    print STDERR "\n";

    #log_info "EVALD RESOLVE: INSTANCES READY";

    # write it to a file to allow Weka to read it
    my $evald_features_file_name = $doc->full_filename . ($self->ns_filter ? ".".$self->ns_filter : "") . ".arff";
    open my $fh, '>:utf8', $evald_features_file_name or die "Could not open file '$evald_features_file_name' $!";
    print $fh $instance_str;
    close $fh;

    my $model_name = $self->model;
    # try finding a model trained without unlabeled data features
    if (!$self->_feat_extractor->uses_unlab_models) {
        $model_name =~ s/_all\./_no_unlab./;
    }
    log_debug("Evaluating using model '$model_name'\n");
    
    my $weka_jar = Treex::Core::Resource::require_file_from_share('installed_tools/ml-process/lib/weka-3.8.0.jar');
    # my $weka_model = Treex::Core::Resource::require_file_from_share('data/models/discourse/CS/Merlin_trees.RandomForest.model');
    my $weka_model = Treex::Core::Resource::require_file_from_share($self->model_dir . '/' . $model_name);
    
    # my $class_name = 'weka.classifiers.trees.RandomForest';
    my $class_name = $self->classifier;
    my $java_cmd = "java -Dfile.encoding=UTF8 -cp $weka_jar $class_name -l $weka_model -T $evald_features_file_name -p 0";
    print STDERR "$java_cmd\n";

    my @prediction = qx($java_cmd);
    log_debug("Result: @prediction");

    my ($class, $prob) = Treex::Tool::ML::Weka::Util::parse_output(@prediction);

    return ($class, $prob);
}


1;
#TODO adjust documentation

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::Resolve

=head1 DESCRIPTION

A base class for all textual coreference resolution blocks. 
It combines the following modules:
* anaphor candidate filter - it determines the nodes, for which an antecedent will be seleted
* antecedent candidate selector - for each anaphor, it selects a bunch of antecedent candidates
* feature extractor - it extracts features that describe an anaphor - antecedent candidate couple
* ranker - it ranks the antecedent candidates based on the feature values
ID of the predicted antecedent is filled in the anaphor's 'coref_text.rf' attribute.

=head1 PARAMETERS

=over

=item model_path

The path of the model used for resolution.

=item anaphor_as_candidate

If enabled, the block provides joint anaphoricity determination and antecedent selection.
If disabled, this block must be preceded by a block resolving anaphoricity of anaphor candidates. 

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
