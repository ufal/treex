package Treex::Tool::ML::Classifier::MaxEnt;

use Moose;
use AI::MaxEntropy::Model;

with 'Treex::Tool::ML::Classifier', 'Treex::Tool::ML::Model';

has '+_model' => (
    isa => 'AI::MaxEntropy::Model',
);

sub score {
    my ($self, $instance, $class) = @_;
    return $self->_model->score($instance => $class);
}

sub all_classes {
    my ($self) = @_;
    return $self->_model->all_labels;
}

sub load_model {
    my ($self, $model_file) = @_;
    return AI::MaxEntropy::Model->new($model_file);
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::Classifier::MaxEnt

=head1 DESCRIPTION

A wrapper for the maximum entropy classifier model
implemented in C<AI::MaxEntropy>.

=head1 METHODS

=over

=item score

It assignes a score (or probability) to the given instance being
labeled with the given class.

=item all_classes

It returns all possible classes.

=item load_model

Loads a model from the given file.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
