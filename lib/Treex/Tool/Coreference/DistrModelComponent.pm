package Treex::Tool::Coreference::DistrModelComponent;

use Moose::Role;

has 'init_weight' => (
    is          => 'ro',
    isa         => 'Num',
    required    => 1,
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

    my $level = $self->_sums;
    pop @feats;

    foreach my $feat (@feats) {
        if (!defined $feat) {
            print STDERR ref($self) . "\n";
        }
        $level = $level->{$feat};
    }
    return $level->{__sum__} || 0;
}

sub _update_sums {
    my ($self, $value, @feats) = @_;
    
    # last feature is not needed for sums
    pop @feats;

    my $level = $self->_sums;

    # increment overall sum
    $level->{__sum__} += $value;

    foreach my $feat (@feats) {
        if (!defined $level->{$feat}) {
            $level->{$feat} = {};
        }
        my $level = $level->{$feat};
        $level->{__sum__} += $value;
    }
}

sub _get_count {
    my ($self, @feats) = @_;

    my $level = $self->_counts;
    my $last_feat = pop @feats;

    foreach my $feat (@feats) {
        $level = $level->{$feat};
    }
    return $level->{$last_feat} || 0;
}

sub _update_counts {
    my ($self, $value, @feats) = @_;
    
    my $level = $self->_counts;
    my $last_feat = pop @feats;

    foreach my $feat (@feats) {
        if (!defined $level->{$feat}) {
            $level->{$feat} = {};
        }
        $level = $level->{$feat};
    }
    $level->{$last_feat} += $value;
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
