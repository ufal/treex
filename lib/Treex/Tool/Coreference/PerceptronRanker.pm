package Treex::Tool::Coreference::PerceptronRanker

use Treex::Core::Common;

has 'model_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',

    documentation => 'path to the trained model',
);

has '_model' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef[Str]',
    builder      => '_build_model',
);

sub _build_model {
    my ($self) = @_;

    # TODO if it doesn't exist?
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


sub pick_winner {
    my ($self, $instances) = @_;

    my $cand_weights = $self->rank( $instances );
    my @cands = sort {$cand_weights->{$b} <=> $cand_weights->{$a}} 
        keys %{$cand_weights};
    return $cands[0];
}

# Copyright 2008-2011 Nguy Giang Linh, Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
