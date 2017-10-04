package Treex::Block::Discourse::CS::EvaldEvaluateWeka;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has model => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'base filename of the models to be used, relative to model_dir',
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
    documentation => 'Weka classifier to be used, e.g. weka.classifiers.trees.RandomForest',
);

sub process_zone {
}

sub print_footer {
  my ($self, $doc) = @_;
  
  my %predicted_classes;
  my %predicted_probabilities;

  my @SETS = qw(all spelling morphology vocabulary syntax connectives_quantity connectives_diversity coreference);
  
  my $info_string = "\n\n================================================================================\n\nWEKA Evaluation Results for individual sets of features:\n\n";

  foreach my $set (@SETS) {
    
    # get the features in the arff format from the previous Treex block:
    my $arff = $doc->{"coherence_weka_arff_$set"};
    
    # write it to a file to allow Weka to read it
    my $evald_features_file_name = $doc->full_filename . ".$set.arff";
    open(my $fh, '>', $evald_features_file_name) or die "Could not open file '$evald_features_file_name' $!";
    print $fh "$arff";
    close $fh;
    
    # evaluate in weka
    my $model_name = $self->model . "_$set.model";
    my @prediction = evaluate_weka($self, $model_name, $evald_features_file_name);
    ($predicted_classes{$set}, $predicted_probabilities{$set}) = parse_weka_output(@prediction);
    $info_string .= " - feature set '$set': class = '" . $predicted_classes{$set} . "', probability = '" . $predicted_probabilities{$set} . "'\n";
  }
  
  $info_string .= "\n================================================================================\n";

  log_info($info_string);

  my $cs_zone = $doc->get_zone($self->language);

  foreach my $set (@SETS) {
    $cs_zone->set_attr('set_' . $set . '_evald_class', $predicted_classes{$set});
    $cs_zone->set_attr('set_' . $set . '_evald_class_prob', $predicted_probabilities{$set});
  }
  #print {$self->_file_handle} "@prediction";
  #if ($predicted_class ne 'N/A') {
  #  print {$self->_file_handle} $info_string;
  #}

} # print_footer

sub evaluate_weka {
  my ($self, $model_name, $evald_features_file_name) = @_;
  log_debug("Evaluating using model '$model_name'\n");

  my $weka_jar = Treex::Core::Resource::require_file_from_share('installed_tools/ml-process/lib/weka-3.8.0.jar');
  # my $weka_model = Treex::Core::Resource::require_file_from_share('data/models/discourse/CS/Merlin_trees.RandomForest.model');
  my $weka_model = Treex::Core::Resource::require_file_from_share($self->model_dir . '/' . $model_name);

  # my $class_name = 'weka.classifiers.trees.RandomForest';
  my $class_name = $self->classifier;
  my $java_cmd = "java -cp $weka_jar $class_name -l $weka_model -T $evald_features_file_name -p 0";
  
  my @prediction = qx($java_cmd);
  log_debug("Result: @prediction");
  
  return @prediction;
}

=item

This is an example of a Weka prediction output:

   === Predictions on test data ===
 
     inst#     actual  predicted error prediction
         1        1:?       3:B1       0.47 

=cut

sub parse_weka_output {
  my @lines = @_;
  my $predicted_class = 'N/A';
  my $probability = 'N/A';
  foreach my $line (@lines) {
    if ($line =~ /\d+\s+\d+:\?\s+\d+:(\S+)\s+(\S+)/) {
      $predicted_class = $1;
      $probability = $2;
      last;
    }
  }
  return ($predicted_class, $probability);
}


1;

__END__

=encoding utf-8


=head1 NAME

Treex::Block::Discourse::CS::EvaldEvaluateWeka

=head1 DESCRIPTION

Evaluates features (i.e. makes predictions) using the WEKA toolkit

=head1 AUTHOR

Jiří Mírovský <mirovsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


