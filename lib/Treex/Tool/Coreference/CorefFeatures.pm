package Treex::Tool::Coreference::CorefFeatures;
use Moose;

extends 'Treex::Tool::ML::Ranker::Features';

has '+node1_label' => ( default => 'anaph' );
has '+node2_label' => ( default => 'cand' );

1;
