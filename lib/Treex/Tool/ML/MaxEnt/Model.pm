package Treex::Tool::ML::MaxEnt::Model;

use Moose;

use Treex::Core::Common;

use AI::MaxEntropy::Model;

use Storable;
use PerlIO::gzip;

with 'Treex::Tool::ML::Classifier', 'Treex::Tool::Storage::Storable';

has 'old_model' => (
    isa => 'AI::MaxEntropy::Model',
    is => 'ro',
);

has 'model' => (
    is          => 'ro',
    isa => 'HashRef[HashRef[Num]]',
    writer => '_set_model',
);

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

# preprocess if $x is hashref
sub _to_array {
    my ($x) = @_;
    
    return [
        map {
        my $attr = $_;
        ref($x->{$attr}) eq 'ARRAY' ? 
            map { "$attr:$_" } @{$x->{$attr}} : "$_:$x->{$_}" 
        } keys %$x
    ] if ref($x) eq 'HASH';
    return $x;
}

sub score {
    my ($self, $x, $y) = @_;

    $x = _to_array($x);

    # calculate score
    
    my $lambda_f = 0;
    my $model_for_y = $self->model->{$y};
    if (defined $model_for_y) {
        foreach my $feat (@$x) {
            $lambda_f += $model_for_y->{$feat} || 0;
        }
    }
    return $lambda_f; 
}

sub log_feat_weights {
    my ($self, $x, $y) = @_;
    
    $x = _to_array($x);
        
    my %feat_weights;
    my $model_for_y = $self->model->{$y};
    if (defined $model_for_y) {
        foreach my $feat (@$x) {
            $feat_weights{$feat} += $model_for_y->{$feat} || 0;
        }
    }
    my @sorted = map {$_ . "=" . $feat_weights{$_}} 
        (sort {$feat_weights{$b} <=> $feat_weights{$a}} keys %feat_weights);
    return \@sorted; 
}

sub all_classes {
    my ($self) = @_;
    return keys %{$self->model};
}

# in order to be used instead of AI::MaxEntropy::Model
sub all_labels {
    my ($self) = @_;
    return $self->all_classes;
}

sub _make_compact_hash {
    my ($self, $old_model) = @_;

    my $probs = {};
    for my $y (0 .. @{$old_model->{y_list}}-1) {
        for my $x (0 .. @{$old_model->{x_list}}-1) {
            my $idx = $old_model->{f_map}->[$y]->[$x];
            if ($idx > -1) {
                $probs->{$old_model->{y_list}->[$y]}->{$old_model->{x_list}->[$x]} = $old_model->{lambda}->[$idx];
            }
        }
    }
    return $probs;
}

sub create_model {
    my ($self) = @_;
    return undef if (!defined $self->old_model);
    return $self->_make_compact_hash( $self->old_model );
}

############# implementing Treex::Tool::Storage::Storable role #################

before 'save' => sub {
    my ($self, $filename) = @_;
    log_info "Storing MaxEnt model into $filename...";
};

before 'load' => sub {
    my ($self, $filename) = @_;
    log_info "Loading MaxEnt model from $filename...";
};

sub freeze {
    my ($self) = @_;
    return [ $self->model, $self->y_num ];
}

sub thaw {
    my ($self, $buffer) = @_;
    $self->_set_model( $buffer->[0] );
    $self->_set_y_num( $buffer->[1] );
}

#############################################################################

sub cut_weights {
    my ($self, $threshold) = @_;

    foreach my $class ($self->all_classes) {
        my $feat_hash = $self->model->{$class};
        foreach my $feat (keys %$feat_hash) {
            if (abs($feat_hash->{$feat}) < $threshold) {
                delete $feat_hash->{$feat};
            }
        }
    }
}

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
