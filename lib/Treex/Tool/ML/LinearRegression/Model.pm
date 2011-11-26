package Treex::Tool::ML::LinearRegression::Model;

use Moose;
use YAML::Syck;

has 'model_path'    => (is => 'ro', isa => 'Str', required => 1);
has 'lambda'        => (is => 'rw', isa => 'ArrayRef[Num]');
has 'means'         => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });
has 'ranges'        => (is => 'rw', isa => 'ArrayRef[Num]', default => sub { [] });

sub BUILD {
    my ($self) = @_;

    $self->load( $self->model_path );
}

sub load {
    my ($self, $file) = @_;
    my $model = LoadFile($file);
    use Data::Dumper;
    print STDERR Dumper($model->[0]);
    $self->lambda($model->[0]);
    $self->means($model->[1]); 
    $self->ranges($model->[2]); 
}

sub save {
    my ($self, $file) = @_;
    my $data = [
        $self->lambda,
        $self->means,
        $self->ranges,
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
    my @x_normed = map {($x->[$_] - $means->[$_]) / $ranges->[$_]} (0 .. @$x-1);

    my $lambdas = $self->lambda;

    # calculate score
    my $lambda_f = $lambdas->[0];
    for (my $i = 1; $i < @$lambdas; $i++) {
        if (defined $x_normed[$i]) {
            $lambda_f += $lambdas->[$i] * $x_normed[$i];
        }
    }
    return $lambda_f; 
}

1;
