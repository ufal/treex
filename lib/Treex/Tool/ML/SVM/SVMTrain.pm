use strict;
use warnings;
use Algorithm::SVM;
use Algorithm::SVM::DataSet;
# Load the model stored in the file 'sample.model'
my $svm = new Algorithm::SVM();


my @tset = ();

my($file, $num_features) = @ARGV;

open FILE, "$file" or die $!;
#input file format label <tab> feature one <tab> feature 2<tab> and so on
while (<FILE>){
my @tokens=split ("\t",$_);
my @features=();
my $f=1;
#print "NUM OF FEATURE $num_features \n";
while ($f < $num_features+1){
  push (@features,$tokens[$f]);
  $f++;
}

#right now hard coded for 3 features. Should change to accept as variable
#my $ds = new Algorithm::SVM::DataSet(Label => $tokens[0],
#				     Data  => [$tokens[1],$tokens[2],$tokens[3],$tokens[4],$tokens[5],$tokens[6],$tokens[7],$tokens[8],$tokens[9],$tokens[10],$tokens[11],$tokens[12],$tokens[13],$tokens[14],$tokens[15]]);

# foreach (@features){
#   print $_."\t";
# }
# print "\n";
# my $ds = new Algorithm::SVM::DataSet(Label => $tokens[0],
# 				     Data  => \@features);
				     
# my $ds = new Algorithm::SVM::DataSet(Label => $tokens[0],
# 				     Data  => [$features[0],$features[1],$features[2],$features[3],$features[4],$features[5],$features[6],$features[7],$features[8],$features[9],$features[10],$features[11],$features[12],$features[13],$features[14],$features[15],$features[16],$features[17],$features[18],$features[19],$features[20],$features[21],$features[22],$features[23],$features[24],$features[25],$features[26],$features[27],$features[28]]);
			#	     print "$tokens[0]=[$features[0],$features[1],$features[2],$features[3],$features[4],$features[5],$features[6],$features[7],$features[8],$features[9],$features[10]]\n";				     

my $ds = new Algorithm::SVM::DataSet(Label => $tokens[0], Data  => [@features]);
							     
push (@tset,$ds);
}

# Train a new SVM on some new datasets.
$svm->train(@tset);
#print $svm;

# Save the model to a file.
$svm->save('new.model');



 #Change some of the SVM parameters.
#$svm->gamma(64);
#$svm->C(8);
# Retrain the SVM with the new parameters.
#$svm->retrain();

# Perform cross validation on the training set.
#$accuracy = $svm->validate(5);


# Load a saved model from a file.
#$svm->load('new-sample.model');

# Retreive the number of classes.
#$num = $svm->getNRClass();

# Retreive labels for dataset classes
#(@labels) = $svm->getLabels();

# Probabilty for regression models, see below for details
#$prob = $svm->getSVRProbability();