package Treex::Tool::Coreference::CombinedDistrModel;

use Moose;
use Treex::Tool::Coreference::DistrModelComponent;
use Treex::Tool::Coreference::DistrModelComponent::Gender;
use Treex::Tool::Coreference::DistrModelComponent::Number;
use Treex::Tool::Coreference::DistrModelComponent::SentDist;
use Treex::Tool::Coreference::DistrModelComponent::ParentLemma;

use List::Util qw/sum/;
use Data::Dumper;
use Storable qw/nstore retrieve/;

has 'components' => (
    is          => 'rw',
    isa         => 'ArrayRef[Treex::Tool::Coreference::DistrModelComponent]',
);

sub logprob {
    my ($self, $anaph, $cand) = @_;
    
    my @probs = map {$_->prob($anaph, $cand)} 
        @{$self->components};
    my @logprobs = map {log($_)} @probs;
    return sum(@logprobs);
}

sub decrement_counts {
    my ($self, $anaph, $old_cand, $new_cand) = @_;

    foreach my $submodel (@{$self->components}) {
        $submodel->decrement_counts($anaph, $old_cand);
    }
}

sub increment_counts {
    my ($self, $anaph, $new_cand) = @_;
    
    foreach my $submodel (@{$self->components}) {
        $submodel->increment_counts($anaph, $new_cand);
    }
}

sub save {
    my ($self, $path) = @_;

    #open my $fh, ">:utf8", $path;
    #print $fh Dumper($self->components);
    #close $fh;
    nstore($self->components, $path);
}

sub load {
    my ($self, $path) = @_;

    die "File $path does not exist" if (!-e $path);

    #open FILE, "<:utf8", $path;
    #my $code = join "\n", <FILE>;
    #my $components = eval $code;
    #print STDERR $components;
    #print STDERR "\n";
    
    my $components = retrieve($path);
    #print STDERR Dumper($components);
    $self->components( $components );
    #close FILE;
}

1;
