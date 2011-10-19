package Treex::Tool::Coreference::AnteCandsGetter;

use Moose::Role;

requires '_select_all_cands';
requires '_find_positive_cands';

has 'anaphor_as_candidate' => (
    isa => 'Bool',
    is  => 'ro',
    required => 1,
    default => 0,
);

sub get_candidates {
    my ($self, $anaph) = @_;

    my $cands = $self->_select_all_cands($anaph);
    if ($self->anaphor_as_candidate) {
        unshift @$cands, $anaph;
    }
    return $cands;
}

sub get_pos_neg_candidates {
    my ($self, $anaph) = @_;

    my $cands  = $self->_select_all_cands($anaph);
    my $antecs = $self->_get_antecedents($anaph);
    return $self->_split_pos_neg_cands($anaph, $cands, $antecs);
}

sub _get_antecedents {
    my ($self, $anaph) = @_;

    my $antecs = [];
    my @antes = $anaph->get_coref_chain;
    my @membs = map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ?
                        $_->children : () } @antes;
    return [ @antes, @membs ];
}

# This method splits all candidates to positive and negative ones
# It returns two hashmaps of candidates indexed by their order within all
# returned candidates.
sub _split_pos_neg_cands {
    my ($self, $anaph, $cands, $antecs) = @_;

    my %ante_hash = map {$_->id => $_} @$antecs;
    
    my $pos_cands = $self->_find_positive_cands($anaph, $cands);
    my $neg_cands = [];
    my $pos_ords = [];
    my $neg_ords = [];

    if ($self->anaphor_as_candidate) {
        if (@$pos_cands > 0) {
            push @$neg_cands, $anaph;
        }
        else {
            push @$pos_cands, $anaph;
        }
    }

    my $ord = 1;
    foreach my $cand (@$cands) {
        if (!defined $ante_hash{$cand->id}) {
            push @$neg_cands, $cand;
            push @$neg_ords, $ord;
        }
        elsif (grep {$_ == $cand} @$pos_cands) {
            push @$pos_ords, $ord;
        }
        $ord++;
    }
    return ( $pos_cands, $neg_cands, $pos_ords, $neg_ords );
}

# TODO doc
1;
