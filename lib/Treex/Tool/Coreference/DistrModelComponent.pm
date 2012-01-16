package Treex::Tool::Coreference::DistrModelComponent;

use Moose::Role;

has 'init_weight' => (
    is          => 'ro',
    isa         => 'Num',
    required    => 1,
);

has 'feat_union_delim' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    default     => '/',
);

has '_counts' => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 1,
    default     => sub { {} },
);
has '_sums' => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 1,
    default     => sub { {} },
);

requires '_select_features';
requires '_base_distrib';

sub prob {
    my ($self, $anaph, $cand) = @_;

    my @feats = $self->_select_features($anaph, $cand);

    my $count = $self->_get_count(@feats);
    my $sum = $self->_get_sum(@feats);

    my $alpha = $self->init_weight;
    my $base_p = $self->_base_distrib(@feats);

    my $p = ($alpha * $base_p + $count) / ($alpha + $sum);

    return $p;
}

sub _get_sum {
    my ($self, @feats) = @_;
    my $delim = $self->feat_union_delim;

    my @levels = ($self->_sums);
    pop @feats;

    foreach my $feat_union (@feats) {
        my @new_levels = ();
        foreach my $level (@levels) {
            foreach my $feat (split /$delim/, $feat_union) {
                push @new_levels, $level->{$feat};
            }
        }
        @levels = @new_levels;
    }
    my $total_count = 0;
    foreach my $level (@levels) {
        $total_count += $level->{__sum__} || 0;
    }
    return $total_count;
}

sub _update_sums {
    my ($self, $value, @feats) = @_;
    my $delim = $self->feat_union_delim;

    my @feats_split = map {[split /$delim/, $_]} @feats;
    my @products = ();
    my $product = 1;
    for (my $i = @feats_split-1; $i >= 0; $i--) {
        $product *= scalar(@{$feats_split[$i]});
        unshift @products, $product;
    }
    #print STDERR Dumper(\@feats_split, \@products);

    # last feature is not needed for sums
    pop @feats_split;

    # increment overall sum
    $self->_sums->{__sum__} += $value * shift @products;
    
    my @levels = ($self->_sums);

    foreach my $feat_union (@feats_split) {
        my @new_levels = ();
        my $level_count = shift @products;
        foreach my $level (@levels) {
            foreach my $feat (@$feat_union) {
                if (!defined $level->{$feat}) {
                    $level->{$feat} = {};
                }
                push @new_levels, $level->{$feat};
                $level->{$feat}{__sum__} += $value * $level_count;
            }
        }
        @levels = @new_levels;
    }
    
    #use Data::Dumper;
    #print STDERR Dumper(\@feats, \@feats_split, \@products);
    #print STDERR Dumper($self->_sums);
    #exit;
}

sub _get_count {
    my ($self, @feats) = @_;
    my $delim = $self->feat_union_delim;

    my @levels = ($self->_counts);
    my $last_feat_union = pop @feats;

    foreach my $feat_union (@feats) {
        my @new_levels = ();
        foreach my $level (@levels) {
            foreach my $feat (split /$delim/, $feat_union) {
                push @new_levels, $level->{$feat};
            }
        }
        @levels = @new_levels;
    }
    my $total_count = 0;
    foreach my $level (@levels) {
        foreach my $last_feat (split /$delim/, $last_feat_union) {
            $total_count += $level->{$last_feat} || 0;
        }
    }
    return $total_count;
}

sub _update_counts {
    my ($self, $value, @feats) = @_;
    my $delim = $self->feat_union_delim;
    
    my @levels = ($self->_counts);
    my $last_feat_union = pop @feats;

    foreach my $feat_union (@feats) {
        my @new_levels = ();
        foreach my $level (@levels) {
            foreach my $feat (split /$delim/, $feat_union) {
                if (!defined $level->{$feat}) {
                    $level->{$feat} = {};
                }
                push @new_levels, $level->{$feat};
            }
        }
        @levels = @new_levels;
    }
    foreach my $level (@levels) {
        foreach my $last_feat (split /$delim/, $last_feat_union) {
            $level->{$last_feat} += $value;
        }
    }
}

sub increment_counts {
    my ($self, $anaph, $new_cand) = @_;

    my @feats = $self->_select_features($anaph, $new_cand);
    $self->_update_counts(1, @feats);
    $self->_update_sums(1, @feats);
}
sub decrement_counts {
    my ($self, $anaph, $old_cand) = @_;
    
    my @feats = $self->_select_features($anaph, $old_cand);
    $self->_update_counts(-1, @feats);
    $self->_update_sums(-1, @feats);
}

1;
