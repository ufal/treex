use Algorithm::SVM;
use Algorithm::SVM::DataSet;
# Load the model stored in the file 'sample.model'
$svm = new Algorithm::SVM();


@tset = ();

while (<>){
my @tokens=split ("\t",$_);

my $ds = new Algorithm::SVM::DataSet(Label => $tokens[0],
				     Data  => [$tokens[1],$tokens[2],$tokens[3]]);
				     
				#     print $tokens[0] ."\t".$tokens[1]."\t".$tokens[2]."\t".$tokens[3];
push (@tset,$ds);
}
		   

# Train a new SVM on some new datasets.
$svm->train(@tset);
print $svm;

my $dstest = new Algorithm::SVM::DataSet(Label => "test",
				     Data  => ["NNP",3,32]);
				     
				     
$res = $svm->predict($dstest);
print "Results \t". $res . "\n";


 #Change some of the SVM parameters.
#$svm->gamma(64);
#$svm->C(8);
# Retrain the SVM with the new parameters.
#$svm->retrain();

# Perform cross validation on the training set.
#$accuracy = $svm->validate(5);

# Save the model to a file.
#$svm->save('new-sample.model');

# Load a saved model from a file.
#$svm->load('new-sample.model');

# Retreive the number of classes.
#$num = $svm->getNRClass();

# Retreive labels for dataset classes
#(@labels) = $svm->getLabels();

# Probabilty for regression models, see below for details
#$prob = $svm->getSVRProbability();