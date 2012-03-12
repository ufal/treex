package Treex::Tool::Coreference::PerceptronRanker;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use Treex::Tool::Coreference::ValueTransformer;

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
    isa         => 'HashRef[HashRef[Num]]',
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
    open MODEL, "<:gzip:utf8", $model_file;

# DEBUG
#    print STDERR "FILE: $model_file\n";

    my $perc_weights;
    my $start = 0;
    while (my $line = <MODEL>) {
        chomp $line;

        if ($line =~ /^START/) {
            $start = 1;
        }
        elsif ($start) {
            my @vals = split /,/, $line;
            
            my $weight = $vals[0];
            my ($fname, $value);
            if ($vals[1] =~ /^r_/) {
                $fname = substr($vals[1], 2);          
                $value = 'weight';
            }
            elsif ($vals[1] =~ /^c_/) {
                my @cat_feats = split /§/, $vals[1];
                $fname = substr($cat_feats[0], 2);
                $value = $cat_feats[1] || "";
            }
            
            if (!defined $value) {
                print STDERR $fname."\n";
            }
            $perc_weights->{$fname}{$value} = $weight;
        }
    }

    return $perc_weights;
}

sub rank {
    my ($self, $instances) = @_;

# DEBUG
#    my ($self, $instances, $debug) = @_;

    my $cand_weights;

    foreach my $id (keys %{$instances}) {
        my $instance = $instances->{$id};
        my $cand_weight = 0;
        for my $fname (keys %{$instance}) {
            my $feat_weight;
            my $fvalue;
            if ($fname =~ /^(r|b)_/) {
                $fvalue = $instance->{$fname};
                if (defined $fvalue) {
                    $feat_weight = $fvalue * 
                        ($self->_model->{$fname}{'weight'} || 0);
                } else {
                    $feat_weight = 0;
                }
            }
            else {
                $fvalue = $instance->{$fname};
                $fvalue = $self->_feature_transformer->special_chars_off($fvalue);
                if (defined $fvalue) {
                    $feat_weight = ( $self->_model->{$fname}{$fvalue} || 0 );
                } else {
                    $feat_weight = 0;
                }
            }
            $cand_weight += $feat_weight;

# DEBUG
#if ($debug && ($id eq 't_tree-cs_src-s15-n1119')) {
#    print "$fname = $fvalue : $feat_weight\n"
#}
        }
        $cand_weights->{$id} = $cand_weight;
    }
    return $cand_weights;
}

1;


__END__

=head1 NAME

Treex::Tool::Coreference::PerceptronRanker

=head1 DESCRIPTION

A perceptron ranker.

=head1 METHODS

=over

=item C<rank>

Calculates scores of candidates based on the model created by ranking
perceptron learning algorithm.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENCE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
