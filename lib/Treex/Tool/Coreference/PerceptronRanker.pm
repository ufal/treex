package Treex::Tool::Coreference::PerceptronRanker

use Treex::Core::Common;
use Treex::Core::Resource;

with 'Treex::Tool::Coreference::Ranker';

has '_model' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef[Str]',
    builder      => '_build_model',
);

sub _build_model {
    my ($self) = @_;

    Treex::Core::Resource::require_file_from_share($self->model_path, ref($self));
    log_fatal 'File ' . $self->model_path . 
        ' with a model for pronominal textual coreference resolution does not exist.' 
        if !-f $self->model_path;
    open MODEL, $self->model_path;

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
                $value = $cat_feats[1];
            }
            
            $perc_weights->{$fname}{$value} = $weight;
        }
    }
    
    return $perc_weights;
}

sub rank {
    my ($self, $instances) = @_;

    my $cand_weights;

    foreach my $id (keys %{$instances}) {
        my $instance = $instances->{$id};
        my $cand_weight = 0;
        for my $fname (keys %{$instance}) {
            my $feat_weight;
            if ($fname =~ /^(r|b)_/) {
                my $fvalue = $instance->{$fname};
                $feat_weight = $fvalue * $self->_model->{$fname}{'weight'};
            }
            else {
                #my $fvalue = special_chars_off2($pfeatures->{$fname});
                my $fvalue = $pfeatures->{$fname};
                $feat_weight = $p_perc_weights->{$fname}{$fvalue};
            }
            $cand_weight += $feat_weight;
        }
        $cand_weights->{$id} = $cand_weight;
    }
    return $cand_weights;
}


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
