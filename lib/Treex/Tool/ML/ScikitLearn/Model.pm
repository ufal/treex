package Treex::Tool::ML::ScikitLearn::Model;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;

with 'Treex::Tool::ML::Classifier', 
     'Treex::Tool::Storage::Storable' => {
        -alias => { load  => '_load', save => '_save' },
        -excludes => [ 'load', 'save' ],
     };

has 'classes' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);

#has '_python' => (
#    is => 'ro',
#    lazy => 1,
#    builder => '_build_python',
#);

has '_filename' => (
    is => 'rw',
    isa => 'Str',
);

#sub BUILD {
#    my ($self) = @_;
#    $self->_python;
#}

my $INIT = <<INIT;
import os, sys
lib_path = os.path.abspath('/home/mnovak/projects/mt_coref/lib')
sys.path.append(lib_path)
import model
model = model.Model()
INIT

#sub _build_python {
#    my ($self) = @_;
#    my $python = Treex::Tool::Python::RunFunc->new();
#    $python->command($INIT);
#    return $python;
#}

my $SCORE = <<SCORE;
x = %s
y = '%s'
classes = %s
classes.sort()
idx = classes.index(y)
x_hash = { k:v for (k,v) in (tuple(s.split("=")) for s in x) }
try:
  score = model.predict_proba(x_hash)
  print score[0][idx]
except NotImplementedError:
  score = model.predict(x_hash)
  if score[0] == y:
      print 1.0
  else:
      print 0.0
SCORE

sub score {
    my ($self, $x, $y) = @_;
    my $arr_str = "['" . (join "','", @$x) . "']";
    my $classes_str = "['" . (join "','", @{$self->classes}) . "']";

    my $command = $INIT . "\n" . sprintf("model.load('%s')", $self->_filename) . "\n" . sprintf($SCORE, $arr_str, $y, $classes_str) . "\n";
    print STDERR $command;
    #my $score = $self->_python->command(sprintf($SCORE, $arr_str, $y, $classes_str));
    my $python = Treex::Tool::Python::RunFunc->new();
    my $score = $python->command($command);
    print STDERR "SCORE: $y $score\n";
    return $score;
}

sub log_feat_weights {
}

sub all_classes {
    my ($self) = @_;
    return @{$self->classes};
}

############# implementing Treex::Tool::Storage::Storable role #################

# TODO this is hacky

sub save {
    my ($self, $filename) = @_;
    log_info "Storing sklearn model into $filename...";
    $self->_python->command("model.save('$filename')");
}

sub load {
    my ($self, $filename) = @_;
    $filename = $self->_locate_model_file($filename);
    log_info "Loading sklearn model from $filename...";
    $self->_set_filename($filename);
    #$self->_python->command("model.load('$filename')");
}

sub freeze {
}

sub thaw {
}

#############################################################################
