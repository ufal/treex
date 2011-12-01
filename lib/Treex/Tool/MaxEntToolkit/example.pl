#!/usr/bin/env perl

# Example script to demonstrate MaxEntToolkitWrapper usage

use strict;
use warnings;
use utf8;

use Treex::Tool::MaxEntToolkit::MaxEntToolkitWrapper;

# create maxent toolkit wrapper
my $maxent = Treex::Tool::MaxEntToolkit::MaxEntToolkitWrapper->new({'maxent_binary' => '${TMT_ROOT}/share/external_tools/MaxEntToolkit/maxent_i686', 'model' => 'test_model'});

# create some training instances
my @instances = [ 'Outdoor Sunny Happy',
                  'Outdoor Sunny Happy Dry',
                  'Outdoor Sunny Happy Humid', 
                  'Indoor Rainy Happy Humid', 
                  'Indoor Rainy Happy Dry', 
                  'Indoor Rainy Sad Dry',
                ];

# train
$maxent->train(@instances);

# test
my $instance = 'Sunny Happy Dry';
my $predicted_output = $maxent->predict($instance);
print "Instance: \"$instance\"\nPredicted output: $predicted_output\n";
