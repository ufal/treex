#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 4;

use Treex::Tool::ML::LinearRegression;
use Treex::Tool::ML::LinearRegression::Model;

srand(1986);

# parameters
my $epsilon = 0.0000000000001;
my $regul_param = 0;

# number of instances
my $m_train = 1000;
my $m_test = 10;

# params for random values
my $RAND_MIN = -1000;
my $RAND_MAX = 1000;

sub train_test {
    my ($f, $n, $poly_degree) = @_;
    
    ################# initialize linear regression module #################
    my $lr = Treex::Tool::ML::LinearRegression->new(
        algorithm => {
            progress_cb => 'verbose',
            epsilon => $epsilon
        },
        poly_degree => $poly_degree,
        regul_param => $regul_param,
    );
    isa_ok( $lr, 'Treex::Tool::ML::LinearRegression', 'cluster instantiated' );

    ################## train a lr model ##############################

    my @x_train = map { { map { ("x$_") => _rand() } (1 .. $n) } } (1 .. $m_train);

    foreach my $instance (@x_train) {
        my @values = map {  $instance->{"x$_"} } (1 .. $n);
        my $y = &$f(@values);
        $lr->see( $instance => $y );
    }

    my $model = $lr->learn();

    ################## test and eval the model ######################

    my @x_test = map { { map { ("x$_") => _rand() } (1 .. $n) } } (1 .. $m_test);
    my @y_test_pred = map {$model->predict($_)} @x_test;

    my $error_rate = 0;

    for (my $i = 0; $i < @y_test_pred; $i++) {
        my @values = map {  $x_test[$i]->{"x$_"} } (1 .. $n);
        my $y = &$f(@values);
        my $y_pred = $y_test_pred[$i];
        $error_rate += ($y_pred - $y) ** 2;
    }
    $error_rate /= (2 * @y_test_pred);
    
    return $error_rate;
}

sub _rand {
    return int(rand($RAND_MAX - $RAND_MIN) + $RAND_MIN + 1);
}

my $error_rate = 0;

my $f1 = sub { 4 + 5*$_[0] };
$error_rate = train_test($f1, 1, 2);
ok($error_rate < 0.001, 'prediction of a linear function');

$f1 = sub { 41 - 2*($_[0]**2) + 7*$_[0]*$_[1] - $_[1]**3 };
$error_rate = train_test($f1, 2, 3);
ok($error_rate < 0.001, 'prediction of a polynomial function');
