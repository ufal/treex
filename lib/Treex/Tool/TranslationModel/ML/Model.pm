package Treex::Tool::TranslationModel::ML::Model;

use Moose;
use Moose::Util::TypeConstraints;

use Treex::Core::Common;
use Treex::Tool::ML::Factory;
use Treex::Tool::ML::NormalizeProb;

with 'Treex::Tool::TranslationModel::Model';

# both old and new types of submodels supported
has '+_submodels' => (
    isa => 'HashRef[Treex::Tool::ML::Classifier]',
);

has '_submodel_factory' => (
    isa => 'Treex::Tool::ML::Factory',
    is => 'ro',
    default => sub { Treex::Tool::ML::Factory->new(); }, 
);

has 'model_type' => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);

sub source {
    my ($self) = @_;
    return $self->model_type;
}

sub _get_transl_variants {
    my ($self, $submodel, $features_rf) = @_;

    if (scalar(@$features_rf) == 0) {
        $features_rf =  [ 'dummy_feat' ];
    }
    
    my @variants;
    foreach my $output_label ($submodel->all_classes) {

        my $variant = {
            label => $output_label,
            score => $submodel->score($features_rf, $output_label),
            source => $self->source,
            feat_weights => $submodel->log_feat_weights($features_rf, $output_label),
        };

        push @variants, $variant;
    }

    my @scores = map {$_->{score}} @variants;
    #log_info "SCORES: " . join " ", @scores;

    # HACK
    # add zero scores for undefined variants
    if ($submodel->isa("Treex::Tool::ML::MaxEnt::Model")) {
        my $num_to_add = $submodel->y_num - scalar(@scores);
        #print STDERR "Y_COUNT: ".scalar(@scores)."/".$submodel->y_num."\n";
        push @scores, map {0} (0 .. $num_to_add-1); 
    }
    
    my @probs = Treex::Tool::ML::NormalizeProb::logscores2probs(@scores);

    foreach my $i (0..$#variants) {
        $variants[$i]->{prob} = $probs[$i];
    }
    #log_info "CLASSES: " . scalar($submodel->all_classes);
    
    #print  STDERR "Count: " . scalar @variants . "\n";
    #my @non_zero = sort {$a->{score} <=> $b->{score}} (grep {$_->{score} > 0} @variants);
    #print Dumper(\@non_zero);
    
    return @variants;
}

sub _create_submodel {
    my ($self) = @_;
    return $self->_submodel_factory->create_classifier_model($self->model_type);
}

#sub feature_weights {
#    my ($self, $input, $output) = @_;
#
#    my @input_labels = defined $input ? $input : sort $self->get_input_labels;
#
#    foreach my $input_label (@input_labels) {
#        my $submodel = $self->_submodels->{$input_label};
#    
#        log_fatal "This method is no longer maintained and supported for old version of models"
#            if (!$submodel->isa("Treex::Tool::ML::MaxEnt::Model"));
#
#        utf8::encode($output) if (defined $output);
#        my @output_labels = defined $output ? $output : sort $submodel->all_classes;
#
#        foreach my $output_label (@output_labels) {
#            my $feat_hash = $submodel->model->{$output_label};
#            foreach my $feat_name (sort {$feat_hash->{$b} <=> $feat_hash->{$a}} keys %$feat_hash) {
#                print $input_label . "\t" . $output_label . "\t" . $feat_name . ":" . 
#                    sprintf("%.3f", $feat_hash->{$feat_name}) . "\n";
#            }
#        }
#    }
#
#    return;
#}

1;
__END__

=encoding utf-8

=head1 NAME

TranslationModel::ML::Model

=head1 DESCRIPTION

A base class for models based on any ML method.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 
Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENCE

Copyright © 2009-2013 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

