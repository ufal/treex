package Treex::Block::Discourse::CS::EvaldEvaluateWeka;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has model => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'filename of the model to be used relative to model_dir',
);

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/discourse/CS',
    documentation => 'path to the model relative to Treex resource_path',
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

  my $evald_features_file_name = $doc->full_filename . ".arff";

  my $arff = $doc->{'coherence_weka_arff'};

  open(my $fh, '>', $evald_features_file_name) or die "Could not open file '$evald_features_file_name' $!";
  print $fh "$arff";
  close $fh;

  # log_info("Evaluate:\n$features\n");
  my $weka_jar = Treex::Core::Resource::require_file_from_share('installed_tools/ml-process/lib/weka-3.8.0.jar');
  # my $weka_model = Treex::Core::Resource::require_file_from_share('data/models/discourse/CS/Merlin_trees.RandomForest.model');
  my $weka_model = Treex::Core::Resource::require_file_from_share($self->model_dir . '/' . $self->model);

  # my $class_name = 'weka.classifiers.trees.RandomForest';
  my $class_name = $self->classifier;
  my $java_cmd = "java -cp $weka_jar $class_name -l $weka_model -T $evald_features_file_name -p 0";
  
  my @prediction = qx($java_cmd);
  log_debug("Result: @prediction");

  my ($predicted_class, $probability) = parse_weka_output(@prediction);
  my $info_string;
  if ($predicted_class ne 'N/A') {
    $info_string = "\n\n================================================================================\n\nThe predicted class for the given text is '$predicted_class', with probability '$probability'\n\n================================================================================\n";
    log_debug($info_string);
  }

  my $cs_zone = $doc->get_zone($self->language);
  $cs_zone->set_attr('evald_class', $predicted_class);
  $cs_zone->set_attr('evald_class_prob', $probability);
  
  print {$self->_file_handle} "@prediction";
  if ($predicted_class ne 'N/A') {
    print {$self->_file_handle} $info_string;
  }

} # print_footer


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


