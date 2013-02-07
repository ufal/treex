package Treex::Tool::ML::MaxEnt::Learner;

use Moose;
use AI::MaxEntropy;
use Treex::Tool::ML::MaxEnt::Model;

use Data::Dumper;

with 'Treex::Tool::ML::Learner';

has 'smooth_type' => (
    isa => 'Str',
    is => 'ro',
    default => 'gaussian',
);
has 'smooth_sigma' => (
    isa => 'Num',
    is => 'ro',
    default => 0.99,
);

has '_ai_learner' => (
    isa => 'AI::MaxEntropy',
    is => 'ro',
    builder => '_build_ai_learner',
    lazy => 1,
);

sub BUILD {
    my ($self) = @_;
    $self->_ai_learner;
}

sub _build_ai_learner {
    my ($self) = @_;
    my $ai_params = {
        smoother => { type => $self->smooth_type, sigma => $self->smooth_sigma },
    };
    return AI::MaxEntropy->new(%$ai_params);
}

sub see {
    my $self = shift;
    $self->_ai_learner->see(@_);
}

sub learn {
    my $self = shift;
    my $ai_model = $self->_ai_learner->learn(@_);
    my $compact_hash = $self->_make_compact_hash($ai_model);
    return Treex::Tool::ML::MaxEnt::Model->new($compact_hash);
}

sub cut_features {
    my $self = shift;
    $self->_ai_learner->cut(@_);
}

sub forget_all {
    my $self = shift;
    $self->_ai_learner->forget_all(@_);
}

sub _make_compact_hash {
    my ($self, $ai_model) = @_;

    my $probs = {};
    for my $y (0 .. @{$ai_model->{y_list}}-1) {
        for my $x (0 .. @{$ai_model->{x_list}}-1) {
            my $idx = $ai_model->{f_map}->[$y]->[$x];
            if ($idx > -1) {
                $probs->{$ai_model->{y_list}->[$y]}->{$ai_model->{x_list}->[$x]} = $ai_model->{lambda}->[$idx];
            }
        }
    }

    my $compact_hash = {
        model => $probs,
        y_num => $ai_model->{y_num},
    };

    return $compact_hash;
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
