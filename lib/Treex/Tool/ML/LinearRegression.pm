package Treex::Tool::ML::LinearRegression;

use Moose;
use Algorithm::LBFGS;
use AI::LinearRegression::Model;

has 'algorithm'             => (is => 'ro', isa => 'HashRef');
has 'samples'               => (is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub { [] });
has 'means'                 => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'ranges'                => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'samples_normed'        => (is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub { [] });
has 'lambda'                => (is => 'rw', isa => 'ArrayRef[Num]');
has '_x_num'                => (is => 'rw', isa => 'Int', default => 0);

sub _add_sample {
    my ($self, $x, $y) = @_;
    
    push @{$self->samples}, [ $x, $y ];
}

sub see {
    my ($self, $x, $y) = @_;
    
    # preprocess if $x is hashref
    $x = [
        map { $x->{$_} } (sort (keys %$x))
    ] if ref($x) eq 'HASH';
    
    # update af_num
    $self->_x_num(scalar @$x) if ($self->_x_num == 0);
    die "Instances must have the same number of features, which is " . $self->_x_num . "\n" if ($self->_x_num != @$x);
    
    # add the sample
    $self->_add_sample($x, $y);
}

sub _cost_function {
    my ($lambdas, $step, $data) = @_;

    # calculate cost function
    my $cost = 0;
    my @grad = map {0} (0 .. @$lambdas-1);


    foreach my $sample (@{$data->samples_normed}) {
        my $x = $sample->[0];
        my $y = $sample->[1];
         
        # intercept
        my $y_estim = $lambdas->[0];
        for (my $i = 1; $i < @$lambdas; $i++) {
            $y_estim += $x->[$i-1] * $lambdas->[$i];
        }        
        
        my $resid = $y_estim - $y;

        $grad[0] += $resid;
        for (my $j = 1; $j < @grad; $j++) {
            $grad[$j] += $resid * $x->[$j-1];
        }

        $cost += $resid ** 2;
    }
    $cost /= 2 * @{$data->samples_normed};

    for (my $j = 0; $j < @grad; $j++) {
        $grad[$j] /= @{$data->samples_normed};
    }
    
    use Data::Dumper;
    print STDERR Dumper($cost, \@grad, $lambdas);
    return ($cost, \@grad);
}

sub normalize_features {
    my ($self) = @_;

    my @sums = map { 0 } (1 .. $self->_x_num);
    my @maxs = map { undef } (1 .. $self->_x_num);
    my @mins = map { undef } (1 .. $self->_x_num);

    foreach my $sample (@{$self->samples}) {
        my $x = $sample->[0];
        for (my $i = 0; $i < @$x; $i++) {
            $sums[$i] += $x->[$i];
            $maxs[$i] = $x->[$i] if (!defined $maxs[$i] || ($maxs[$i] < $x->[$i]));
            $mins[$i] = $x->[$i] if (!defined $mins[$i] || ($mins[$i] > $x->[$i]));
        }
    }
    
    my @means = map {$_ / @{$self->samples}} @sums;
    my @ranges = map {$maxs[$_] - $mins[$_]} (0 .. @mins-1);

    $self->means(\@means);
    $self->ranges(\@ranges);

    foreach my $sample (@{$self->samples}) {
        my $x = $sample->[0];
        my $y = $sample->[1];
        
        my @new_x = map {($x->[$_] - $means[$_]) / $ranges[$_]} (0 .. @$x-1);
        
        push @{$self->samples_normed}, [ \@new_x, $y ];
    }
}

sub learn {
    my $self = shift;

    $self->normalize_features;
    
    # initialize
    my $lambda = [map { 0 } (0 .. $self->_x_num)];
    
    # optimize
    my $o = Algorithm::LBFGS->new(%{$self->algorithm});
    $lambda = $o->fmin(\&_cost_function, $lambda,
        $self->algorithm->{progress_cb}, $self);
    use Data::Dumper;
    print STDERR Dumper($lambda);
    
    $self->lambda($lambda);
    return $self->_create_model;
}

sub _create_model {
    my $self = shift;
    my $model = AI::LinearRegression::Model->new;
    $model->lambda($self->lambda);
    $model->means($self->means);
    $model->ranges($self->ranges);
    return $model;
}

1;
