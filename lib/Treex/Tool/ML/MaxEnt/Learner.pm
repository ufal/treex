package Treex::Tool::ML::MaxEnt::Learner;

use Moose;
#use AI::MaxEntropy::Model;
use Treex::Tool::ML::MaxEnt::Model;

extends 'AI::MaxEntropy';

with 'Treex::Tool::ML::Learner';

sub _make_compact_hash {
    my ($self) = @_;

    my $probs = {};
    for my $y (0 .. @{$self->{y_list}}-1) {
        for my $x (0 .. @{$self->{x_list}}-1) {
            my $idx = $self->{f_map}->[$y]->[$x];
            if ($idx > -1) {
                $probs->{$self->{y_list}->[$y]}->{$self->{x_list}->[$x]} = $self->{lambda}->[$idx];
            }
        }
    }
    return $probs;
}

override '_create_model' => sub {
    my ($self) = @_;
    my $probs = $self->_make_compact_hash();
    my $model = Treex::Tool::ML::MaxEnt::Model->new({
        model => $probs,
        y_num => $self->{y_num},
    });
    return $model;
};

sub cut_features {
    my $self = shift;
    $self->cut(@_);
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::Classifier::MaxEnt::Model

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
