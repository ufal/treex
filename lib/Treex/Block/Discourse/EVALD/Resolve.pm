package Treex::Block::Discourse::EVALD::Resolve;
use Moose;
use Treex::Core::Common;

use Treex::Tool::ML::Weka::Util;

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
    documentation => 'Weka classifier to be used, e.g. weka.classifiers.trees.RandomForest',
);

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


sub process_document {
    my ($self, $doc) = @_;

    #log_info "EVALD RESOLVE: START";

    # obtaining the feature structure in a multiline format not supported yet
    my $instance_str = Treex::Tool::ML::Weka::Util::format_header($self->_feat_extractor->weka_featlist, $self->_feat_extractor->all_classes);
    my $feats = $self->_feat_extractor->extract_features($doc, 0);
    $instance_str .= Treex::Tool::ML::Weka::Util::format_instance($feats, undef, $self->_feat_extractor->weka_featlist, $self->_feat_extractor->all_classes);
    print STDERR $instance_str;
    print STDERR "\n";

    #log_info "EVALD RESOLVE: INSTANCES READY";

    # write it to a file to allow Weka to read it
    my $evald_features_file_name = $doc->full_filename . ($self->ns_filter ? ".".$self->ns_filter : "") . ".arff";
    open my $fh, '>:utf8', $evald_features_file_name or die "Could not open file '$evald_features_file_name' $!";
    print $fh $instance_str;
    close $fh;

    #log_info "EVALD RESOLVE: INSTANCES STORED TO AN ARFF FILE";

    my @prediction = $self->evaluate_weka($evald_features_file_name);
    my ($class, $prob) = Treex::Tool::ML::Weka::Util::parse_output(@prediction);
    log_info "EVALD Weka model results:\tfeature set: ".$self->ns_filter."\tclass: $class\tprobability: $prob";

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

sub evaluate_weka {
    my ($self, $evald_features_file_name) = @_;

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
    
    return @prediction;
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
