package Treex::Tool::ML::MaxEnt::Model;

use Moose;

use Treex::Core::Common;

use AI::MaxEntropy::Model;

use Storable;
use PerlIO::gzip;

with 'Treex::Tool::ML::Classifier', 'Treex::Tool::ML::Model';

has 'old_model' => (
    isa => 'AI::MaxEntropy::Model',
    is => 'ro',
);

has '+model' => (
    isa => 'HashRef[HashRef[Num]]',
);

has 'y_num' => (
    isa => 'Int',
    is => 'ro',
    builder => '_build_y_num',
    lazy => 1,
);

sub _build_y_num {
    my ($self) = @_;
    return scalar (keys %{$self->model});
}

sub score {
    my ($self, $x, $y) = @_;

    # preprocess if $x is hashref
    $x = [
        map {
        my $attr = $_;
        ref($x->{$attr}) eq 'ARRAY' ? 
            map { "$attr:$_" } @{$x->{$attr}} : "$_:$x->{$_}" 
        } keys %$x
    ] if ref($x) eq 'HASH';
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

sub load_model {
    my ($self, $filename) = @_;

    open my $fh, "<:gzip", $filename or log_fatal($!);
    my $model = Storable::retrieve_fd($fh) or log_fatal($!);
    close($fh);

    return $model;
    #return AI::MaxEntropy::Model->new($model_file);
}

sub save_model {
    my ($self, $filename) = @_;
    
    open (my $fh, ">:gzip", $filename) or log_fatal $!;
    Storable::nstore_fd($self->model, $fh) or log_fatal $!;;
    close($fh);
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
