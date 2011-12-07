package Treex::Tool::ML::LinearRegression::Model;

use Moose;
use Treex::Tool::ML::LinearRegression::Util;
use YAML::Syck;

has 'model_path'    => (is => 'ro', isa => 'Str');
has 'lambda'        => (is => 'rw', isa => 'ArrayRef[Num]');
has 'means'         => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'ranges'        => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'poly_degree'   => (is => 'rw', isa => 'Int', default => 1);

sub BUILD {
    my ($self) = @_;

    if (defined $self->model_path) {
        $self->load( $self->model_path );
    }
}

sub load {
    my ($self, $file) = @_;
    my $model = LoadFile($file);
    #use Data::Dumper;
    #print STDERR Dumper($model->[0]);
    $self->lambda($model->[0]);
    $self->means($model->[1]); 
    $self->ranges($model->[2]); 
    $self->poly_degree($model->[3]); 
}

sub save {
    my ($self, $file) = @_;
    my $data = [
        $self->lambda,
        $self->means,
        $self->ranges,
        $self->poly_degree,
    ];
    DumpFile($file, $data);    
}

sub predict {
    my ($self, $x) = @_;
    
    # preprocess if $x is hashref
    $x = [
        map { $x->{$_} } (sort (keys %$x))
    ] if ref($x) eq 'HASH';


    my $means = $self->means;
    my $ranges = $self->ranges;
    
    my $x_poly = Treex::Tool::ML::LinearRegression::Util->extract_polyn_feats(
        $x, $self->poly_degree
    );
    my $x_norm = Treex::Tool::ML::LinearRegression::Util->normalize(
        $x_poly, $self->means, $self->ranges
    );

    my $lambdas = $self->lambda;

    # calculate score
    my $lambda_f = $lambdas->[0];
    for (my $i = 1; $i < @$lambdas; $i++) {
        if (defined $x_norm->[$i-1]) {
            $lambda_f += $lambdas->[$i] * $x_norm->[$i-1];
        }
    }
    return $lambda_f; 
}

1;
