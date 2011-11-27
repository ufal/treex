package Treex::Tool::ML::LinearRegression;

use Moose;
use Algorithm::LBFGS;
use Treex::Tool::ML::LinearRegression::Model;
use Treex::Tool::ML::LinearRegression::Util;

has 'algorithm'             => (is => 'ro', isa => 'HashRef');
has 'poly_degree'           => (is => 'ro', isa => 'Int', default => 1);
has 'regul_param'           => (is => 'ro', isa => 'Num', default => 0);
has 'samples_x'             => (is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub { [] });
has 'samples_y'             => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'means'                 => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'ranges'                => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'samples_normed'        => (is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub { [] });
has 'lambda'                => (is => 'rw', isa => 'ArrayRef[Num]');
has '_x_num'                => (is => 'rw', isa => 'Int', default => 0);

sub _add_sample {
    my ($self, $x, $y) = @_;
    
    push @{$self->samples_x}, $x;
    push @{$self->samples_y}, $y;
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

    my $m = @{$data->samples_x};

    # calculate cost function
    my $cost = 0;
    my @grad = map {0} (0 .. @$lambdas-1);


    for (my $i = 0; $i < $m; $i++) {
        my $x = $data->samples_x->[$i];
        my $y = $data->samples_y->[$i];
         
        # intercept
        my $y_estim = $lambdas->[0];
        for (my $j = 1; $j < @$lambdas; $j++) {
            $y_estim += $x->[$j-1] * $lambdas->[$j];
        }        
        
        my $resid = $y_estim - $y;

        $grad[0] += $resid;
        for (my $j = 1; $j < @grad; $j++) {
            $grad[$j] += $resid * $x->[$j-1];
        }

        $cost += $resid ** 2;
    }
    
    # finish cost function
    $cost /= 2 * $m;
    # regularization
    my $regul = 0;
    for (my $j = 1; $j < @$lambdas; $j++) {
        $regul += $lambdas->[$j] ** 2;
    }
    $cost += $data->regul_param * $regul;

    # finish gradients
    for (my $j = 0; $j < @grad; $j++) {
        $grad[$j] /= $m;
        
        # regularization
        if ($j > 0) {
            $grad[$j] -= $lambdas->[$j] * $data->regul_param / $m;
        }
    }
    
    #use Data::Dumper;
    #print STDERR Dumper($cost, \@grad, $lambdas);
    return ($cost, \@grad);
}

sub add_polynom_features {
    my ($self, $samples_x, $k) = @_;

    my @samples_x_poly = ();
    my $feat_count;

    foreach my $x (@$samples_x) {
        my $x_poly = Treex::Tool::ML::LinearRegression::Util->extract_polyn_feats( $x, $k );
        push @samples_x_poly, $x_poly;
        if (!defined $feat_count) {
            $feat_count = scalar @$x_poly;
        }
    }
    return (\@samples_x_poly, $feat_count);
}

sub normalize_features {
    my ($self, $samples_x) = @_;

    my @sums = map { 0 } (1 .. $self->_x_num);
    my @maxs = map { undef } (1 .. $self->_x_num);
    my @mins = map { undef } (1 .. $self->_x_num);

    foreach my $x (@$samples_x) {
        for (my $i = 0; $i < @$x; $i++) {
            $sums[$i] += $x->[$i];
            $maxs[$i] = $x->[$i] if (!defined $maxs[$i] || ($maxs[$i] < $x->[$i]));
            $mins[$i] = $x->[$i] if (!defined $mins[$i] || ($mins[$i] > $x->[$i]));
        }
    }
    
    my @means = map {$_ / @{$samples_x}} @sums;
    my @ranges = map {$maxs[$_] - $mins[$_]} (0 .. @mins-1);

    my @samples_x_normed = ();
    foreach my $x (@{$samples_x}) {
        my $x_norm = Treex::Tool::ML::LinearRegression::Util->normalize( $x, \@means, \@ranges ); 
        push @samples_x_normed, $x_norm;
    }

    return (\@samples_x_normed, \@means, \@ranges);
}

sub learn {
    my $self = shift;

    my $samples_x = $self->samples_x;
    my ($samples_x_poly, $feat_count) 
        = $self->add_polynom_features( $samples_x, $self->poly_degree );
    my ($samples_x_norm, $means, $ranges) 
        = $self->normalize_features( $samples_x_poly );

    $self->means( $means );
    $self->ranges( $ranges );
    $self->samples_x( $samples_x_norm );
    $self->_x_num( $feat_count );
    
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
    my $model = Treex::Tool::ML::LinearRegression::Model->new;
    $model->lambda($self->lambda);
    $model->means($self->means);
    $model->ranges($self->ranges);
    $model->poly_degree($self->poly_degree);
    return $model;
}

1;
