package Treex::Block::Print::CorefSegmentsData;

use Moose;
use Treex::Core::Common;

use AI::MaxEntropy;
use Treex::Tool::Coreference::CS::CorefSegmentsFeatures;

extends 'Treex::Core::Block';

has 'y_feat_name' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 'class',
);

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    lazy        => 1,
    builder     => '_build_feature_names',
);

has '_feature_extractor' => (
    is          => 'ro',
    required    => 1,
# TODO this should be a role, not a concrete class
    lazy        => 1,
    isa         => 'Treex::Tool::Coreference::CorefSegmentsFeatures',
    builder     => '_build_feature_extractor',
);


sub BUILD {
    my ($self) = @_;

    $self->feature_names;
}

sub _build_feature_names {
    my ($self) = @_;
    
    my $names = $self->_feature_extractor->feature_names;
    return $names;
}

sub _build_feature_extractor {
    my ($self) = @_;

    my $fe = Treex::Tool::Coreference::CS::CorefSegmentsFeatures->new();
    return $fe;
}

sub _get_class {
    my ($self, $value) = @_;
    
    if (!defined $value) {
        return undef;
    }

    my $clusters = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20 ];

    my $classes = {
        0       =>  '0',
        1       =>  '1',
        2       =>  '2',                                                                          
        3       =>  '3',
        4       =>  '4',
        5       =>  '5',                                                                          
        6       =>  '6',                                                                          
        7       =>  '7',                                                                          
        8       =>  '8',                                                                          
        9       =>  '9',                                                                          
        10       =>  '10',                                                                          
        11       =>  '12',                                                                          
        12       =>  '14',                                                                          
        13       =>  '16',                                                                          
        14       =>  '18',                                                                          
        15       =>  '20',                                                                          
    };
    
    my $index = scalar( grep {$value >= $_} @$clusters );
    return $classes->{$index};
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    my $fe = $self->_feature_extractor;

    $fe->init_doc_features( $doc, $self->language, $self->selector );

    # print header
    # print join "\t", ($self->y_feat_name, @{$self->feature_names});
    # print "\n";
};

sub process_ttree{
    my ( $self, $tree ) = @_;

    my $instance = $self->_feature_extractor->extract_features( $tree );

    my $bundle = $tree->get_bundle;
    my $y_value = $self->_get_class( $bundle->wild->{true_interlinks} );

    # print the instance
    print join "\t", ($y_value, map {$instance->{$_}} @{$self->feature_names});
    print "\n";

    #print STDERR Dumper($instance, $y_value);
}


1;
