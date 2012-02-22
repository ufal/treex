use strict;
use warnings;
use Algorithm::SVM;
use Algorithm::SVM::DataSet;
# Load the model stored in the file 'sample.model'
my $svm = new Algorithm::SVM();


my @tset = ();

#input file format label <tab> feature one <tab> feature 2<tab> and so on
while (<>){
my @tokens=split ("\t",$_);

#right now hard coded for 3 features. Should change to accept as variable
my $ds = new Algorithm::SVM::DataSet(Label => $tokens[0],
				     Data  => [$tokens[1],$tokens[2],$tokens[3],$tokens[4],$tokens[5],$tokens[6],$tokens[7],$tokens[8],$tokens[9],$tokens[10],$tokens[11],$tokens[12],$tokens[13],$tokens[14],$tokens[15]]);
push (@tset,$ds);
}

# Train a new SVM on some new datasets.
$svm->train(@tset);
print $svm;

# Save the model to a file.
$svm->save('new-2.model');



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