package Treex::Block::Discourse::CS::EvaldEvaluateWeka;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_document {
  my ($self, $doc) = @_;

  my $evald_features_file_name = $doc->full_filename . ".arff";

  my $arff = $doc->{'coherence_weka_arff'};

  open(my $fh, '>', $evald_features_file_name) or die "Could not open file '$evald_features_file_name' $!";
  print $fh "$arff";
  close $fh;

  # log_info("Evaluate:\n$features\n");
  my $weka_jar = Treex::Core::Resource::require_file_from_share('installed_tools/ml-process/lib/weka-3.8.0.jar');
  my $weka_model = Treex::Core::Resource::require_file_from_share('data/models/discourse/CS/Merlin_trees.RandomForest.model');

  my $class_name = 'weka.classifiers.trees.RandomForest';
  my $java_cmd = "java -cp $weka_jar $class_name -l $weka_model -T $evald_features_file_name -p 0";
  
  my @prediction = qx($java_cmd);
  log_info("Result: @prediction");

  my $evald_evaluation_output_file_name = $doc->full_filename . ".prediction";
  open($fh, '>', $evald_evaluation_output_file_name) or die "Could not open file '$evald_evaluation_output_file_name' $!";
  print $fh "@prediction";
  close $fh;

} # process_document






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


