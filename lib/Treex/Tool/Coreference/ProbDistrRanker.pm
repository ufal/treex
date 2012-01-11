package Treex::Tool::Coreference::ProbDistrRanker;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use Treex::Tool::Coreference::ValueTransformer;
use Treex::Tool::Coreference::CombinedDistrModel;

with 'Treex::Tool::Coreference::Ranker';

has 'model_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',

    documentation => 'path to the trained model',
);

# TODO this should be a separate class and a feature transformer should be a part of it
has '_model' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::CombinedDistrModel',
    lazy        => 1,
    builder      => '_build_model',
);

has '_feature_transformer' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::ValueTransformer',
    default     => sub{ Treex::Tool::Coreference::ValueTransformer->new },
);

# Attribute _model depends on the attribute model_path, whose value do not
# have to be accessible when building other attributes. Thus, _model is
# defined as lazy, i.e. it is built during its first access. However, we wish all
# models to be loaded while initializing a block. Following hack ensures it.
sub BUILD {
    my ($self) = @_;

    $self->_model;
}

sub _build_model {
    my ($self) = @_;

    my $model_file = require_file_from_share($self->model_path, ref($self));
    log_fatal 'File ' . $model_file . 
        ' with a model for pronominal textual coreference resolution does not exist.' 
        if !-f $model_file;
    my $model = Treex::Tool::Coreference::CombinedDistrModel->new();
    $model->load( $model_file );
    return $model;
}

sub _transform_values {
    my ($self, $instances) = @_;

    my $ft = $self->_feature_transformer;
    
    my $anaph = $instances->{'anaph'};
    my $cands = $instances->{'cands'};
    foreach my $key (keys %$anaph) {
        $anaph->{$key} = $ft->special_chars_off($anaph->{$key});
    }
    foreach my $cand_id (keys %$cands) {
        foreach my $key (keys %{$cands->{$cand_id}}) {
            $cands->{$cand_id}{$key} = $ft->special_chars_off($cands->{$cand_id}{$key});
        }
    }
}

sub rank {
    my ($self, $instances) = @_;

    my $model = $self->_model;
    
    $self->_transform_values($instances);
    my $anaph = $instances->{'anaph'};
    my $cands = $instances->{'cands'};

    my %scores = map {$_ => $model->logprob($anaph, $cands->{$_})} (keys %$cands);

    return \%scores;
}

1;


__END__

=head1 NAME

Treex::Tool::Coreference::ProbDistrRanker

=head1 DESCRIPTION

A ranker based on a combined model of probability distribution.

=head1 METHODS

=over

=item C<rank>

Calculates scores of candidates based on the combined distribution model.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
