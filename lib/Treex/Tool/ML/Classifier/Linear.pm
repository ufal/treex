package Treex::Tool::ML::Classifier::Linear;

use Moose;

use Treex::Core::Common;

use Storable;
use PerlIO::gzip;

with 'Treex::Tool::ML::Classifier', 'Treex::Tool::Storage::Storable';

has 'model' => (
    is          => 'ro',
    isa => 'HashRef[HashRef[Num]]',
    writer => '_set_model',
);

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
            my $weight = $model_for_y->{$feat} || 0;
            $lambda_f += $weight;
            #print STDERR "CLASS: $y\tFEAT:$feat\tWEIGHT:$weight\n";
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
            my $weight = $model_for_y->{$feat} || 0;
            $feat_weights{$feat} += $weight;
            #print STDERR "CLASS: $y\tFEAT:$feat\tWEIGHT:$weight\n";
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

############# implementing Treex::Tool::Storage::Storable role #################

before 'save' => sub {
    my ($self, $filename) = @_;
    log_info "Storing linear model into $filename...";
};

before 'load' => sub {
    my ($self, $filename) = @_;
    log_info "Loading linear model from $filename...";
};

sub freeze {
    my ($self) = @_;
    return $self->model;
}

sub thaw {
    my ($self, $buffer) = @_;
    $self->_set_model( $buffer );
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

sub dump {
    my ($self, $sort_by_weights) = @_;

    foreach my $class (sort $self->all_classes) {
        
        print STDOUT "$class\n";
        
        my $feat_hash = $self->model->{$class};
        my @sorted_feats = $sort_by_weights 
            ? sort {$feat_hash->{$b} <=> $feat_hash->{$a}} keys %$feat_hash
            : sort keys %$feat_hash;
        foreach my $feat (@sorted_feats) {
            print STDOUT "\t$feat = " . $feat_hash->{$feat} . "\n";
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::Classifier::Linear

=head1 DESCRIPTION

A model for linear classifiers. Score for a given feature vector
and a class is calculated as a dot product of the feature vector
and the corresponding vector of weights.

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
