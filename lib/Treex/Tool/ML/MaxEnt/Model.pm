package Treex::Tool::ML::MaxEnt::Model;

use Moose;

use Treex::Core::Common;

use AI::MaxEntropy::Model;

use Storable;
use PerlIO::gzip;

extends 'Treex::Tool::ML::Classifier::Linear';

has 'y_num' => (
    isa => 'Int',
    is => 'ro',
    builder => '_build_y_num',
    lazy => 1,
    writer => '_set_y_num',
);

sub _build_y_num {
    my ($self) = @_;
    return scalar (keys %{$self->model});
}

sub import_model {
    my ($model_to_import) = @_;

    log_fatal "Only AI::MaxEntropy::Model can be imported." 
        if (!$model_to_import->isa('AI::MaxEntropy::Model'));

    my $probs = {};
    for my $y (0 .. @{$model_to_import->{y_list}}-1) {
        for my $x (0 .. @{$model_to_import->{x_list}}-1) {
            my $idx = $model_to_import->{f_map}->[$y]->[$x];
            if ($idx > -1) {
                $probs->{$model_to_import->{y_list}->[$y]}->{$model_to_import->{x_list}->[$x]} = $model_to_import->{lambda}->[$idx];
            }
        }
    }

    my $model = Treex::Tool::ML::MaxEnt::Model->new({ 
        model => $probs, 
        y_num => $model_to_import->{y_num} 
    });
    return $model;
}

############# implementing Treex::Tool::Storage::Storable role #################

override 'freeze' => sub {
    my ($self) = @_;
    return [ $self->model, $self->y_num ];
};

override 'thaw' => sub {
    my ($self, $buffer) = @_;
    $self->_set_model( $buffer->[0] );
    $self->_set_y_num( $buffer->[1] );
};

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::MaxEnt::Model

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
