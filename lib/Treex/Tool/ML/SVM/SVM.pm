package Treex::Tool::ML::SVM::SVM;
use Moose;
use Treex::Core::Common;
use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

# Load the model stored in the file 'sample.model'
my $svm;


sub BUILD {
  my ( $self, $params ) = @_;
  $svm = new Algorithm::SVM(Model => '/home/green/tectomt/treex/lib/Treex/Tool/ML/SVM/new.model');
  
}

sub predict(){
  my ($self, $dstest)= @_;
  
my $label = $svm->predict($dstest);
#print "Results \t". $label . "\n";

return $label;
}

1;

__END__