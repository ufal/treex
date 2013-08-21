package Treex::Tool::Coreference::NADA;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use Treex::External::NADA;

has 'weights_path' => (
    is => 'ro',
    isa => 'Str',
    default => 'data/models/coreference/EN/NADA/featureWeights.dat',
    required => 1,
);
has 'ngrams_path' => (
    is => 'ro',
    isa => 'Str',
    default => 'data/models/coreference/EN/NADA/ngrams',
    required => 1,
);

has '_weights' => (
    is => 'ro',
    isa => 'Object',
    builder => '_build_weights',
    lazy => 1,
);
has '_ngrams' => (
    is => 'ro', 
    isa => 'Treex::External::NADA::NgramCompressedCntMap',
    builder => '_build_ngrams',
    lazy => 1,
);

sub BUILD {
    my ($self) = @_;
    $self->_weights;
    $self->_ngrams;
}

sub _build_weights {
    my ($self) = @_;
    my $weights_file = require_file_from_share( $self->weights_path, ref($self) );
    log_fatal 'File ' . $weights_file . 
        ' with a NADA model used for'.
        ' anaphoricity determination does not exist.' 
        if !-f $weights_file;
    return Treex::External::NADA::initializeFeatureWeights($weights_file);
}
sub _build_ngrams {
    my ($self) = @_;
    my $ngrams_file = require_file_from_share( $self->ngrams_path, ref($self) );
    log_fatal 'File ' . $ngrams_file . 
        ' with ngram counts used by NADA for'.
        'anaphoricity determination  does not exist.' 
        if !-f $ngrams_file;
    my $ngrams = Treex::External::NADA::NgramCompressedCntMap->new(); 
    $ngrams->initialize($ngrams_file);
    return $ngrams;
}

sub process_sentence {
    my ($self, @sentence) = @_;
    
    my @positions = grep {$sentence[$_] =~ /^[Ii]t$/} (0 .. $#sentence);
    
    my $result = Treex::External::NADA::processSentence(\@sentence, $self->_weights, $self->_ngrams, \@positions);
    my %result_hash = map {$positions[$_] => $result->[$_]} (0 .. $#positions);
    return \%result_hash;
}

1;

# TODO POD
