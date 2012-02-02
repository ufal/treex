package Treex::Tool::Coreference::NADA;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use NADA;

has 'weights_path' => (
    is => 'ro',
    isa => 'Str',
    default => 'data/models/coreference/EN/NADA/',
    required => 1,
);
has 'ngrams_path' => (
    is => 'ro',
    isa => 'Str',
    default => 'data/models/coreference/EN/NADA/',
    required => 1,
);

has '_weights' => (
    is => 'ro',
    isa => 'Object',
    builder => '_build_weights'
);
has '_ngrams' => (
    is => 'ro', 
    isa => 'NADA::NgramCompressedCntMap',
    builder => '_build_ngrams',
);

sub BUILD {
    my ($self) = @_;
    $self->weights_path;
    $self->ngrams_path;
}

sub _build_weights {
    my ($self) = @_;
    my $weights_file = require_file_from_share( $self->weights_path, ref($self) );
    log_fatal 'File ' . $weights_file . 
        ' with a NADA model used for'.
        'anaphoricity determination does not exist.' 
        if !-f $weights_file;
    return NADA::initializeFeatureWeights($weights_file);
}
sub _build_ngrams {
    my ($self) = @_;
    my $ngrams_file = require_file_from_share( $self->ngrams_path, ref($self) );
    log_fatal 'File ' . $ngrams_file . 
        ' with ngram counts used by NADA for'.
        'anaphoricity determination  does not exist.' 
        if !-f $ngrams_file;
    my $ngrams = NADA::NgramCompressedCntMap->new(); 
    $ngrams->initialize($ngrams_file);
    return $ngrams;
}

sub process_sentence {
    my ($self, @sentence) = @_;
    
    my @positions = grep {$sentence[$_] =~ /^[Ii]t$/} (0 .. $#sentence);
    
    my $result = NADA::processSentence(\@sentence, $self->_weights, $self->_ngrams, \@positions);
    my %result_hash = map {$positions[$_] => $result->[$_]} (0 .. $#positions);
    return ($result_hash);
}

1;

# TODO POD
