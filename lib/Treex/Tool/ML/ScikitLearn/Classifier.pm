package Treex::Tool::ML::ScikitLearn::Classifier;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;

has '_python' => ( is => 'ro', lazy => 1, builder => '_build_python' );
has 'model_path' => ( is => 'ro', isa => 'Str' );

has '_filename' => (
    is => 'rw',
    isa => 'Str',
);

sub BUILD {
    my ($self) = @_;
    $self->_python;
}

my $INIT = <<INIT;
from sklearn.externals import joblib
import numpy as np
import sys

model_path = "%s"
print >> sys.stderr, "Loading model " + model_path + "..."
try:
    model = joblib.load(model_path)
    print >> sys.stderr, "Model loaded!"
except Exception as e:
    print "Cannot parse and import model"
INIT

sub _build_python {
    my ($self) = @_;
    my $python = Treex::Tool::Python::RunFunc->new();
    my $cmd = sprintf $INIT, $self->model_path;
    my $res = $python->command($cmd);
    if ($res) {
        log_warn(sprintf "Cannot load a model from %s. Detailed error message: %s", $self->model_path, $res);
        exit;
    }
    return $python;
}

my $PREDICT = <<PREDICT;
x_arr = np.array(%s, dtype=np.float64).reshape(1, -1)
pred = model.predict_proba(x_arr)
print "{:d} {:f}".format(np.argmax(pred), np.max(pred))
PREDICT

sub predict {
    my ($self, $feats) = @_;
    
    my ($cand_feats, $shared_feats) = @$feats;
    my @feats_list = map {$_->[1] // $_->[2]} grep {$_->[0] !~ /^\|/} @$shared_feats;
    my $feats_str = "[ ". (join ", ", @feats_list) . " ]";
    my $cmd = sprintf $PREDICT, $feats_str;
    my $res = $self->_python->command($cmd);
    return split / /, $res;
}

1;
__END__

=encoding utf-8


=head1 NAME

Treex::Tool::ML::ScikitLearn::Classifier

=head1 DESCRIPTION

Wrapper of a ScikitLearn classifier.

=head1 METHODS

=head2 predict
Given a feature set, predict an index of a class and its probability.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
